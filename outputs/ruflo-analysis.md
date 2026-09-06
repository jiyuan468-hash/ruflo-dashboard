# Ruflo 深度分析报告

## 项目概览

| 属性 | 值 |
|------|-----|
| 名称 | Ruflo (原名 Claude Flow) |
| 作者 | RuvNet (ruv.io) |
| 语言 | TypeScript + Rust (WASM) |
| 许可证 | MIT |
| GitHub Stars | ~69,787 |
| Forks | 8,347 |
| 最新版本 | v3.38.20 (2026-08-24) |
| 测试 | 1999/1999 vitest 通过 |

## 定位

Ruflo 是一个 Agent Meta-Harness（智能体元编排层），为 Claude Code、Codex、Cursor、Copilot 等 AI 编程助手提供协调、记忆、学习和蜂群能力。

核心思想：Agent = Model + Harness。模型负责写代码，Harness 提供工具、记忆、循环、沙箱和管控。

## 架构设计

系统架构：
用户 -> Ruflo (CLI/MCP) -> 路由器 -> 蜂群 -> 智能体 -> 记忆 -> LLM 提供商
                                    自学习循环 (向上反馈)

## 源码结构 (v3/@claude-flow/cli/src/)

| 模块 | 文件数 | 职责 |
|------|--------|------|
| commands/ | 73 | 26 个顶级 CLI 命令，140+ 子命令 |
| mcp-tools/ | 48 | 323 个 MCP 工具定义 |
| services/ | 49 | 后台服务（daemon、proxy、路由等）|
| memory/ | 17 | AgentDB + HNSW 向量搜索 + RAG |
| ruvector/ | 29 | GPU 加速嵌入、Graph RAG |
| benchmarks/ | 28 | GAIA benchmark、SPARC 方法论 |
| funnel/ | 24 | 智能提示路由、成本追踪 |
| transfer/ | 23 | 跨会话记忆传输、RVF 格式 |
| init/ | 12 | 项目初始化、配置生成 |
| plugins/ | 10 | 插件发现与安装 |
| swarm/ | 1 | 蜂群协调（消息压缩器等）|
| security/ | 4 | 输入验证、CVE 修复 |
| auth/ | 7 | 认证、加密 |
| appliance/ | 7 | 硬件 Appliance 支持 |
| proxy/ | 7 | LLM API 代理 |
| production/ | 6 | 生产部署工具 |
| config/ | 4 | 配置管理 |
| update/ | 5 | 自动更新检查 |

## 插件生态 (40 个插件)

核心编排：ruflo-core, ruflo-swarm, ruflo-autopilot, ruflo-loop-workers, ruflo-workflows, ruflo-federation
记忆与知识：ruflo-agentdb, ruflo-rag-memory, ruflo-rvf, ruflo-ruvector, ruflo-knowledge-graph
特殊领域：ruflo-browser, ruflo-neural-trader, ruflo-security-audit, ruflo-cost-tracker, ruflo-goals, ruflo-market-data, ruflo-iot-cognitum, ruflo-music, ruflo-ddd, ruflo-jujutsu

## 智能体 (134 个 Skills)

内置智能体类型：coder, tester, reviewer, architect, security-architect, researcher, devops, +90 个专业领域智能体

## 核心技术

1. 3 层模型路由：确定式 codemod () -> Haiku (.0002) -> Sonnet/Opus (.003-0.015)
2. 自学习记忆：HNSW 向量索引, AgentDB, RuVector GPU 加速, SONA 神经网络
3. 蜂群协调：分层/网格拓扑, Raft 共识, 反漂移机制, 消息压缩
4. 联邦通信：Ed25519 签名, deny-by-default, CASA 策略
5. 双模式协作：Claude Code + Codex 同时运行，共享记忆

## CLI 命令

npx ruflo init           # 初始化项目
npx ruflo doctor         # 健康检查
npx ruflo agent spawn    # 创建智能体
npx ruflo swarm init     # 初始化蜂群
npx ruflo memory search  # 搜索记忆
npx ruflo security scan  # 安全扫描
npx ruflo verify         # 验证安装完整性

## 总结

Ruflo 是最全面的 AI Agent 编排框架之一，提供 323 个 MCP 工具、134 个预置 Skills、40 个插件。
适合：大型代码库开发、多阶段工作流自动化、跨机器协作、需要持久记忆的 AI 辅助编程。
