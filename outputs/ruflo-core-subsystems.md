# Ruflo 核心子系统深度技术报告

---

## 一、插件架构 (Plugin System)

### 1.1 插件目录结构

每个插件是一个独立目录，包含以下标准结构：

\\\
plugins/ruflo-<name>/
├── .mcp.json              # MCP server 注册配置
├── README.md              # 插件文档
├── agents/                # 智能体定义 (Markdown frontmatter)
│   ├── coder.md
│   └── researcher.md
├── commands/              # CLI 命令定义
│   └── ruflo-status.md
├── docs/                  # ADR 和技术文档
├── hooks/                 # Hook 配置
│   └── hooks.json
├── scripts/               # 启动脚本
│   ├── mcp-launch.cjs     # MCP 服务器启动器
│   └── ruflo-hook.cjs     # Hook 执行器
└── skills/                # Skill 定义
    └── discover-plugins/
        └── SKILL.md
\\\

### 1.2 .mcp.json — MCP 服务器注册

\\\json
{
  "mcpServers": {
    "ruflo": {
      "command": "node",
      "args": ["\/scripts/mcp-launch.cjs"],
      "env": {
        "CLAUDE_FLOW_MCP_TRANSPORT": "stdio"
      }
    }
  }
}
\\\

**mcp-launch.cjs 解析逻辑**（优先级从高到低）：
1. ~/.claude/plugins/marketplaces/ruflo/bin/cli.js (marketplace 安装)
2. <cwd>/node_modules/@claude-flow/cli/bin/cli.js (npm 本地安装)
3. <cwd>/node_modules/ruflo/bin/cli.js (ruflo 包安装)
4. <cwd>/v3/@claude-flow/cli/bin/cli.js (源码路径)
5. 回退到 
px -y @claude-flow/cli@latest mcp start

每个候选项验证 dist/src/index.js 存在性，防止裸 clone 无 build 时崩溃。

### 1.3 Agent 定义格式

\\\markdown
---
name: coder
description: Implementation specialist for writing clean, efficient code
model: sonnet
---
You are a code implementation specialist working within a Ruflo-coordinated swarm...
\\\

**关键字段**：
- 
ame: 智能体标识符
- description: 触发 skill 的描述文本
- model: 推荐模型 (sonnet/haiku/opus)
- llowed-tools: MCP 工具白名单
- rgument-hint: 参数提示

### 1.4 Skills 格式

\\\markdown
---
name: discover-plugins
description: Discover and recommend ruflo plugins based on your workflow
argument-hint: "[search-query]"
allowed-tools: mcp__plugin_ruflo-core_ruflo__transfer_plugin-search Bash Read
---

# Discover Plugins
Find and recommend ruflo plugins for your workflow.
\\\

### 1.5 Hooks 格式

\\\json
{
  "description": "Hook 说明",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "node -e \"process.argv=[..., 'modify-bash']; require(...)\""
          }
        ]
      }
    ],
    "PostToolUse": [...],
    "PreCompact": [...]
  }
}
\\\

**关键设计**：
- 使用 
ode -e require() 而非 bash，保证 Windows/macOS/Linux 一致
- 始终 || true 确保 hook 失败不阻塞主流程
- 通过 process.env.CLAUDE_PLUGIN_ROOT 定位插件目录

---

## 二、蜂群协议 (Swarm Protocol)

### 2.1 拓扑类型

| 拓扑 | 适用场景 | 共识 | 通信模式 |
|------|----------|------|----------|
| hierarchical | 代码开发、结构化任务 | Raft | 树形层级 |
| mesh | 创意 brainstorming | Gossip | 全对全 |
| hierarchical-mesh | 10+ 智能体 | Queen + Peer | 混合 |
| ring | 线性流水线 | Leader | 环形 |
| star | 中心协调 | Leader | 星形 |
| adaptive | 动态复杂度 | 自动切换 | 混合 |

### 2.2 蜂群状态机

\\\
initializing → running ↔ paused → shutting_down → terminated
                ↑                       ↓
                └──── crash/recovery ────┘
\\\

**状态文件**: .claude-flow/swarm/swarm-state.json

\\\	ypescript
interface SwarmState {
  swarmId: string;
  topology: 'hierarchical' | 'mesh' | 'ring' | 'star' | 'adaptive';
  maxAgents: number;
  status: 'initializing' | 'running' | 'paused' | 'shutting_down' | 'terminated';
  agents: string[];
  tasks: string[];
  config: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
  pid?: number;           // #1799: 初始化进程 PID
  terminationReason?: string;
}
\\\

### 2.3 反漂移机制 (Anti-Drift)

**默认配置**（CLAUDE.md 生成）：

| 参数 | 默认值 | 作用 |
|------|--------|------|
| topology | hierarchical | 协调器捕获分歧 |
| maxAgents | 6-8 | 小团队减少漂移 |
| strategy | specialized | 清晰角色边界 |
| consensus | raft | Leader 维护权威状态 |
| memory | hybrid | SQLite + AgentDB |

**漂移检测**：
- 定期 checkpoint 对比
- 角色重叠检测
- 任务分配冲突检测
- 记忆命名空间隔离

### 2.4 共识算法

| 算法 | 容错 | 复杂度 | 适用 |
|------|------|--------|------|
| Raft | f < n/2 | O(n) 日志复制 | 强一致性场景 |
| Byzantine (BFT) | f < n/3 | O(n²) 消息 | 非信任环境 |
| Gossip | 概率性 | O(log n) 传播 | 最终一致 |
| CRDT | 无中心 | 操作合并 | 无冲突复制 |
| Quorum | 可配置 | O(q) | 可调容错 |

**ADR-095 Gap G2** 指出：当前共识实现是单进程 EventEmitter，非真正分布式。需要：
- WebSockets/gRPC 传输层
- Ed25519 真实签名验证
- 故障注入测试 (f<n/3 for BFT, f<n/2 for Raft)

### 2.5 Worktree 隔离

`	ypescript
// 每个智能体独立 git worktree
EnterWorktree(agentId)  →  创建独立 worktree
ExitWorktree(agentId)   →  清理 worktree
`

**硬不变量**：同一 worktree 禁止两个写入者。

---

## 三、RVF 格式 (RuVector Format)

### 3.1 格式定义

RVF (RuVector Format) 是便携式向量记忆格式：

\\\	ypescript
interface RVFContainer {
  version: '1.0.0';
  schema: 'session' | 'memory' | 'trajectory';
  metadata: {
    project: string;
    createdAt: string;
    lastAccessed: string;
    embeddingModel: string;
    dimensions: number;
  };
  sessions: RVFSession[];
  vectors: RVFVector[];
  causalGraph: RVFCausalEdge[];
  attestations: RVFAttestation[];
}
\\\

### 3.2 加密 (ADR-096)

**启用条件**：
- CLAUDE_FLOW_ENCRYPT_AT_REST=1
- CLAUDE_FLOW_ENCRYPTION_KEY: 64-char hex 或 44-char base64

**加密方案**：AES-256-GCM + RFE1 magic byte prefix

**行为**：
- 默认关闭 → 明文 JSON，权限 0600
- 启用后 → 自动加密写入，透明解密读取
- 旧版明文 session 自动迁移兼容

### 3.3 跨插件 RVF 所有权

| 切片 | 所有者 | 功能 |
|------|--------|------|
| 便携记忆 + 会话持久化 | ruflo-rvf | save/restore, 跨机器传输 |
| 浏览器会话作为 RVF | ruflo-browser | 会话级 RVF 容器 |
| RVF 工具 (10 子命令) | ruflo-ruvector | create/ingest/query/status/... |

### 3.4 RVF 命名空间

- 专属命名空间: vf-sessions
- 保留命名空间（不可覆盖）: pattern, claude-memories, default

---

## 四、AgentDB 控制器层次

### 4.1 INIT_LEVELS 初始化顺序

| Level | 控制器 | 职责 |
|-------|--------|------|
| 0 | _(基础)_ | Bootstrap |
| 1 | reasoningBank, hierarchicalMemory, learningBridge, hybridSearch, tieredCache | 核心智能 |
| 2 | memoryGraph, agentMemoryScope, vectorBackend, mutationGuard, gnnService | 图 + 安全 |
| 3 | skills, explainableRecall, reflexion, attestationLog, batchOperations, memoryConsolidation | 专业化 |
| 4 | causalGraph, nightlyLearner, learningSystem, semanticRouter | 因果 + 路由 |
| 5 | graphTransformer, sonaTrajectory, contextSynthesizer, rvfOptimizer, mmrDiversityRanker, guardedVectorBackend | 高级服务 |
| 6 | federatedSession, graphAdapter | 会话管理 |

### 4.2 G7 控制器 (ADR-095)

| 控制器 | 功能 |
|--------|------|
| gnnService | GNN 嵌入 + 关系评分 |
| rvfOptimizer | RVF 量化 + 去重压缩 |
| mutationGuard | WASM 证明生成 (ADR-060) |
| attestationLog | 哈希链审计日志 |
| GuardedVectorBackend | 封装 mutationGuard + attestationLog |

### 4.3 ADR-095 开放 Gap

| Gap | 状态 | 阻塞 |
|-----|------|------|
| G1: agent_spawn 无子进程 | 未实现 | 阻塞 G3/G4 |
| G2: Hive-mind 单进程 | 部分实现 | 需传输层 |
| G3: Workflow 无运行时 | 未实现 | 依赖 G1 |
| G4: WASM agent echo | 未实现 | 依赖 G1 |
| G5: protobufjs RCE | 已修复 (ADR-094) | - |
| G6: 联邦无成本追踪 | Phase 1 已实现 | - |
| G7: 安全控制器激活 | 已实现 (ADR-095) | - |

---

## 五、联邦协议 (Federation)

### 5.1 5 层信任模型

\\\
UNTRUSTED → VERIFIED → ATTESTED → TRUSTED → PRIVILEGED
\\\

基于行为评分动态调整。

### 5.2 预算熔断器 (ADR-097)

**Phase 1** (已实现)：
- maxHops: 默认 8，防止递归委托循环
- maxTokens: 总 token 上限
- maxUsd: 总成本上限
- 常量错误字符串 HOP_LIMIT_EXCEEDED / BUDGET_EXCEEDED（防 oracle 探测）

**Phase 2** (延期): 对等体状态机 ACTIVE/SUSPENDED/EVICTED
**Phase 3** (已实现): ruflo-cost-tracker 集成
**Phase 4** (延期): 统一成本面

### 5.3 安全特性

- mTLS + Ed25519 身份证明
- 14 类 PII 检测，按信任级别策略 (BLOCK/REDACT/HASH/PASS)
- HMAC 签名信封
- 双 AI Defence 门控 (出站 + 入站)
- 合规模式: HIPAA, SOC2, GDPR 审计日志

---

## 六、MCP 工具分类

### 6.1 323 个工具按家族分组

| 家族 | 工具数 | 文件 |
|------|--------|------|
| agentdb_* | 15 | agentdb-tools.ts |
| memory_* | ~40 | memory-tools.ts |
| embeddings_* | 10 | embeddings-tools.ts |
| hooks_* | 19+ | hooks-tools.ts |
| swarm_* | 4 | swarm-tools.ts |
| agent_* | 8 | agent-tools.ts |
| neural_* | 6 | neural-tools.ts |
| browser_* | 28 | browser-tools.ts + browser-session-tools.ts |
| security_* | 6 | security-tools.ts |
| workflow_* | ~15 | workflow-tools.ts |
| ruvllm_* | 4 | ruvllm-tools.ts |
| daa_* | ~10 | daa-tools.ts |
| guidance_* | ~10 | guidance-tools.ts |
| transfer_* | ~15 | transfer-tools.ts |
| task_* | ~10 | task-tools.ts |
| performance_* | ~8 | performance-tools.ts |
| claims_* | ~5 | claims-tools.ts |
| config_* | ~5 | config-tools.ts |
| session_* | ~5 | session-tools.ts |

### 6.2 工具设计模式

**输入验证** (alidate-input.ts)：
- 长度上限、字符白名单
- 路径穿越防护
- 危险字符过滤

**原子写** (s-secure.ts)：
- 先写临时文件再 rename
- 权限 0600

**失败容忍**：
- || true 在 hook 链
- 降级策略（WASM 缺失 → 本地回退）

---

## 七、Dream Cycle 系列 ADR (365-376)

这是 Ruflo 最前沿的研究方向：

| ADR | 主题 | 核心思想 |
|-----|------|----------|
| ADR-365 | 记忆巩固回路过闸 | 基于触发条件的选择性持久化 |
| ADR-366 | 蜂群自演化技能蒸馏 | 从成功任务中提取可复用技能 |
| ADR-367 | 认知工作记忆管道 | 类似人类工作记忆的短期缓冲区 |
| ADR-368 | 选择性持久化 | 只保留高价值记忆 |
| ADR-369 | IB+VQ 智能体间通信 | 181.8% 任务增益的消息压缩 |
| ADR-370 | 世界模型 + 智能体规划 | 内部模拟未来状态 |
| ADR-371 | 神经密码授权 | 基于神经网络的访问控制 |
| ADR-372 | 认知模式路由器 | 多模式切换 |
| ADR-373 | 记忆预算算子选择 | 资源受限下的最优操作 |
| ADR-374 | 子智能体权限委托 | 最小权限传播 |
| ADR-375 | AgentPerf 基准测试 | MoE (Mixture of Agents) 评估 |
| ADR-376 | 异构集成 API | 多模型协作接口 |

---

## 八、开发者指南：创建自定义插件

### 8.1 最小插件结构

\\\
my-plugin/
├── .mcp.json
├── README.md
├── agents/
│   └── my-agent.md
├── skills/
│   └── my-skill/
│       └── SKILL.md
└── scripts/
    └── mcp-launch.cjs  # (复用 ruflo-core 的)
\\\

### 8.2 .mcp.json

\\\json
{
  "mcpServers": {
    "my-plugin": {
      "command": "node",
      "args": ["\/scripts/mcp-launch.cjs"],
      "env": {
        "CLAUDE_FLOW_MCP_TRANSPORT": "stdio"
      }
    }
  }
}
\\\

### 8.3 Agent 定义

\\\markdown
---
name: my-agent
description: Specialized agent for X task type
model: haiku
---
You are a specialized agent for...
\\\

### 8.4 Skill 定义

\\\markdown
---
name: my-skill
description: When to trigger this skill
argument-hint: "[params]"
allowed-tools: mcp__my-plugin__some_tool Bash Read
---

# My Skill

Instructions here...
\\\

### 8.5 安装

\\\ash
# 方式 1: 本地开发
/plugin install my-plugin@local /path/to/my-plugin

# 方式 2: npm 发布后
/plugin marketplace add my-org/my-repo
/plugin install my-plugin@my-org
\\\

---

## 九、关键设计原则总结

1. **诚实注释文化** — 代码中对局限性的坦诚标注（Fisher Information 命名、WASM agent echo、单进程共识）
2. **Fail-Closed 安全** — 未知参数拒绝执行，不静默通过
3. **渐进式架构** — ADR-053 6 阶段控制器激活，每阶段向后兼容
4. **多平台一致** — Node-based hooks 避免 bash/POSIX 依赖
5. **优雅降级** — Windows 原生 bridge 失败 → sql.js 回退
6. **原子持久化** — 临时文件 + rename 防止损坏
7. **命名空间隔离** — kebab-case 命名约定，保留命名空间保护
8. **预算熔断** — 防止递归委托和成本失控
