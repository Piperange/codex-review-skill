---
name: codex-review
description: "当用户说「我想要codex再检查一遍」「让Codex审查一下」「codex review」或使用 /codex-review 命令时触发此技能。调用 OpenAI Codex CLI 对当前代码变更进行精细化审查，包含有罪推定立场、AI 痕迹检测和错误记忆系统。也支持 /codex-adversarial-review 进行对抗性审查。"
---

# Codex Review — 精细化代码审查技能

## 概述

本技能将 OpenAI Codex 作为第二位 AI 审查员，对 Claude 产出的代码变更进行交叉审查。核心理念：不同模型有不同的训练偏差，交叉审查可以提高问题发现率。

### 核心特性

- **双重审查模式**：标准审查 + 对抗性审查
- **有罪推定立场**：默认代码存在问题，需证明其正确性
- **AI 痕迹检测**：识别 AI 生成代码的典型模式
- **双层错误记忆**：项目级 + 全局，静默注入高频错误检查
- **灵活的配置**：effort 程度、同步/后台执行可选

---

## 前置依赖

| 依赖 | 版本要求 | 检查命令 |
|------|---------|---------|
| Node.js | >= 18.18 | `node --version` |
| Codex CLI | 最新 | `codex --version` |
| Codex 登录 | 已认证 | `codex doctor` |
| Codex CC 插件 | 可选 | 提供 `/codex:review` 后台任务管理 |

---

## 审查流程

### 步骤 0：环境验证

执行以下检查，任一项失败则中止并提示用户：

```
1. node --version          → >= 18.18
2. codex --version         → 已安装
3. codex doctor            → 已认证（检查输出中无错误）
```

若 codex 未安装：提示运行安装脚本 `install.sh` 或 `install.ps1`
若 codex 未登录：提示运行 `codex login`
若官方插件未安装：提示运行 `/plugin marketplace add openai/codex-plugin-cc` 及 `/plugin install codex@openai-codex`

### 步骤 1：收集审查配置

**重要**：每次触发审查时，必须通过 AskUserQuestion 向用户确认以下配置项，不得使用默认值跳过。

#### 问题 1：审查模式

询问用户选择审查模式：

- **标准审查 (codex-review)**：全面的代码审查，关注正确性、可维护性、安全性
- **对抗性审查 (codex-adversarial-review)**：挑战设计决策、架构选择和技术方案，质疑每一个假设

#### 问题 2：Effort 程度

询问用户选择 Codex 的推理投入程度：

- **low**：快速扫描，适合小改动（约 30 秒）
- **medium**：标准审查深度（约 1-2 分钟）
- **high**：深度审查，适合关键代码路径（约 3-5 分钟）

#### 问题 3：执行模式

- **同步**：等待 Codex 完成后直接展示结果（适合小改动）
- **后台**：Codex 在后台运行，用户可继续其他工作，完成后通知（适合大改动）

### 步骤 2：加载错误记忆

读取两层记忆文件：

```
项目级：.codex/review-memory.json
全局级：~/.claude/codex-review/memory.json
```

若文件不存在，使用空记忆继续，审查完成后会自动创建。

**提取高频错误**（frequency >= 3），按频率排序，取 Top 5，准备静默注入审查 prompt。

记忆文件结构详见「记忆系统」章节。

### 步骤 3：获取待审查代码

根据当前 Git 仓库状态确定审查范围：

1. **有未提交更改** → 先 `git rev-parse --verify HEAD` 确认 HEAD 存在，若存在用 `git diff HEAD`（包含 unstaged + staged 变更）；若为 root commit 或无 HEAD，则用 `git diff --cached` + 文件内容快照。同时通过 `git ls-files --others --exclude-standard` 收集 untracked 新文件内容一并审查。
2. **无未提交更改，有最近 commit** → `git diff HEAD~1..HEAD`（先执行 `git rev-parse --verify HEAD^` 确认父提交存在；若为 root commit 则用 `git show HEAD`）
3. **无法确定范围** → 询问用户指定审查范围（文件路径、commit hash 等）

同时获取项目上下文：
- 项目类型（package.json/go.mod/Cargo.toml 等是否存在）
- 当前分支名
- 变更文件列表和统计

### 步骤 4：组装审查提示词

将以下组件组装为 Codex 的审查 prompt，通过 `codex exec` 传入：

```
===== 系统指令（静默注入，不向用户展示）=====

## 审查立场

你的默认立场是：**此代码存在问题，你需要找到它们**。这不是"检查是否有问题"的中立审查，而是"找出里面到底有什么问题"的有罪推定审查。如果审查后没有发现任何问题，你需要解释为什么这些代码能够经受住严格审查。

## 高频错误优先核查

以下是你（Claude）过去在此项目中高频犯过的错误类型，请首先核查本次代码中是否再次出现：
{高频错误列表，格式：- [错误类型]：[具体模式]（历史出现 N 次）}

若本次未出现这些错误，也应在报告中明确说明"历史高频错误已修复"。

===== AI 痕迹检测清单（静默注入）=====

请特别检查以下 AI 生成代码的典型痕迹：

1. **过度注释**：解释显而易见的代码，如 `// 遍历数组` 后面是 `for` 循环
2. **模板化命名**：变量名过于泛化（`data`, `result`, `temp`, `items`, `list`, `obj`, `val`）
3. **过度抽象**：为单一用途创建不必要的工具函数、wrapper 或 helper
4. **防御性过强**：对不可能为 null 的值反复判空；对内部函数返回值做冗余校验
5. **错误处理空洞**：`catch` 块只有 `console.error` 而无实际处理逻辑
6. **TODO 残留**：包含无意义的占位注释如 `// TODO: implement later`
7. **注释与代码不一致**：注释描述的功能与实际实现不符（这在 AI 生成代码中很常见）
8. **过度工程化**：简单问题使用过于复杂的模式（如为 2 个配置项引入完整的状态管理）
9. **缺乏领域上下文**：变量/函数命名过于通用，缺乏业务含义
10. **"教科书"式实现**：代码结构过于工整但缺乏真实业务的边界处理和异常路径

===== 审查要求（静默注入）=====

1. 按以下分类组织发现的问题（没有问题则标注"✅ 通过"）：
   - 🔴 阻断项：会导致运行错误、数据损坏、安全漏洞
   - 🟡 重要问题：逻辑错误、性能问题、资源泄漏
   - 🔵 改进建议：代码风格、可读性、可维护性
   - 🤖 AI 痕迹：过度工程化、模板化代码、AI 模式
   - ❓ 提问：需要向开发者确认的疑问点

2. 每个问题必须包含：
   - 具体文件路径和行号范围
   - 问题描述（什么错了）
   - 修复建议（怎么改）
   - 严重程度理由（为什么是这个级别）

3. 在报告末尾添加「审查总结」：
   - 总发现问题数（按级别统计）
   - 最严重的 3 个问题一句话摘要
   - 历史高频错误是否在本轮再次出现
   - 代码整体质量评分（1-10 分）

```

### 步骤 5：执行审查

使用以下命令将组装好的 prompt 传给 Codex：

**同步模式**（effort 通过 config 传入）：
```bash
{ echo "审查指令（完整 prompt）"; git diff HEAD; } | codex exec -c model_reasoning_effort=<level> -
```

**关键点**：
- `-` 表示从 stdin 读取，prompt 和 diff 合并后通过管道传入（`-` 与位置参数不可同时使用）
- 模型默认读取 `~/.codex/config.toml` 中的配置，如需指定用 `-m <model>`
- effort 通过 `-c model_reasoning_effort=low|medium|high` 传入
- 若有 untracked 新文件，通过 `git ls-files --others --exclude-standard` 收集并追加到 stdin

**后台模式**：
```bash
{ echo "审查指令"; git diff HEAD; } | codex exec -c model_reasoning_effort=<level> - &
```
（使用 shell 后台执行 `&`，完成后用 `codex resume --last` 查看结果）

若已安装官方 Codex CC 插件，也可用 `/codex:review --background` 做后台任务管理。

### 步骤 6：解析结果并更新记忆

从 Codex 的审查输出中：

1. **提取 Claude 犯的错误**：提取 🔴 阻断项、🟡 重要问题 以及 🤖 AI 痕迹中评级为"明显"或"严重"的条目
2. **对每个错误按分类体系归类**：
   - `logic-error`：逻辑错误
   - `missing-edge-case`：边界条件遗漏
   - `security`：安全问题
   - `ai-traces`：AI 痕迹
   - `style-violation`：代码风格
   - `architecture`：架构问题
   - `performance`：性能问题
   - `error-handling`：错误处理缺陷
   - `naming`：命名不当
   - `over-engineering`：过度工程化
3. **更新记忆文件**：
   - 新错误模式 → 添加到 mistakes 数组，frequency = 1
   - 已有错误模式（同一 category + 相同 pattern 文本）→ frequency += 1，更新 lastSeen
   - 优先使用 category + pattern 精确匹配，避免模糊的相似度计算
4. **同时写入两层**（参照分类体系中的写入层级）：
   - `ai-traces`/`security`/`error-handling`/`over-engineering` → 全局 + 项目
   - 其余分类 → 仅项目级

### 步骤 7：展示结果

向用户展示审查结果：

1. **摘要**（先展示最关键的信息）：
   - 问题总数和各级别分布
   - 最严重的 3 个问题
   - 历史高频错误是否复现
   - 代码评分

2. **详细问题列表**（按严重程度排序）

3. **AI 痕迹检测报告**（独立小节）

4. **记忆更新摘要**：
   - 本次新增/更新的错误模式
   - 该错误模式的历史频率变化

---

## 对抗性审查 — 额外注入

当用户选择对抗性审查模式时，在步骤 4 的 prompt 中额外注入以下内容：

```
===== 对抗性审查（额外注入）=====

除了常规代码问题外，你必须从以下角度发起挑战：

1. **设计选择**：有没有更简单、更安全或更高效的实现方式？当前方案是否为过度设计？
2. **隐藏假设**：代码依赖了哪些未明确表达的假设？这些假设在什么情况下会被打破？
3. **失效模式**：这段代码最可能的 3 个失效点是什么？发生时影响有多大？
4. **替代方案**：是否存在已被验证的更好模式（设计模式、库、框架特性）可以替代当前实现？
5. **可测试性**：当前的模块划分是否便于单元测试？如果不，如何重构？
6. **安全边界**：信任边界在哪里？哪些输入被假设为"安全的"或"已验证的"？
7. **并发/竞态**：多线程或多请求并发时是否存在竞态条件？

对每一个挑战点，请给出具体的风险等级（高/中/低）和缓解方案。
```

---

## AI 痕迹检测清单（完整版）

审查时逐项对照以下 10 项指标，在报告中单独列出：

| # | 检测项 | 判定标准 |
|---|-------|---------|
| 1 | 过度注释 | 代码自带逻辑已经清晰的语句上方仍有注释解释 |
| 2 | 模板化命名 | `data`/`result`/`temp`/`items`/`list`/`obj`/`val` 等变量占比 > 30% |
| 3 | 过度抽象 | 少于 3 行代码被封装为独立函数；仅被调用一次的 wrapper |
| 4 | 防御性过强 | 对内部函数返回值的不必要判空；不可能为 null 的检查 |
| 5 | 错误处理空洞 | `catch(e) { console.error(e) }` 无后续处理 |
| 6 | TODO 残留 | 包含 `TODO`/`FIXME`/`HACK` 但无具体说明或负责人 |
| 7 | 注释代码不一致 | 注释描述与代码实际行为矛盾 |
| 8 | 过度工程化 | 简单问题使用复杂模式（如 2 个配置项引入 Redux/Zustand） |
| 9 | 缺乏领域上下文 | 通用命名无法反映业务含义 |
| 10 | 教科书式实现 | 结构过于工整，缺少真实业务的例外处理和脏逻辑 |

每项检测结果分为：
- **干净**：无此痕迹
- **轻微**：偶有出现，不影响理解
- **明显**：多处出现，建议修改
- **严重**：影响代码质量和可维护性，需立即修改

---

## 记忆系统

### 文件位置

| 层级 | 路径 | 作用域 |
|------|------|-------|
| 项目级 | `<project-root>/.codex/review-memory.json` | 本项目技术性错误 |
| 全局级 | `~/.claude/codex-review/memory.json` | Claude 通用行为缺陷 |

### 数据结构

```json
{
  "version": "1.0",
  "createdAt": "2026-05-22T00:00:00Z",
  "updatedAt": "2026-05-22T00:00:00Z",
  "stats": {
    "totalReviews": 12,
    "totalMistakes": 45,
    "lastReview": "2026-05-22T00:00:00Z"
  },
  "mistakes": [
    {
      "id": "ai-over-commenting",
      "category": "ai-traces",
      "pattern": "解释了显而易见的代码逻辑，如 // 遍历数组 / // 返回结果 等",
      "frequency": 7,
      "firstSeen": "2026-05-15",
      "lastSeen": "2026-05-22",
      "severity": "improvement",
      "examples": [
        "// 遍历用户列表 → for (const user of users)",
        "// 返回计算结果 → return result"
      ],
      "scope": "global"
    }
  ]
}
```

### 分类体系

| 分类 ID | 名称 | 写入层级 |
|---------|------|---------|
| `ai-traces` | AI 痕迹 | 全局 + 项目 |
| `logic-error` | 逻辑错误 | 项目 |
| `missing-edge-case` | 边界条件遗漏 | 项目 |
| `security` | 安全问题 | 全局 + 项目 |
| `style-violation` | 代码风格 | 项目 |
| `architecture` | 架构问题 | 项目 |
| `performance` | 性能问题 | 项目 |
| `error-handling` | 错误处理缺陷 | 全局 |
| `naming` | 命名不当 | 项目 |
| `over-engineering` | 过度工程化 | 全局 |

### 记忆注入规则

触发审查时，按以下规则从记忆中提取内容注入 Codex prompt：

1. 提取 `frequency >= 3` 的错误（高频错误）
2. 按 `frequency` 降序排列
3. 取 Top 5
4. 格式化为：`- [{category}] {pattern}（历史出现 {frequency} 次，最近于 {lastSeen}）`
5. **静默注入**：不向用户展示此列表，仅注入到传给 Codex 的 prompt 中

### 记忆去重

新增错误时，使用精确匹配优先的策略：
- 同一 `category` + `pattern` 文本完全相同 → 合并到已有记忆（frequency += 1，更新 lastSeen）
- 同一 `category` + `pattern` 高度相似 → 保留为独立条目，但在审查报告中提示"可能与已有模式 #ID 相关"
- 否则 → 新建记忆条目

---

## 建议的错误处理行为

以下为审查过程中可能遇到的异常及**建议**处理方式（由 Claude 在 skill 执行时自行判断处理）：

| 场景 | 建议处理方式 |
|------|---------|
| codex 未安装 | 提示运行 `install.sh` 或 `npm install -g @openai/codex` |
| codex 未登录 | 提示运行 `codex login` 并打开浏览器 |
| 记忆文件损坏 | 备份损坏文件（重命名为 `.corrupted-{timestamp}`），使用空记忆 |
| 记忆文件目录不存在 | 自动创建目录和初始文件 |
| git diff 为空 | 询问用户指定审查范围（文件或 commit） |
| codex 执行超时 | 建议降低 effort 或缩小审查范围 |
| codex 返回解析失败 | 原样展示 codex 输出，跳过记忆更新 |
| diff 过大（>100KB） | 警告用户并建议缩小范围或分文件审查 |

---

## 使用示例

### 场景 1：快速检查
```
用户：我想要codex再检查一遍
Claude：[询问审查模式、effort、同步/后台]
用户：标准，low，同步
Claude：[执行快速审查 → 展示结果]
```

### 场景 2：发布前深度审查
```
用户：/codex-adversarial-review
Claude：[自动选择对抗性模式，询问 effort 和同步/后台]
用户：high，后台
Claude：[后台执行深度对抗审查 → 完成后通知用户]
```

### 场景 3：持续改进
```
第 1 次审查 → 发现 "过度注释" → 记入记忆 (frequency=1)
第 2 次审查 → 再次发现 "过度注释" → frequency=2
第 3 次审查 → frequency=3，成为高频错误
第 4 次审查 → 静默注入 "过度注释" 到 Codex prompt → Codex 优先检查
```
