# 研究发现

## planning 查重结果
- **发现**：无可复用的高相似任务（最高 46%）。
- **来源**：`planning/01-*`、`planning/02-*` 的 `task_plan/findings/progress` 内容对比。
- **影响**：按规范新建本次任务 planning。

## 容器运行状态（2026-03-03 15:37 CST）
- **发现**：`beszel`、`beszel-agent` 均为 `running/Up`，重启计数均为 `0`。
- **来源**：`docker compose ps`、`docker inspect`。
- **影响**：服务进程层面稳定，无崩溃重启迹象。

## Hub 可用性与 API 健康检查
- **发现**：`http://127.0.0.1:38005/` 返回 `200`，`/api/health` 返回 `200` 且响应 `API is healthy.`。
- **来源**：本机 `curl` 检查。
- **影响**：Hub Web 与后端 API 均可用。

## Agent 服务连通性
- **发现**：本机 `127.0.0.1:45876` 端口可连通。
- **来源**：本机 `nc -z 127.0.0.1 45876`。
- **影响**：Agent SSH 监听正常，Hub 具备连接基础条件。

## 日志风险判定
- **发现**：日志中的 `HUB_URL environment variable not set` 发生在 Agent 启动 WebSocket 客户端阶段；代码在该场景会回退为 SSH Server 模式。
- **来源**：`docker compose logs`，代码 `agent/client.go` 与 `agent/connection_manager.go`。
- **影响**：该告警在当前配置（未设置 `HUB_URL`）下属预期行为，不构成“运行异常”。
