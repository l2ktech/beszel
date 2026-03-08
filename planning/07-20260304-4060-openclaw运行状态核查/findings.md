# 研究发现

## 检索结论（Grok 优先）
- **发现**：openclaw 常见健康核验路径为“进程/容器状态 + 关键监听端口 + 健康接口 + 最近日志”四项组合判断。
- **来源**：Grok Search（`docs.openclaw.ai/install/docker`、`docs.openclaw.ai/logging`、`github.com/openclaw/openclaw/issues/27139`）
- **影响**：本次核验按四项执行，避免仅凭“进程存在”得出误判。

## 本地补充结论
- **发现**：仓库内未检索到 `openclaw` 直接配置；`~/.ssh/known_hosts` 显示 `4060` 历史连接端口为 `35622`，且 `192.168.192.10` 当前不可达、`192.168.193.10` 可达。
- **来源**：本地检索命令 `rg -n \"openclaw|4060\"`、`rg -n \"192.168.192.10|35622\" ~/.ssh -S`、`ping`
- **影响**：实际核验路径切换为 `wzy@192.168.193.10:35622`。

## 4060 实测结论
- **发现**：`openclaw --version` 为 `2026.3.2`；主进程 `openclaw-gateway` 持续运行（运行约 8.5 小时）；监听端口 `0.0.0.0:18789`、`127.0.0.1:18791`、`127.0.0.1:18792` 正常；`http://192.168.193.10:18789/` 返回 `200`。
- **来源**：远端命令 `openclaw --version`、`pgrep -af openclaw`、`ss -lntp`、`curl`
- **影响**：可判定 openclaw 网关服务处于“可用”状态。

## 风险与异常
- **发现**：`win-cli` SSH MCP 调用全部报“response body 解码错误”；`openclaw-gateway` 日志存在持续 bonjour 重发布提示，以及部分 `chatgpt.com` DNS 解析失败导致的 embedded agent error=500。
- **来源**：`win-cli-mcp` 调用返回、`journalctl --user -u openclaw-gateway --since \"2 hours ago\"`
- **影响**：不影响网关本体监听与页面访问，但可能影响依赖外网 DNS 的嵌入式代理任务稳定性，建议后续单独排障 DNS/出网策略。
