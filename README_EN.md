# Codex Review Skill for Claude Code

Add OpenAI Codex as a second AI reviewer to cross-examine code produced by Claude Code.

> Different models have different training biases — cross-review increases issue detection rates.

[中文文档](README.md)

## Core Features

- **Dual Review Modes** — Standard review (code quality) + Adversarial review (challenge design decisions)
- **Guilty-Until-Proven-Innocent** — Default stance: the code has bugs; dig deep from a "find what's wrong" perspective
- **AI Trace Detection** — 10 indicators to detect typical AI-generated code patterns (over-commenting, templated naming, over-engineering...)
- **Dual-Layer Error Memory** — Project-level + global; high-frequency errors are silently injected into the review prompt so Codex prioritizes checking your historical blind spots
- **Flexible Configuration** — Selectable effort levels, sync/background execution

## Prerequisites

| Dependency | Version | Purpose |
|------|------|------|
| Node.js | >= 18.18 | Run Codex CLI |
| OpenAI Codex CLI | >= 0.133.0 | Execute code reviews |
| Claude Code | Latest | Host environment |
| Codex Account | ChatGPT Plus/Pro/API | Authentication |
| Codex CC Plugin | Optional | Background task management |

## One-Click Install

### macOS / Linux / WSL

```bash
# Clone from GitHub and install
git clone https://github.com/Piperange/codex-review-skill.git
cd codex-review-skill
bash install.sh
```

### Windows

```powershell
# Clone from GitHub and install
git clone https://github.com/Piperange/codex-review-skill.git
cd codex-review-skill
.\install.ps1
```

### What the Install Script Does

1. Checks Node.js version
2. Installs/updates `@openai/codex` CLI
3. Guides Codex account login
4. Installs the Skill to `~/.claude/skills/codex-review/`
5. Creates the memory directory `~/.claude/codex-review/`

### Post-Install Manual Steps

Run these in Claude Code:

```
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
```

## Usage

### How to Trigger

Two ways to trigger:

| Method | Example |
|------|------|
| Natural Language | "I want Codex to check this again", "Let Codex review it" |
| Slash Command | `/codex-review` |

### Review Flow

Each time triggered, Claude will ask:

1. **Review Mode** — Standard or Adversarial review
2. **Effort Level** — low (quick) / medium (standard) / high (deep)
3. **Execution Mode** — Sync (wait for results) or Background (notify when done)

Then automatically:
- Loads error memory (silently injects high-frequency errors)
- Fetches current code changes (git diff)
- Assembles the review prompt (guilty stance + AI trace detection + high-frequency error checks)
- Invokes Codex to perform the review
- Parses results and updates error memory
- Displays the review report

### Review Report Includes

```
🔴 Blockers    — Runtime errors, data corruption, security vulnerabilities
🟡 Major       — Logic errors, performance issues, resource leaks
🔵 Suggestions — Code style, readability, maintainability
🤖 AI Traces   — Over-engineering, templated code, AI patterns
❓ Questions   — Points needing developer clarification
```

Each issue includes: file path + line numbers, problem description, fix suggestion, and severity rationale.

## Adversarial Review

When adversarial mode is selected, Codex additionally challenges from these angles:

- Is the design choice reasonable? Is there a simpler approach?
- What hidden, unstated assumptions does the code depend on?
- What are the 3 most likely failure points?
- Are there proven better patterns available?
- Are there concurrency/race conditions?
- Where are the security and trust boundaries?

## AI Trace Detection

Automatically detects 10 AI-generated code patterns:

| # | Detection Item |
|---|-------|
| 1 | Over-commenting |
| 2 | Templated naming |
| 3 | Over-abstraction |
| 4 | Over-defensive checks |
| 5 | Hollow error handling |
| 6 | Lingering TODOs |
| 7 | Comment-code mismatch |
| 8 | Over-engineering |
| 9 | Lack of domain context |
| 10 | Textbook-style implementation |

## Error Memory System

### Dual-Layer Architecture

| Layer | Path | Content |
|------|------|------|
| Project-level | `.codex/review-memory.json` | Project-specific technical errors |
| Global-level | `~/.claude/codex-review/memory.json` | Claude's general behavioral blind spots |

### How It Works

1. After each review, Claude's mistakes are automatically extracted and classified
2. Same error accumulates 3 occurrences → marked as "high-frequency error"
3. On the next review, high-frequency errors are **silently injected** into Codex's review prompt
4. Codex prioritizes checking whether these historical high-frequency errors have reappeared

## Project Structure

```
codex-review-skill/
├── SKILL.md              # Skill definition file (core)
├── README.md             # Documentation (Chinese)
├── README_EN.md          # Documentation (English)
├── install.sh            # Linux/macOS/WSL installer
├── install.ps1           # Windows PowerShell installer
└── memory-template.json  # Memory file template
```

## FAQ

**Q: What if Codex is not logged in?**
Run `codex login` to open your browser and log into your OpenAI account.

**Q: How do I switch the Codex model?**
Edit the `model` field in `~/.codex/config.toml`, or specify it manually during review.

**Q: Can I edit the memory file manually?**
Yes. The file is standard JSON — you can manually add, remove, or adjust error pattern frequencies.

**Q: Can I share the memory with my team?**
It's recommended to add `.codex/review-memory.json` to `.gitignore`, as code snippets in memory may contain sensitive information. If sharing is necessary, sanitize it first.

**Q: Does the install script create a .gitignore?**
No. Manually add `.codex/review-memory.json` to your project's `.gitignore`.

## License

MIT
