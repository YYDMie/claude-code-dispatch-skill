# Claude Code Dispatch Skill

[![test](https://github.com/YYDMie/claude-code-dispatch-skill/actions/workflows/test.yml/badge.svg)](https://github.com/YYDMie/claude-code-dispatch-skill/actions/workflows/test.yml)

一个面向 Codex 的 Claude Code 本地派发技能。

它让 Codex 可以把已经整理好的任务提示词交给本机 Claude Code 执行，同时记录提示词快照、进程信息、日志和工作流状态。Claude 完成开发后，Codex 再检查实际代码差异并独立验收。

本项目适合这样的协作方式：

```text
Codex 规划与验收
        ↓
生成范围明确的任务提示词
        ↓
Claude Code 实现
        ↓
Codex 检查 diff、运行测试、发现问题
        ↓
再次派发修复任务，直到验收通过
```

## 主要能力

- 从 Markdown 提示词文件启动 Claude Code。
- 支持可视化交互窗口和隐藏后台执行。
- 自动保存提示词快照、PID、状态和日志路径。
- 支持额外只读或可访问目录的 `--add-dir` 参数。
- 支持 `direct` 单会话开发模式。
- 支持 `ultracode` 动态多代理工作流模式。
- 支持 `PrepareOnly`，启动前先检查最终提示词。
- 读取 Claude Code `wf_*.json`，低频检查工作流状态。
- 为后续 Codex 独立验收保留完整证据。

## 适用场景

### 直接模式

适合范围较小、文件所有权集中、一个 Claude 会话即可完成的任务，例如：

- 修复一个明确 bug。
- 为一个模块补测试。
- 修改一个 API 客户端。
- 根据验收意见完成一次小范围返工。

### Ultracode 工作流模式

适合跨模块、需要多个视角审计或独立验收的任务，例如：

- 后端、客户端和契约同时变化。
- 先并行审计，再分区实现。
- 实现完成后需要独立 reviewer 检查真实 diff。
- 任务较大，需要记录各阶段 agent 状态和 token 使用。

`ultracode` 不是 Claude CLI 参数。它是提示词协议，用于要求 Claude Code 调用内置的 `Workflow` 工具，并运行由 `phase()`、`agent()`、`parallel()` 组成的动态工作流。

## 环境要求

- Windows 10 或 Windows 11。
- Windows PowerShell 5.1 或 PowerShell 7。
- 已安装并登录 Claude Code。
- 已安装 Codex，并支持本地 Skills。

检查命令：

```powershell
Get-Command claude
claude --version
claude --help
```

本项目在 Claude Code `2.1.177` 上验证。Claude Code 的 Workflow 属于版本敏感能力，升级后建议先使用 `PrepareOnly` 和小型测试任务验证。

仓库自测不要求安装 Claude Code：

```powershell
.\test.ps1
```

自测会检查 PowerShell 语法、Ultracode 提示词生成和临时目录安装。

## 安装

### 一键安装

克隆仓库：

```powershell
git clone https://github.com/YYDMie/claude-code-dispatch-skill.git
cd claude-code-dispatch-skill
```

在仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

安装目标默认为：

```text
%USERPROFILE%\.codex\skills\claude-code-dispatch
```

如果目标已存在，安装器默认停止，避免覆盖本地修改。确认覆盖时使用：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Force
```

旧技能会先备份为带时间戳的目录，再安装新版本。

### 手动安装

将以下目录：

```text
skills\claude-code-dispatch
```

复制到：

```text
%USERPROFILE%\.codex\skills\claude-code-dispatch
```

重新打开 Codex 会话后即可触发技能。

## 快速开始

先准备一个任务文件，例如：

```text
C:\work\my-project\.tasks\feature-a.md
```

示例内容见 [examples/task-prompt.md](examples/task-prompt.md)。

### 可视化直接开发

```powershell
$skill = "$HOME\.codex\skills\claude-code-dispatch"

powershell -NoProfile -ExecutionPolicy Bypass `
  -File "$skill\scripts\dispatch-claude-code.ps1" `
  -PromptPath "C:\work\my-project\.tasks\feature-a.md" `
  -WorkingDirectory "C:\work\my-project" `
  -LogPrefix "feature-a" `
  -Name "MyProject-Feature-A" `
  -PermissionMode auto `
  -Effort high `
  -VisibleInteractive
```

Claude Code 会在新的 PowerShell 窗口中运行。Claude 退出后，窗口默认自动关闭。

### 可视化 Ultracode 工作流

```powershell
$skill = "$HOME\.codex\skills\claude-code-dispatch"

powershell -NoProfile -ExecutionPolicy Bypass `
  -File "$skill\scripts\dispatch-claude-code.ps1" `
  -PromptPath "C:\work\my-project\.tasks\release-prep.md" `
  -WorkingDirectory "C:\work\my-project" `
  -AddDir "C:\work\shared-contracts" `
  -LogPrefix "release-prep" `
  -Name "MyProject-Release-Prep" `
  -DispatchMode ultracode `
  -WorkflowName "myproject-release-prep" `
  -PermissionMode auto `
  -Effort high `
  -VisibleInteractive
```

工作流提示词会强制要求 Claude：

1. 创建并运行内置 Workflow。
2. 先做只读审计。
3. 只并行执行文件范围互不重叠的实现任务。
4. 做集成验证。
5. 使用独立 agent 验收真实 diff。
6. 返回 `runId`、状态、agent 数量和工作流文件路径。

### 后台执行

去掉 `-VisibleInteractive` 即可使用隐藏后台模式：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File "$skill\scripts\dispatch-claude-code.ps1" `
  -PromptPath "C:\work\my-project\.tasks\feature-a.md" `
  -WorkingDirectory "C:\work\my-project" `
  -Name "MyProject-Feature-A"
```

后台模式会生成独立的标准输出和错误日志。

### 仅生成提示词，不启动

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File "$skill\scripts\dispatch-claude-code.ps1" `
  -PromptPath "C:\work\my-project\.tasks\release-prep.md" `
  -WorkingDirectory "C:\work\my-project" `
  -DispatchMode ultracode `
  -WorkflowName "myproject-release-prep" `
  -PrepareOnly
```

建议首次使用 Ultracode 或升级 Claude Code 后先运行此模式，检查生成的 `*.prompt.md`。

## 状态与产物

默认产物目录：

```text
<WorkingDirectory>\.claude-dispatch\
```

常见文件：

| 文件 | 说明 |
|---|---|
| `*.prompt.md` | 最终发送给 Claude 的提示词 |
| `*.source.prompt.md` | Ultracode 模式下的原始任务快照 |
| `*.state.json` | 机器可读的派发状态 |
| `*.pid.txt` | 便于人工查看的进程和路径信息 |
| `*.out.log` | 后台模式标准输出 |
| `*.err.log` | 后台模式错误输出 |
| `*.transcript.txt` | 可视化模式 PowerShell transcript |

可以通过 `-LogDirectory` 指定其他目录。

## 工作流状态检查

Claude Code 的动态工作流状态通常写入：

```text
%USERPROFILE%\.claude\projects\<project>\<session>\workflows\wf_*.json
```

检查最新状态：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File "$skill\scripts\get-claude-workflow-status.ps1" `
  -WorkingDirectory "C:\work\my-project" `
  -WorkflowName "myproject-release-prep"
```

等待完成，并每 90 秒检查一次：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File "$skill\scripts\get-claude-workflow-status.ps1" `
  -WorkingDirectory "C:\work\my-project" `
  -WorkflowName "myproject-release-prep" `
  -WaitForCompletion `
  -PollSeconds 90 `
  -TimeoutMinutes 180
```

输出包含：

- `run_id`
- `workflow_name`
- `status`
- `agent_count`
- `total_tokens`
- `total_tool_calls`
- `script_path`
- `state_file`

## 重要参数

| 参数 | 默认值 | 说明 |
|---|---|---|
| `PromptPath` | 必填 | 原始任务提示词文件 |
| `WorkingDirectory` | 必填 | Claude Code 工作目录 |
| `AddDir` | 空 | 额外允许访问的目录，可传多个 |
| `DispatchMode` | `direct` | `direct` 或 `ultracode` |
| `WorkflowName` | `Name` | Ultracode 工作流名称 |
| `PermissionMode` | `auto` | Claude Code 权限模式 |
| `Effort` | `high` | Claude Code effort |
| `VisibleInteractive` | 关闭 | 新窗口可视化执行 |
| `KeepOpenAfterExit` | 关闭 | Claude 退出后保留窗口 |
| `PrepareOnly` | 关闭 | 仅生成派发产物 |
| `DangerouslySkipPermissions` | 关闭 | 显式跳过 Claude 权限检查 |
| `Wait` | 关闭 | 后台模式等待进程结束 |

## 推荐协作规范

### 派发前

- 先检查 `git status`。
- 明确允许修改的目录和文件。
- 写清楚禁止事项。
- 写出可执行的验收命令。
- 要求生成结果报告。
- 不把密码、token 或生产凭据写进提示词。

### Claude 执行期间

- 可视化模式下允许用户直接观察进度。
- 不要高频读取 transcript；交互式 TUI 内容不一定完整写入 transcript。
- Ultracode 优先读取 `wf_*.json`。
- 任务运行较久时使用有意义的检查间隔。

### Claude 完成后

- 不直接相信 Claude 的“全部通过”总结。
- 检查真实 `git diff` 和文件边界。
- 独立运行测试、构建和静态检查。
- 发现问题后生成范围更窄的修复提示词。
- 验收通过后再提交和推送。

## 安全说明

- 默认不启用 `--dangerously-skip-permissions`。
- 不建议对来源不明的仓库使用 `bypassPermissions`。
- 动态工作流中的多个写 agent 不应修改重叠文件。
- 日志与提示词快照可能包含项目路径和任务内容，提交 Git 前应清理。
- 工作流 agent 的总结只是线索，不是验收证据。
- 本项目不会自动提交或推送代码，除非原始任务明确要求 Claude 这样做。

## 常见问题

### 提示词中的 `--check` 被 Claude CLI 当成参数

脚本在 prompt 参数前加入了 `--` 终止符，避免 `git diff --check` 等文本被当作 Claude CLI 参数。

### Ultracode 没有创建 Workflow

单独写 `ultracode` 不一定足够。此技能生成的工作流引导会明确要求调用 `Workflow`，并要求不可用时返回 `BLOCKED`，禁止静默退回单 agent。

### 找不到工作流状态

确认：

- `WorkingDirectory` 与启动 Claude 时一致。
- `WorkflowName` 完全一致。
- `Since` 时间没有过滤掉目标运行。
- 当前 Claude Code 版本仍使用相同的项目状态目录格式。

### PowerShell 中文乱码

工作流引导语使用 ASCII 英文，原始任务文件按 UTF-8 读取。任务文件本身建议保存为 UTF-8。

### 测试时出现 `obj/bin Access denied`

这通常来自沙箱限制、并发构建或仍在运行的 `dotnet` 进程。先关闭完成的 Claude 窗口，避免并行执行多个 `dotnet test`，并确认当前工具有权写目标仓库。

## 仓库结构

```text
.
├── README.md
├── LICENSE
├── SECURITY.md
├── install.ps1
├── test.ps1
├── .github/
│   └── workflows/
│       └── test.yml
├── examples/
│   └── task-prompt.md
└── skills/
    └── claude-code-dispatch/
        ├── SKILL.md
        ├── agents/
        │   └── openai.yaml
        ├── references/
        │   └── ultracode-workflows.md
        └── scripts/
            ├── dispatch-claude-code.ps1
            └── get-claude-workflow-status.ps1
```

## 兼容性与声明

- 当前实现主要面向 Windows。
- Claude Code 的 Workflow 内部接口可能随版本变化。
- 本项目不是 Anthropic 或 OpenAI 官方项目。
- Claude、Claude Code、Codex 等名称归各自权利人所有。

## 许可证

[MIT License](LICENSE)
