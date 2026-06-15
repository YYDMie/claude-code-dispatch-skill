# 安全说明

## 敏感信息

请勿在任务提示词、日志或状态文件中写入：

- API token
- GitHub token
- SSH 私钥
- 生产环境密码
- 用户隐私数据

派发产物默认写入目标仓库的 `.claude-dispatch` 目录。将代码提交到 Git 前，请确认该目录已被忽略或已清理。

## 权限模式

默认使用 Claude Code `auto` 权限模式。

仅在可信本地仓库、明确理解风险且确有需要时使用：

```text
-DangerouslySkipPermissions
```

## 漏洞报告

请通过 GitHub Security Advisory 私下报告可能导致命令注入、凭据泄露、越权文件访问或不安全进程控制的问题。
