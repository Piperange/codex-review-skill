# Codex Review Skill for Claude Code

让 OpenAI Codex 作为第二位 AI 审查员，对你 Claude Code 产出的代码进行精细化交叉审查。

> 不同模型有不同的训练偏差 — 交叉审查可以提高问题发现率。

[English Documentation](README_EN.md)

## 核心特性

- **双重审查模式** — 标准审查（代码质量）+ 对抗性审查（挑战设计决策）
- **有罪推定立场** — 默认代码存在问题，从"一定有问题"的角度深挖
- **AI 痕迹检测** — 10 项指标检测 AI 生成代码的典型模式（过度注释、模板化命名、过度工程化…）
- **双层错误记忆** — 项目级 + 全局，静默注入高频错误到审查 prompt，让 Codex 优先核查你的历史漏洞
- **灵活配置** — effort 程度可选、同步/后台执行可选

## 前置依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Node.js | >= 18.18 | 运行 Codex CLI |
| OpenAI Codex CLI | >= 0.133.0 | 执行代码审查 |
| Claude Code | 最新 | 宿主环境 |
| Codex 账户 | ChatGPT Plus/Pro/API | 认证 |
| Codex CC 插件 | 可选 | 后台任务管理 |

## 一键安装

### macOS / Linux / WSL

```bash
# 从 GitHub 克隆并安装
git clone https://github.com/Piperange/codex-review-skill.git
cd codex-review-skill
bash install.sh
```

### Windows

```powershell
# 从 GitHub 克隆并安装
git clone https://github.com/Piperange/codex-review-skill.git
cd codex-review-skill
.\install.ps1
```

### 安装脚本做了什么

1. 检查 Node.js 版本
2. 安装/更新 `@openai/codex` CLI
3. 引导登录 Codex 账户
4. 安装 Skill 到 `~/.claude/skills/codex-review/`
5. 创建记忆目录 `~/.claude/codex-review/`

### 安装后还需手动执行

在 Claude Code 中运行：

```
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
```

## 使用方式

### 触发方式

两种方式均可触发：

| 方式 | 示例 |
|------|------|
| 自然语言 | 「我想要codex再检查一遍」「让Codex审查一下」 |
| 斜杠命令 | `/codex-review` |

### 审查流程

每次触发后，Claude 会依次询问：

1. **审查模式** — 标准审查 or 对抗性审查
2. **Effort 程度** — low（快速）/ medium（标准）/ high（深度）
3. **执行模式** — 同步（等待结果） or 后台（完成后通知）

然后自动：
- 加载错误记忆（静默注入高频错误）
- 获取当前代码变更（git diff）
- 组装审查 prompt（有罪推定 + AI 痕迹检测 + 高频错误核查）
- 调用 Codex 执行审查
- 解析结果并更新错误记忆
- 展示审查报告

### 审查报告包含

```
🔴 阻断项    — 会导致运行错误、数据损坏、安全漏洞
🟡 重要问题  — 逻辑错误、性能问题、资源泄漏
🔵 改进建议  — 代码风格、可读性、可维护性
🤖 AI 痕迹   — 过度工程化、模板化代码、AI 模式
❓ 提问      — 需要向开发者确认的疑问点
```

每个问题都附带：文件路径 + 行号、问题描述、修复建议、严重程度理由。

## 对抗性审查

选择对抗性审查模式时，Codex 会额外从以下角度发起挑战：

- 设计选择是否合理？有无更简单的方案？
- 代码依赖了哪些未表达的隐藏假设？
- 最可能的 3 个失效点是什么？
- 是否存在已被验证的更好模式？
- 并发/竞态条件是否存在？
- 安全边界和信任边界在哪里？

## AI 痕迹检测

自动检测 10 项 AI 生成代码痕迹：

| # | 检测项 |
|---|-------|
| 1 | 过度注释 |
| 2 | 模板化命名 |
| 3 | 过度抽象 |
| 4 | 防御性过强 |
| 5 | 错误处理空洞 |
| 6 | TODO 残留 |
| 7 | 注释代码不一致 |
| 8 | 过度工程化 |
| 9 | 缺乏领域上下文 |
| 10 | 教科书式实现 |

## 错误记忆系统

### 双层架构

| 层级 | 路径 | 内容 |
|------|------|------|
| 项目级 | `.codex/review-memory.json` | 本项目技术性错误 |
| 全局级 | `~/.claude/codex-review/memory.json` | Claude 通用行为缺陷 |

### 工作方式

1. 每次审查后自动提取并分类 Claude 犯的错误
2. 同一错误累计出现 3 次 → 标记为「高频错误」
3. 下次审查时，高频错误**静默注入** Codex 的审查 prompt
4. Codex 优先核查这些历史高频错误是否再次出现

## 项目结构

```
codex-review-skill/
├── SKILL.md              # 技能定义文件（核心）
├── README.md             # 本文档（中文）
├── README_EN.md          # English documentation
├── install.sh            # Linux/macOS/WSL 安装脚本
├── install.ps1           # Windows PowerShell 安装脚本
└── memory-template.json  # 记忆文件模板
```

## 常见问题

**Q: Codex 未登录怎么办？**
运行 `codex login` 打开浏览器登录你的 OpenAI 账户。

**Q: 如何切换 Codex 模型？**
修改 `~/.codex/config.toml` 中的 `model` 字段，或在审查时手动指定。

**Q: 记忆文件可以手动编辑吗？**
可以。文件是标准 JSON，你可以手动添加、删除或调整错误模式的频率。

**Q: 可以将记忆分享给团队吗？**
建议将 `.codex/review-memory.json` 加入 `.gitignore`，因为记忆中的代码片段可能包含敏感信息。若确需共享，请先脱敏。

**Q: 安装脚本会创建 .gitignore 吗？**
不会自动创建。请手动在项目根目录的 `.gitignore` 中添加 `.codex/review-memory.json`。

## License

MIT
