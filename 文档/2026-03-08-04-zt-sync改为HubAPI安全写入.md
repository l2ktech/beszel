# 2026-03-08：zt-latency-sync 改为 Hub API 安全写入

## planning
- 复用任务：`planning/05-20260303-192193网络波动掉线采集告警/`
- 目标：
  1. 去掉 `zt_latency_sync.sh` 对 SQLite 的直接写入。
  2. 恢复 `z193/zt1m` 持续采集。
  3. 避免再把整个 Beszel 状态层写崩。

## implementation
### 1) 问题点
- 原脚本在 host 侧直接执行：
  - `UPDATE systems SET info=json_set(...)`
  - `INSERT INTO system_stats (... type='zt1m' ...)`
- 与此同时，容器内 Hub 也在写同一个 bind mount SQLite 文件。
- 这会形成“宿主机 sqlite3 + 容器内 PocketBase”双写同库的竞争条件。

### 2) 改造方案
- 在 Hub 中新增认证保护接口：`POST /api/beszel/zt-latency-sync`
- 该接口在 Hub 进程内使用 PocketBase 事务：
  - 更新 `systems.info` 中的 `z193` 自定义字段
  - 插入 `system_stats.type='zt1m'`
- 脚本保留只读查询旧状态与告警状态机计算，但最终写入改为一次性 POST 到 Hub。

### 3) 脚本认证策略
- 优先使用：`HUB_AUTH_TOKEN`
- 否则使用：`HUB_EMAIL + HUB_PASSWORD`
- 若未显式配置，则从本地 `docker-compose.yml` 中解析：
  - `BESZEL_HUB_USER_EMAIL`
  - `BESZEL_HUB_USER_PASSWORD`
- 然后调用：
  - `POST /api/collections/users/auth-with-password`
  - `POST /api/beszel/zt-latency-sync`

### 4) 兼容修复
- 修复 `mktemp` 在 macOS 下的模板写法。
- 修复 `trap` 对未定义 `payload_file` 的清理问题。
- 清理旧锁目录后恢复 `launchd` 定时执行。

## completion
- `go test ./internal/hub/...` 通过。
- `bash -n scripts/zt_latency_sync.sh` 通过。
- 重建部署后，手动执行脚本可使 `zt1m` 时间推进，且 `pragma quick_check` 保持 `ok`。
- 恢复 `launchd` 后，完整等待一轮 `60s`，`zt1m` 再次推进，数据库仍然 `ok`。
- 说明新方案已经满足：
  - 不再直接写 SQLite
  - `z193/zt1m` 恢复
  - 不再把 Beszel 状态层写崩

## project_summary
- 这次改造把 zT 延迟采集从“宿主机直写库”改成了“宿主机计算 + Hub 事务写入”。
- Hub 成为唯一写入者后，SQLite bind mount 的竞争条件被消除，主监控链路和自定义采集链路终于可以并存。

## usage_guide
### 手动执行一次
- `bash scripts/zt_latency_sync.sh`

### 检查采样是否推进
- `sqlite3 beszel_data/data.db "select type, max(created), count(*) from system_stats where type in ('1m','zt1m') group by type;"`

### 检查数据库健康
- `sqlite3 beszel_data/data.db 'pragma quick_check;'`

### 可选配置
- `scripts/zt_alert.env` 支持：
  - `HUB_BASE_URL`
  - `HUB_AUTH_TOKEN`
  - `HUB_EMAIL`
  - `HUB_PASSWORD`

### 当前已知限制
- `ds224` 当前主记录地址仍是 `192.168.192.188`，脚本会推导到 `192.168.193.188` 进行探测，因此 `z193_status` 仍为 `down`。
- 若需要让这类“主地址不在 192/193 镜像规则内”的系统也正确采集 z193，后续需要单独补“系统级自定义探测目标映射”。
