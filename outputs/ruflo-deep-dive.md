# Ruflo 深度技术分析报告

## 一、记忆系统 (Memory) — 自学习核心

### 1.1 架构层次

记忆系统采用 **6 层渐进式架构** (ADR-053 Phases 1-6)：

`
┌─────────────────────────────────────────────────────┐
│ Phase 6: WitnessChain attestation + COW branching   │
│ Phase 5: ReflexionMemory 会话生命周期               │
│ Phase 4: SkillLibrary promotion + AttestationLog   │
│ Phase 3: ReasoningBank 模式存储 + CausalMemoryGraph│
│ Phase 2: BM25 混合检索 + TieredCache               │
│ Phase 1: Core CRUD + HNSW + 嵌入                  │
└─────────────────────────────────────────────────────┘
`

### 1.2 核心模块

**intelligence.ts (49KB) — SONA 神经网络**
- LocalSonaCoordinator：环形缓冲区实现 O(1) 信号记录
- 性能目标：<0.05ms/次（实测 ~0.01ms）
- HNSW 向量索引：O(log n) 检索
- EWC 抗遗忘：Fisher 信息矩阵保护重要模式
- 支持 RuVector WASM 后端（GPU 加速）

**memory-bridge.ts (130KB) — AgentDB 路由桥**
- CLI → ControllerRegistry → AgentDB v3 控制器
- Windows 平台降级策略：原生 bridge 崩溃时回退到 sql.js
- 路径穿越防护：只允许项目目录内的内存路径
- 支持 CLAUDE_FLOW_MEMORY_PATH 环境变量覆盖

**hybrid-retrieval.ts — 混合检索**
- BM25 (稀疏) + 余弦相似度 (密集) + MMR 多样性重排
- 解决 Bi-encoder 在小型语料库上的噪声问题
- Meta-commit 类型惩罚：抑制 release bump、merge commit 抢 top-1

**lucene-bm25.ts — 标准 BM25 实现**
- Porter 词干提取器 (1980 标准算法)
- Lucene 8.x 英文停用词表 (~120 词)
- BEIR 基准：nDCG@10 = 0.325 (vs 之前 0.279)

**rabitq-index.ts — 1-bit 量化预过滤**
- @ruvector/rabitq-wasm 封装
- 32x 压缩比：浮点嵌入 → 1-bit 汉明扫描
- 候选集重排：Hamming 预筛选 → 精确余弦重排
- 重建阈值：向量数量漂移 >20% 时自动 rebuild

**ewc-consolidation.ts — 弹性权重巩固**
- 公式：L_total = L_new + (λ/2) * Σ(F_i * (θ_i - θ_old_i)²)
- 诚实注释：F_i 是嵌入幅度平方的启发式代理，非真正 Fisher 信息
- 持久化到 .swarm/ewc-fisher.json

### 1.3 记忆存储路径

`
项目级:  .claude-flow/neural/patterns.json
         .claude-flow/neural/stats.json
         .swarm/memory.db (SQLite + HNSW)
         .swarm/ewc-fisher.json

用户级:  ~/.claude-flow/neural/patterns.json
`

---

## 二、蜂群协调 (Swarm)

### 2.1 拓扑类型

| 拓扑 | 适用场景 | 共识机制 |
|------|----------|----------|
| hierarchical | 代码开发、结构化任务 | Raft (leader 维护权威状态) |
| mesh | 创意 brainstorming | Gossip 协议 |
| adaptive | 动态复杂度任务 | 自动切换 |

### 2.2 Worker Daemon 系统

**12 种后台 Worker** (worker-daemon.ts):

| Worker | 间隔 | 功能 |
|--------|------|------|
| map | 5 min | 代码库映射 |
| audit | 10 min | 安全分析 |
| optimize | 15 min | 性能优化 |
| consolidate | 30 min | 记忆蒸馏 (ADR-174) |
| testgaps | 20 min | 测试覆盖分析 |
| ultralearn | - | 深度模式学习 |
| predict | - | 路由预测 |
| benchmark | - | GAIA benchmark |
| backup | - | 记忆备份 |
| harness | - | 编排验证 |
| preload | - | 嵌入预热 |
| deepdive | - | 深度代码分析 |

**HeadlessWorkerExecutor (51KB)**:
- 支持 Claude Code headless 模式并发执行
- 可调 sandbox profile (strict/permissive/disabled)
- AI 预算追踪：global-ai-budget.ts
- 作业去重：i-job-dedup.ts 避免重复工作
- Git workspace 身份解析

### 2.3 消息压缩 (message-compressor.ts)

Dream-cycle #2727 成果：
1. 提取 must-preserve spans（代码围栏、内联代码、URL、文件路径）
2. TF-IDF 关键词密度评分
3. 保留 top-K 句子 + 原始 spans 重组
4. 181.8% 任务增益（IB+VQ 启发式）

---

## 三、智能路由 (Learned Routing)

### 3.1 3 层模型路由 (ADR-026, ADR-143)

`
┌────────────────────────────────────────────┐
│  Tier 1: Codemod (WASM)   ~1ms          │
│    - var-to-const, remove-console          │
│    - add-logging, structural transforms    │
├────────────────────────────────────────────┤
│  Tier 2: Haiku              ~500ms .0002 │
│    - 简单任务, 低复杂度 (<30%)             │
├────────────────────────────────────────────┤
│  Tier 3: Sonnet/Opus       2-5s  .003-  │
│    - 复杂推理, 架构设计, 安全分析          │
└────────────────────────────────────────────┘
`

### 3.2 Thompson Sampling 路由 (v3.7+)

从静态阈值升级为 **多臂老虎机 (Multi-Armed Bandit)**：
- 每层维护 Beta(α, β) 先验分布
- hooks_model-outcome 更新先验
- hooks_model-route 采样 θ ~ Beta(α, β) 选择最优层
- ~50 次结果后自动收敛，无需手动调参
- 单次路由开销：45µs

### 3.3 判别式路由学习 (learned-routing.ts)

基于 TF-IDF + IDF 的关键词排名：
`	ypescript
score = withinAgentSupport × meanQuality × idf × discriminativeShare
`
- withinAgentSupport: 该 agent 处理成功次数 / 总次数
- idf: 跨 agent 稀有度 log(1 + agents / documentFreq)
- discriminativeShare: 该 agent 专属程度
- 过滤：最低支持 2 次、质量 ≥0.65、判别度 ≥0.6

---

## 四、安全系统 (Security / Aidefence)

### 4.1 检测能力

**builtin-aidefence.ts** 内置威胁模式：

| 威胁类型 | 严重性 | 置信度 | 检测模式 |
|----------|--------|--------|----------|
| prompt-injection | high | 96% | ignore/disregard + system instructions |
| system-prompt-extraction | high | 94% | reveal/show + system prompt |
| jailbreak | high | 91% | developer mode/DAN/jailbreak |
| data-exfiltration | critical | 98% | 敏感数据外泄模式 |
| PII leakage | high | 95% | 个人身份信息 |

### 4.2 安全扫描

`ash
npx ruflo security scan --depth deep --target ./src
`
- depth: shallow / standard / deep (full 已废弃)
- 三层阶段防护：静态分析 → 依赖扫描 → CVE 匹配
- fail-closed 设计：未知 --type 参数拒绝执行

### 4.3 策略引擎

- ADR-322A: 唯一允许 promotion 的组件
- ADR-324/325: 工作授权 fencing epoch
- deny-by-default + Ed25519 签名凭证
- MutationGuard: 写操作前验证

---

## 五、插件架构 (Plugins)

### 5.1 PluginManager (manager.ts)

`	ypescript
interface InstalledPlugin {
  name: string;
  version: string;
  installedAt: string;
  enabled: boolean;
  source: 'npm' | 'local' | 'ipfs';
  commands?: string[];
  hooks?: string[];
  config?: Record<string, unknown>;
}
`

**Windows 兼容性处理**:
- Node 18.20.2+ 拒绝直接 spawn .cmd/.bat
- 所有 npm 调用通过 cmd.exe /d /s /c npm <args> 包装
- 包名验证正则防止 shell 注入

### 5.2 插件发现

- 35+ 插件 marketplace
- 每个插件独立 README
- 插件可附带：MCP 工具、CLI 命令、Hooks、Agent 定义

### 5.3 ruflo-core 核心插件

- 323 个 MCP 工具
- 26 个 CLI 命令
- 3 个通用智能体：coder, researcher, reviewer
- 首次运行助手：init-project, ruflo-doctor, discover-plugins
- 自动注册 MCP server

---

## 六、Hooks 系统

### 6.1 Hook 事件类型

`json
{
  "PreToolUse": ["Bash", "Write|Edit|MultiEdit"],
  "PostToolUse": ["Bash", "Write|Edit|MultiEdit"],
  "PreCompact": ["manual", "auto"],
  "PostToolUse": [...]
}
`

### 6.2 Hook 流程

`
PreToolUse (Bash) → ruflo-hook.sh modify-bash
                     ↓
              执行命令
                     ↓
PostToolUse (Bash) → post-command --track-metrics --store-results
                     ↓
              更新记忆 + 模式学习
`

### 6.3 持久化

- Hook 定义在 .claude-plugin/hooks/hooks.json
- 脚本在 scripts/ruflo-hook.sh (POSIX only，Windows 需兼容重写)
- 失败容忍：|| true 确保 hook 失败不阻塞主流程

---

## 七、RVF 格式 (RuVector Format)

跨会话记忆传输格式：
- 序列化为 .rvf 文件
- 支持版本化 + 完整性校验
- 可嵌入 git 历史或独立存储

---

## 八、关键设计模式

### 8.1 Lazy Singleton
- memory-bridge: egistryPromise 延迟初始化
- intelligence: easoningBank 按需创建

### 8.2 Graceful Degradation
- Windows 禁用原生 bridge → 回退 sql.js
- RuVector 缺失 → 使用本地嵌入
- AgentDB 初始化失败 → 静默跳过

### 8.3 Path Traversal Protection
- getDbPath(): 只允许 cwd 及以下路径
- 包名验证: 正则 ^[a-z0-9-~]...

### 8.4 Atomic Writes
- writeFileAtomic(): 先写临时文件再 rename
- 防止写入中断导致数据损坏

---

## 九、技术债务与已知问题

1. **Windows 原生 bridge 不稳定** (#2652/#2120)
   - Rust 分配 panic 导致进程崩溃
   - 当前默认禁用，需手动 CLAUDE_FLOW_ENABLE_NATIVE_BRIDGE_ON_WINDOWS=1

2. **Hook 系统 POSIX only**
   - .claude-plugin/hooks/hooks.json 使用 /bin/bash + jq
   - Windows 需要独立的 Node-based shim

3. **Fisher Information 命名误导**
   - 代码注释诚实说明：F_i 是嵌入幅度平方的启发式，非真正 Fisher 信息

4. **memory-bridge 与 memory-initializer 循环依赖**
   - 通过 createRequire + CJS require 规避 ESM 循环

---

## 十、总结

Ruflo 是一个**工业级 AI Agent 编排框架**，核心亮点：

| 维度 | 实现 |
|------|------|
| 记忆 | HNSW + BM25 + RaBitQ 量化 + EWC 抗遗忘 |
| 路由 | Thompson Sampling 多臂老虎机 + 判别式学习 |
| 蜂群 | 分层拓扑 + Raft 共识 + 反漂移 + 消息压缩 |
| 安全 | Aidefence 威胁检测 + MutationGuard + Ed25519 签名 |
| 插件 | npm marketplace + 自动发现 + 生命周期管理 |
| 后台 | 12 种 worker + headless 并发 + AI 预算追踪 |

代码质量：1999/1999 测试通过，诚实注释标注已知局限，模块化设计清晰。
