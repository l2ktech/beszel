# 2026-03-08：jetson 离线排查与 Codex 配置同步

## planning
- 复用任务：`planning/05-20260303-192193网络波动掉线采集告警/`
- 复用判定：相似度 `99%`，不新建 planning 目录。
- 目标：
  1. 解释 `jetson` 为什么在 Beszel 中显示 `down`。
  2. 在不破坏现有数据的前提下恢复 `jetson` 在线状态。
  3. 将 `jetson` 上的 Codex 共享配置与登录态同步到最新。

## implementation
### 1) Beszel 离线根因定位
- Hub 数据库中 `jetson.host` 当时记录为 `192.168.193.201:45876`。
- 本机实测：
  - `192.168.192.201`：`ping` 正常，`22` / `45876` 端口可达。
  - `192.168.193.201`：`ping`、`22`、`45876` 全部超时。
- 使用 Hub 私钥 `beszel_data/id_ed25519` 直连 `192.168.192.201:45876` 可以正常认证并返回 agent stats，说明：
  - agent 本身在运行
  - Hub 密钥未失效
  - 根因聚焦到 `193` 地址不可达

### 2) Beszel 监控恢复
- 先备份数据库：`beszel_data/data.db.bak.20260308-153411.jetson-host-fallback`
- 将 `systems.host` 临时改回：`192.168.192.201`
- 重启 Hub：`docker compose restart beszel`
- 轮询验证：约 15 秒后 `jetson.status` 从 `down` 恢复为 `up`

### 3) Codex 配置同步
- 通过 `jetson@192.168.192.201` + `~/.ssh/id_rsa_github` 登录 shell。
- 确认远端仓库：`~/40-Projects/00-最新配置`
- 执行即时同步校验：仓库已追到 `9bcc083`，与本机 `origin/main` 一致。
- 校验映射：
  - `~/.codex/config.toml`
  - `~/.codex/skills`
  - `~/.codex/AGENTS.md`
  都已指向仓库内最新共享配置。
- 同步本机登录态：
  - `scp ~/.codex/auth.json jetson:~/.codex/auth.json`
  - 远端 `chmod 600 ~/.codex/auth.json`
  - 远端 `codex login status`

## completion
- Beszel 恢复结果：
  - `jetson.host=192.168.192.201`
  - `jetson.status=up`
  - `jetson.info.ct=1`
- 保留现状：`jetson.info.z193_status=down`
- Codex 同步结果：
  - 远端仓库 `HEAD=9bcc083`
  - `~/.codex/config.toml` 哈希与本机一致：
    - `28d4c2d6820e5ecdd760599371da5daa68914429db97c002580fd4f2db87a4a5`
  - `~/.codex/auth.json` 哈希与本机一致：
    - `9c118e9158b6ac82ea9579edeb82b4861ffae16d09ba573533d4f71d89762b0b`
  - `codex login status`：`Logged in using an API key`
- 定时同步状态：
  - `opencode-sync.timer` 已启用并处于 active
  - 当前远端 timer 文案显示为“每30分钟检查一次”

## project_summary
- `08-Beszel` 当前承担 `jetson` 的在线性监控与 `192/193` 网络状态采集。
- 本次排障表明：`jetson` 的 Beszel 掉线并非 agent 崩溃，而是监控地址切到 `193` 后设备侧网络再次失效。
- 与此同时，`jetson` 上的 Codex 共享配置与 skills 已经和本机保持一致，并补齐了当前登录态。

## usage_guide
### Beszel 快速自检
- 查看 `jetson` 状态：
  - `sqlite3 beszel_data/data.db "select name,host,status,updated from systems where name='jetson';"`
- 验证 agent 可达：
  - `nc -vz 192.168.192.201 45876`
- 用 Hub 私钥验证 agent：
  - `ssh -i beszel_data/id_ed25519 -p 45876 root@192.168.192.201`

### jetson Codex 快速自检
- SSH 登录：
  - `ssh -F /dev/null -i ~/.ssh/id_rsa_github -o IdentitiesOnly=yes jetson@192.168.192.201`
- 查看远端仓库版本：
  - `cd ~/40-Projects/00-最新配置 && git rev-parse --short HEAD`
- 查看 Codex 配置映射：
  - `readlink ~/.codex/config.toml`
  - `readlink ~/.codex/skills`
  - `readlink ~/.codex/AGENTS.md`
- 检查登录状态：
  - `codex login status`

### 后续建议
- 如果目标是继续统一到 `192.168.193.*`：
  - 需要单独修复 jetson 的 `193` 网络连通性，再把 `systems.host` 切回 `192.168.193.201`
- 如果只是确保监控在线：
  - 当前 `192.168.192.201` fallback 可继续稳定使用
