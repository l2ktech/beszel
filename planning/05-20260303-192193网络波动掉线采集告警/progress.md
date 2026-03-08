# 进度日志

## 会话 2026-03-03
### 完成
- [x] 完成 planning 查重与新建任务目录
- [x] 完成现有采集与调度路径盘点
- [x] 完成 Grok 优先检索并固化告警防抖策略
- [x] 完成 `scripts/zt_latency_sync.sh` 采集增强（抖动/掉线/状态机）
- [x] 完成钉钉加签告警发送能力接入（含 `errcode` 校验）
- [x] 新增告警配置模板 `scripts/zt_alert.env.example`
- [x] 新增运行时配置 `scripts/zt_alert.env`（并加入 `.gitignore`）
- [x] 完成 DB 字段写入与告警实测（BE6500 离线告警已发送）
- [x] 修复告警边界：持续掉线/持续高抖动可按冷却时间重复提醒
- [x] 完成 webhook 自检（HTTP 200 + `errcode=0`）
- [x] 完成持续掉线复测（`BE6500` 定向触发，日志 `dingtalk send ok`）
- [x] 完成本地提交：`a79f9602`
- [x] 完成 MCP 钉钉任务通知发送

### 阻塞
- `git push` 返回 `403`（`Permission to henrygd/beszel.git denied to l2ktech`），当前环境无远端写权限。

### 问题
- **问题**：用户希望对每台设备增加双网络波动与掉线告警，但现有只采集基础延迟。
- **解决**：进入脚本扩展方案设计与实现阶段。

- **问题**：首次实现出现 SQL 组装错误（空字段导致 `json_set(..., , ...)`）。
- **解决**：增加 `to_int` 归一化函数，对历史字段统一强制数值化，已修复。

## 会话 2026-03-04
### 完成
- [x] 复用本任务 planning（相似度 95%）并补全查重记录
- [x] 完成项目健康核验：容器与 `/api/health` 正常
- [x] 定位采集停更根因：`${1,,}` 在 macOS Bash 3.2 下不兼容导致脚本中断
- [x] 修复兼容问题：`is_true` 改为 `tr` 小写转换
- [x] 实现仅 193 探测：移除 192 探测与 192 告警触发，`z192_status=disabled`
- [x] 增加图表化时序采集：写入 `system_stats.type='zt1m'`（`z193l/z193j/z193s`）
- [x] 前端新增 `ZT 193 Latency` 曲线图，读取 `zt1m` 数据
- [x] 本地验证通过：`bash -n`、脚本执行、DB 查询、`internal/site` 构建
- [x] 完成部署：`docker build -f internal/dockerfile_hub -t beszel:zt-latency-email .` 并 `docker compose up -d beszel`
- [x] 可用性验证：`/api/health` 返回 200
- [x] 完成本地提交：`3981dc8f`
- [x] 复用 planning 执行 th16 连通性排查（目标更正为 `192.168.193.13:38005`）
- [x] 本机验证 `.13:38005`：`ping` 正常、`nc` 可连、`curl` 返回 `HTTP 200`
- [x] 远端交叉验证：`192.168.193.10` 访问 `.13:38005` 返回 `HTTP 200`
- [x] 完成 `192.168.193.*` 存活探测（大多数节点在线）
- [x] 输出结论：服务端与网段整体正常，问题聚焦 th16 本机侧
- [x] 完成 MCP 钉钉任务通知发送

### 问题
- **问题**：前端构建初次失败（`lingui: command not found`）。
- **解决**：执行 `cd internal/site && npm install` 后，`npm run -s build` 通过。

- **问题**：`git push` 返回 `403`（`Permission to henrygd/beszel.git denied to l2ktech`）。
- **解决**：已保留本地提交并发送钉钉通知，等待切换有权限的 remote 凭据后补推送。

## 会话 2026-03-04（192->193 批量替换）
### 完成
- [x] 复用本任务 planning 并补充增量查重记录
- [x] 备份数据库：`beszel_data/data.db.bak.20260304-171733.ip192to193`
- [x] 批量替换 `systems.host`：`192.168.192.* -> 192.168.193.*`
- [x] 重启 hub 并验证健康接口（`/api/health` = 200）
- [x] 等待一个轮询周期后复测状态：`up=12 / down=2`

### 问题
- **问题**：地址切换后仍有两台离线（`15Xpro-wsl`、`SjH-OpenWrt`）。
- **解决**：已确认不是批量地址配置问题，需单机排查 agent 服务/端口或网络策略。

- **问题**：`win-cli` SSH MCP 接口全部报 response body 解码错误，无法直接做 SSH MCP 连通性测试。
- **解决**：改用本机 SSH + 远端节点交叉验证完成诊断；`th16` 仍需可用凭据后补最终远端命令。

- **问题**：`git push` 返回 `403`（`Permission to henrygd/beszel.git denied to l2ktech`）。
- **解决**：已完成本地提交 `65640646`，待切换有写权限的 remote 凭据后补推送。

## 会话 2026-03-04（首页/记录页193延迟展示修复）
### 完成
- [x] 复用本任务 planning 并补充增量查重记录（相似度 97%）
- [x] 定位首页缺失根因：`systems-table-columns.tsx` 未定义 `z193` 字段列
- [x] 首页新增 `ZT 193 Latency` 列，展示 `info.z193 / info.z193_jitter / info.z193_status`
- [x] 记录页（Alert History）新增 `ZT 193 Latency` 采样记录表，数据源 `system_stats.type='zt1m'`
- [x] 为记录页 `zt1m` 表接入实时订阅，新增采样自动刷新
- [x] 前端构建验证通过：`cd internal/site && npm run -s build`
- [x] 部署更新：`docker build -f internal/dockerfile_hub -t beszel:zt-latency-email .` + `docker compose up -d beszel`
- [x] 可用性验证：`curl http://127.0.0.1:38005/api/health` 返回 `200`
- [x] 数据持续更新验证通过：65 秒复测 `zt1m` 从 `966` 增长到 `980`，最新时间前进到 `2026-03-04 09:50:17Z`
- [x] 完成本地提交：`2b630395`
- [x] 文档补充提交：`105a31f3`（planning/progress + 文档部署验证记录）
- [x] 进度收口提交：`a9f653b7`（记录最终提交与推送状态）
- [x] 最终日志提交：`6892ed5c`（planning 会话收尾）

### 问题
- **问题**：`npm run -s check` 在项目现状下存在大量历史 lint/format 诊断，无法作为本次改动门禁。
- **解决**：使用 `npx tsc --noEmit` + `npm run -s build` 验证本次改动可编译、可打包，并单独核验 `zt1m` 数据实时增长。

- **问题**：`git push` 返回 `403`（`Permission to henrygd/beszel.git denied to l2ktech`）。
- **解决**：已保留本地提交 `2b630395`，待切换有写权限凭据后补推送。

## 会话 2026-03-05（历史页仅延迟可见/其余图表数据准备中）
### 完成
- [x] 复用本任务 planning 并补充增量查重记录（相似度 98%）
- [x] 定位现象：`zt1m` 持续增长，但 `system_stats` 的原生类型（特别是 `1m`）几乎停更
- [x] 实测确认：重启前只有少量系统有 `1m` 新样本，导致多数图表显示“数据准备中”
- [x] 后端修复：`internal/hub/systems/system.go` 为 SSH 采集增加 `decode/wait` 超时保护，避免 goroutine 卡死
- [x] 本地验证：`go build ./internal/cmd/hub` 通过
- [x] 部署更新：`docker build -f internal/dockerfile_hub -t beszel:zt-latency-email .` + `docker compose up -d beszel`
- [x] 健康检查：`curl http://127.0.0.1:38005/api/health` 返回 `200`
- [x] 修复验证：重启后 12 台 `up` 系统均恢复 `1m` 写入（每台都有最近样本），`zt1m` 继续稳定增长
- [x] 完成本地提交：`259a24b4`
- [x] 进度补充提交：`01605673`

### 问题
- **问题**：Hub 原生采集在部分 SSH 系统上出现“状态不降级但采集线程卡住”，前端表现为除延迟外都“数据准备中”。
- **解决**：增加 SSH 解码与会话等待超时，避免无限阻塞；重建 Hub 后原生 `1m` 采样恢复。

- **问题**：`git push` 返回 `403`（`Permission to henrygd/beszel.git denied to l2ktech`）。
- **解决**：已保留本地提交 `259a24b4`、`01605673`，待切换有写权限凭据后补推送。

## 会话 2026-03-05（二次“数据准备中” + 两台 down 收口）
### 完成
- [x] 复现实况：用户反馈“正在收集足够的数据来显示”，DB 显示 `zt1m` 连续、`1m` 再次停更
- [x] 二次修复后端：`runSSHOperation` 增加会话级总超时，覆盖 `Shell/Encode` 等潜在阻塞点
- [x] 本地验证通过：`go build ./internal/cmd/hub`
- [x] 部署更新：`docker build -f internal/dockerfile_hub -t beszel:zt-latency-email .` + `docker compose up -d beszel`
- [x] 修复验证通过：85 秒复测 `1m` 从 `155` 增长到 `181`
- [x] `15Xpro-wsl` 修复闭环：`192.168.193.17:22022` SSH 可达，`45877` 监听正常，状态恢复 `up`
- [x] `SjH-OpenWrt` 修复闭环：确认设备本机 agent 正常，临时切换主机到 `192.168.1.1:45876` 后恢复 `up`
- [x] 最终状态：`up=14 / down=0`，`1m` 与 `zt1m` 均持续更新

### 问题
- **问题**：`win-cli` SSH MCP 仍返回 response body 解码错误，无法按用户要求直接使用 MCP 连接。
- **解决**：改用本机 SSH + 跳板 SSH（`rock5c`）完成远端修复与验证，并在 planning 中保留 MCP 故障记录。

- **问题**：`SjH-OpenWrt` 的 193 网络成员长期 `REQUESTING_CONFIGURATION`，无法在本会话内恢复 `192.168.193.203`。
- **解决**：先切换为可达管理地址 `192.168.1.1` 保证监控恢复；后续待 ZeroTier 控制面授权完成后再切回 193 地址。

## 会话 2026-03-05（系统表流量/资源数值异常一致）
### 完成
- [x] 复用本任务 planning 并补充增量查重记录（相似度 96%）
- [x] 定位根因：`SjH-OpenWrt` 临时指向 `192.168.1.1:45876`，与 `BE6500` 实际同机，导致双记录读取同一数据源
- [x] 完成同机证据校验：`192.168.193.16:35622` 与 `192.168.1.1:35622` SSH 指纹一致
- [x] 修复映射：`SjH-OpenWrt.host` 回切 `192.168.193.203`，并清空旧 `info` 防止继续展示缓存指标
- [x] Hub 健康验证：`/api/health` 返回 200
- [x] 完成 MCP 钉钉任务通知发送

### 问题与解决
- **问题**：用户观察到“多个客户端流量/CPU/内存几乎一致”，怀疑采集异常。
- **解决**：确认属于系统映射重复（同一设备双地址）而非采集算法错误；已回切 `SjH` 到真实地址，消除重复数据展示。

## 会话 2026-03-08（UI 未更新 / 数据停更 / SQLite 恢复）
### 完成
- [x] 复用本任务 planning 并补充增量查重记录（相似度 99%）
- [x] 确认运行态：容器在线，但 `1m/zt1m` 最新样本停在 `2026-03-05`
- [x] 确认根因：`beszel_data/data.db` 损坏，`PRAGMA quick_check` 报 malformed
- [x] 离线演练 `.recover`，生成可通过 `quick_check` 的恢复库
- [x] 保留当前 `internal/hub/systems/system.go` SSH 总超时保护改动，并完成本地构建验证
- [x] 新增 Hub SQLite pragma 配置：支持 `BESZEL_HUB_SQLITE_JOURNAL_MODE` / `BESZEL_HUB_SQLITE_SYNCHRONOUS`
- [x] 将当前部署切换为 `DELETE/FULL`，避免 PocketBase 默认 WAL 在 bind mount 上再次损坏
- [x] 备份坏库并切换为恢复库，重建镜像 `beszel:zt-latency-email`，重新启动容器
- [x] 回归验证通过：85 秒内 `1m` 与 `zt1m` 均恢复连续增长
- [x] 手动补跑 `./scripts/zt_latency_sync.sh`，确认自定义 193 延迟链路正常
- [x] 同步 planning / 项目文档 / Obsidian

### 问题与解决
- **问题**：恢复库首次上线后，PocketBase 重新以 WAL 模式打开数据库，普通查询很快再次报 malformed。
- **解决**：不是恢复库本身失效，而是 WAL + bind mount 组合继续引入坏写；通过新增可配置 DB pragmas，并在 compose 中切到 `journal_mode=DELETE`、`synchronous=FULL` 根治。

- **问题**：启动日志保留过一次 `database disk image is malformed: malformed database schema ...`。
- **解决**：重启后不再复现，且 `pragma quick_check=ok`、采样持续增长，判定为恢复过程中的历史残留日志，不再阻塞本次交付。

### 当前状态
- `1m` 最新样本：`2026-03-08 08:25:34+08:00`
- `zt1m` 最新样本：`2026-03-08 08:25:30+08:00`
- Hub 健康：`curl http://127.0.0.1:38005/api/health` 返回 `200`
- DB 状态：`pragma journal_mode=delete`，`pragma quick_check=ok`
- 剩余节点：`jetson=down`、`SjH-OpenWrt=paused`（历史设备侧问题，未影响本次主链路恢复）

## 会话 2026-03-08（193 列空白 / 系统页空白 / 首页全展开）
### 完成
- [x] 确认当前采样持续更新：`1m` 最新样本推进到 `2026-03-08 08:44:45 CST`，`zt1m` 推进到 `2026-03-08 08:45:08 CST`
- [x] 定位 193 列空白根因：Hub 保存 `systems.info` 时覆盖掉脚本注入的 `z193*` 字段
- [x] 修复后端：保留 `systems.info` 中非原生字段，避免 `z193/z193_jitter/z193_status/zt_probe_ts` 被覆盖
- [x] 修复前端：首页系统表在 `rows<=100` 时直接全量展开，不再默认只露出约 7 行
- [x] 重新构建前端：`cd internal/site && npm run -s build`
- [x] 重新构建并部署 Hub：`docker build -f internal/dockerfile_hub -t beszel:zt-latency-email .` + `docker compose up -d beszel`
- [x] 验证通过：根页面切到新资产 `index-DVLGcacx.js`，`systems.info.z193*` 恢复稳定写入

### 当前状态
- 在线节点（12 台）原生 `1m` 与 `zt1m` 都在正常推进
- `ZT 193 Latency` 列已恢复可显示数值
- 首页系统表已改为小规模节点直接全展开
- 历史异常节点仍是：`jetson=down`、`SjH-OpenWrt=paused`


## 会话 2026-03-08（个人仓库保存 / README / top磁盘排查）
### 完成
- [x] 确认个人仓库存在：`https://github.com/l2ktech/beszel`，已添加 remote `personal`
- [x] 更新 `readme.md`，补充本地最新改动说明
- [x] 连接 `top-rustdesk(192.168.193.9:35622)`，确认根盘 `98%`，`/var/lib/docker` 占用约 `57GB`
- [ ] 继续定位 Docker/ClickHouse 明细并判断可清理项
- [ ] 整理提交并推送到个人仓库


## 会话 2026-03-08（Status 开关联动 zT 通知）
### 完成
- [x] 确认小铃铛 `Status` 开关的数据来源：`alerts` 表中的 `name='Status'` 记录
- [x] 修改 `scripts/zt_latency_sync.sh`：发送 zT 通知前先检查当前系统是否存在 `Status` 告警记录
- [x] 本地语法校验通过：`bash -n scripts/zt_latency_sync.sh`
- [x] 手动执行脚本验证：`jetson` / `SjH-OpenWrt` 在 `Status` 关闭时不再推进 `z193_last_offline_alert_ts`
- [x] 更新 planning / 文档 / README / Obsidian

### 当前状态
- `Status` 打开：该设备允许发送 zT `offline/recovery/jitter` 钉钉通知
- `Status` 关闭：该设备继续采样 `z193`，但 zT 钉钉通知静默


## 会话 2026-03-08（MacBook 改为 WebSocket）
### 完成
- [x] 定位 MacBook 红色掉线现象：最新一次 `Status` 抖动约 48 秒，且与 `z193` 探测同一分钟一起掉线
- [x] 连接 `MacBook(192.168.193.18)` 检查 agent、launchd、端口监听与 Hub 可达性
- [x] 确认现状为 SSH 模式（`ct=1`），并抓到 WebSocket 接入初次失败原因为 token 无效
- [x] 为 MacBook 在 Hub 中刷新专属 token，并更新远端 launchd 配置为 `HUB_URL + TOKEN + KEY + LISTEN`
- [x] 重启 MacBook agent，验证成功建立 WebSocket 连接（`ct=2`）
- [x] 观察 75 秒：未新增新的 `Status` 掉线事件

### 当前状态
- `macbook` 当前连接模式：`WebSocket (ct=2)`
- 当前状态：`up`
- 现象缓解：切换后的观察窗口内未再出现“红色掉线闪一下”


## 会话 2026-03-08（DS224 群晖接入 Beszel）
### 完成
- [x] 从现有笔记中确认 DS224 信息：`wzy@192.168.1.100:35622` 可用，群晖支持 Docker / Container Manager
- [x] 在 Hub 中为 `ds224` 创建系统记录与专属 token / fingerprint 占位
- [x] 通过 SSH 登录群晖，并使用 `sudo` 在 `/volume3/docker/beszel-agent` 下部署 `henrygd/beszel-agent:latest`
- [x] 配置 `HUB_URL=http://192.168.1.4:38005`，采用 WebSocket 常连接模式
- [x] 验证容器日志出现 `WebSocket connected host=192.168.1.4:38005`
- [x] 验证 Hub 中 `ds224.status=up`、`ds224.info.ct=2`、agent 版本 `0.18.4`

### 当前状态
- `ds224` 已接入 Beszel
- 连接方式：`WebSocket (ct=2)`
- 采集方式：常连接，不依赖 SSH 轮询


## 会话 2026-03-08（DS224 运维与安全审计）
### 完成
- [x] 复核 DS224 当前 Beszel 状态：`up` + `ct=2`
- [x] 抽样检查 DSM 版本、磁盘、内存、主要容器、主要高占用进程
- [x] 抽样检查 SSH 配置、authorized_keys、认证失败日志与计划任务
- [x] 输出可优化项与安全风险判断
- [x] 将连接方式、部署命令与审计结论写入 Obsidian `SRV-007: 群晖NAS (DS224+)`

### 当前判断
- 运行状态：正常
- 采集状态：正常（WebSocket 常连接）
- 优化优先级：`SSH密码登录`、`Docker/Container Manager 版本`、`外露端口收敛`、`Syncthing` 负载关注
- 安全结论：未发现明确入侵证据，但当前暴露面与认证方式仍建议加固


## 会话 2026-03-08（DS224 运维与安全体检）
### 完成
- [x] 连接 DS224 并确认 DSM / Docker / Beszel 当前运行态
- [x] 识别当前主要容器服务：`beszel-agent`、`zerotier`、`docker-registry`、`gitea`、`dify-on-wechat`
- [x] 抽查系统资源：根盘、数据卷、内存、主要进程
- [x] 抽查安全面：SSH 配置、授权公钥、账户清单、认证失败日志
- [x] 停掉并禁用旧的本机版 `beszel-agent` systemd 服务，保留容器版 WebSocket 常连接
- [x] 将 DS224 连接/部署/审计结论写入 Obsidian 服务器笔记

### 当前状态
- DS224 已接入 Beszel，连接模式 `ct=2`
- 群晖当前总体运行正常，未发现明确被入侵证据
- 主要待优化点：SSH 密码登录、旧 Docker 版本、旧 agent 文件清理、端口暴露面治理

## 会话 2026-03-08（jetson 不在线排查与 Codex 配置同步）
### 完成
- [x] 复用 `planning/05-20260303-192193网络波动掉线采集告警/` 并补充增量查重记录（相似度 `99%`）
- [x] 确认 `jetson` 当前记录地址为 `192.168.193.201`，且状态为 `down`
- [x] 对比连通性：`192.168.192.201` 的 `ping/22/45876` 均正常，`192.168.193.201` 全部超时
- [x] 使用 `beszel_data/id_ed25519` 直连 `192.168.192.201:45876`，确认 agent 与 Hub 密钥链路正常
- [x] 备份数据库：`beszel_data/data.db.bak.20260308-153411.jetson-host-fallback`
- [x] 将 `jetson.host` 临时回切为 `192.168.192.201`，重启 Hub 后验证 `jetson.status=up`
- [x] 使用 `~/.ssh/id_rsa_github` 连接 `jetson@192.168.192.201`，确认 `~/40-Projects/00-最新配置` 存在且定时同步已启用
- [x] 执行一次即时同步校验：远端配置仓库已在 `9bcc083`，`~/.codex/*` 链接均正确
- [x] 同步本机 `~/.codex/auth.json` 到 jetson，并验证远端 `codex login status`
- [x] 更新 planning / 项目文档 / Obsidian / 通知

### 当前状态
- `jetson.status=up`
- `jetson.host=192.168.192.201`（临时 fallback）
- `jetson.info.ct=1`
- `jetson.info.z193_status=down`
- `jetson ~/40-Projects/00-最新配置 HEAD=9bcc083`
- `jetson ~/.codex/config.toml` 已链接到仓库最新版本
- `jetson Codex` 当前登录态：`Logged in using an API key`

### 问题
- **问题**：默认 SSH 参数下无法直接拿到 jetson shell 登录结论，容易误判为“SSH 不可用”。
- **解决**：改用笔记中记录的 `jetson@192.168.192.201 + ~/.ssh/id_rsa_github` 明确验证，确认 shell SSH 正常可用。

- **问题**：`win-cli` SSH MCP 仍然无法使用，返回 `response body` 解码错误。
- **解决**：本次统一改用本机 `ssh/scp` 兜底完成 Beszel 与 Codex 两条链路的验证和同步。

- **问题**：`jetson` 的自动同步定时器实际为 30 分钟一次，与 README 中“5 分钟”描述不一致。
- **解决**：本次已手动确认即时状态；后续如需消除认知偏差，需回仓库统一 README / timer 文案。

## 会话 2026-03-08（全节点掉线恢复与 jetson 193 真正修复）
### 完成
- [x] 发现 Beszel 全节点同时 `down`，但本机到各节点 `193/192` 地址与 `45876` 端口仍普遍可达
- [x] 确认连 WebSocket 的 `ds224` 也被打成 `down`，据此排除“SSH 轮询单点故障”
- [x] 确认 live DB 再次损坏：`pragma quick_check` 报 `idx_GxIee0j`、`sqlite_autoindex_system_stats_1` 与 freelist 错误
- [x] 停止 Hub 与 `com.wzy.beszel.zt-latency-sync` 写库任务，尝试 `reindex/vacuum` 失败，改用最近干净备份恢复
- [x] 使用 `beszel_data/data.db.bak.20260308-153411.jetson-host-fallback` 恢复 live DB，并重启 Hub
- [x] 验证恢复成功：约 15 秒内状态回到 `up=14 / paused=1`
- [x] 保持 `zt-latency-sync` 暂停，避免立即再次把 DB 写坏
- [x] 远端确认 `jetson` 同时存在 `zerotier-one` 与 `zerotier-self` 两个实例，`ztdfilglme=192.168.193.201` 为真实 193 接口
- [x] 验证 `192.168.193.201` 再次可达，且 Hub 私钥可成功登录 agent 端口 `45876`
- [x] 将 `jetson.host` 切回 `192.168.193.201`，并连续两轮验证保持 `up`
- [x] 更新 planning / 项目文档 / Obsidian / 通知

### 当前状态
- Beszel：`up=14 / paused=1 / down=0`
- `jetson.host=192.168.193.201`
- `jetson.status=up`
- `1m` 采样已恢复推进
- `zt1m` 采样当前暂停在恢复前时间点（因为临时停掉了 host 侧写库任务）
- `com.wzy.beszel.zt-latency-sync` 当前为停止状态，等待后续改安全写入路径再恢复

### 问题与解决
- **问题**：当前 live DB 已损坏到无法原地 `reindex`，继续强修风险很高。
- **解决**：回滚到最近一份 `quick_check=ok` 的备份，并保留损坏库备查。

- **问题**：用户感知为“全部节点都掉了”，容易误以为是 ZeroTier 全网挂了。
- **解决**：通过本机到多节点端口连通性、以及 `ds224(ct=2)` 也掉线这一事实，快速收敛到 Hub/DB 层故障。

- **问题**：`jetson` 的 193 地址此前短时不可达，且有两个 ZeroTier 实例并存，排障路径容易混淆。
- **解决**：最终确认第二实例 `zerotier-self.service` 负责 `192.168.193.201`，待其恢复可达后，再将 Beszel 地址切回 `193`。

## 会话 2026-03-08（jetson 193 真正修复）
### 完成
- [x] 识别 `jetson` 存在双 ZeroTier 实例：`192` 主实例 + `193` 的 `zerotier-self`
- [x] 确认 `192.168.193.201` 本机地址存在，问题是 self-hosted 193 网络 peer path 卡死，而不是接口缺失
- [x] 抓到异常 peer：本机侧 `fe39a37bbb=-1`、jetson 侧 `88fd07d63b=-1`
- [x] 刷新 193 会话后恢复双向 peer：本机看到 `fe39a37bbb 192.168.1.116/29993`，jetson 看到 `88fd07d63b 192.168.1.4/9993`
- [x] 验证本机到 `192.168.193.201` 的 `ping/22/45876` 全部恢复
- [x] 发现运行中的 Hub 会把直接改库的 `host` 覆写回旧值，因此改为：`docker compose stop beszel -> sqlite3 update -> docker compose up -d beszel`
- [x] 将 `jetson.host` 正式切回 `192.168.193.201`
- [x] 手动补跑 `./scripts/zt_latency_sync.sh`，确认 `jetson z193=1ms, z193_status=up`
- [x] 连续约 40+ 秒观察：`host/status/z193_status` 均保持稳定
- [x] 更新 planning / 项目文档 / Obsidian / 通知

### 当前状态
- `jetson.host=192.168.193.201`
- `jetson.status=up`
- `jetson.info.ct=1`
- `jetson.info.z193=1`
- `jetson.info.z193_status=up`
- 本机到 `192.168.193.201:45876` 连续可达

### 问题与解决
- **问题**：`192.168.193.201` 明明在 jetson 上存在，但本机始终打不通。
- **解决**：定位为 `5cb1bf45e10c6865` 自建 193 网络中 `macmini <-> jetson` 的 peer path 卡死，刷新会话后恢复。

- **问题**：直接在运行中的 Hub 里改 `systems.host` 会被旧内存态覆盖回 `192.168.192.201`。
- **解决**：改为停掉 Hub 后更新数据库，再重新启动 Hub，让 `193` 地址稳定生效。

## 会话 2026-03-08（zt-latency-sync 改为 Hub API 安全写入）
### 完成
- [x] 确认旧版 `zt_latency_sync.sh` 仍直接对 `beszel_data/data.db` 执行 `UPDATE systems + INSERT system_stats(type='zt1m')`
- [x] 在 Hub 中新增认证保护接口：`POST /api/beszel/zt-latency-sync`
- [x] 脚本改为：只读 SQLite 取旧状态 + 通过 Hub API 认证写入 `systems.info` 与 `zt1m`
- [x] 新增脚本认证回退链：`HUB_AUTH_TOKEN` -> `HUB_EMAIL/HUB_PASSWORD` -> `docker-compose.yml` 中的 Hub 用户密码
- [x] 重建并部署 Hub：`docker build -f internal/dockerfile_hub -t beszel:zt-latency-email . && docker compose up -d beszel`
- [x] 手动执行脚本验证通过：`zt1m` 时间推进、`quick_check=ok`
- [x] 修复 launchd 下 `mktemp` 模板与 `trap` 空变量问题
- [x] 恢复 `com.wzy.beszel.zt-latency-sync` 定时任务，并验证完整一轮 `60s` 后 `zt1m` 再次推进且数据库仍为 `ok`
- [x] 更新 planning / 项目文档 / Obsidian / 通知

### 当前状态
- `quick_check=ok`
- `1m` 持续推进
- `zt1m` 持续推进
- `com.wzy.beszel.zt-latency-sync` 已恢复定时运行，`last exit code = 0`
- `jetson.host=192.168.193.201`，`jetson.status=up`，`jetson.info.z193_status=up`

### 问题与解决
- **问题**：即使切掉 host 侧写库任务，旧日志与 launchd 仍残留一次 `mktemp`/`payload_file` 相关异常，导致锁目录未清理。
- **解决**：修正 `mktemp` 的 macOS 模板写法，并将 `trap` 改为对 `${payload_file:-}` 做安全清理；清理旧锁目录后恢复正常。

- **问题**：launchd 首次 `kickstart` 后 `zt1m` 未推进，容易误判为新接口不可用。
- **解决**：核查日志后发现是旧锁目录拦截，而不是新接口失败；清锁后再次执行已恢复正常。

## 会话 2026-03-08（ds224 自定义 193 探测映射）
### 完成
- [x] 为 `zt_latency_sync.sh` 增加按系统名的 `193` 自定义探测目标映射能力
- [x] 在运行时配置中加入：`ZT_TARGET_193_MAP=ds224=192.168.193.188`
- [x] 手动执行脚本，确认 `ds224` 已按自定义映射路径执行探测
- [x] 确认当前 `192.168.193.188` 仍不可达，因此 `ds224.z193_status` 继续为 `down`

### 当前状态
- 自定义映射：已生效
- `ds224` 当前探测目标：`192.168.193.188`
- `ds224.z193_status=down`
- 根因：`ds224` 当前尚未真正加入 `193` 自建网络，`zerotier` 数据卷中仅有官方网络 `565799d8f61f7c2d.conf`

## 会话 2026-03-08（ds224 真正加入 193 并恢复 z193_status）
### 完成
- [x] 确认 `DS224` 的 Docker 版 `zerotier` 已切到自建 `planet`，但仍被宿主套件版 `zerotier` 抢占 `9993`
- [x] 停掉宿主套件版 `zerotier`，让 Docker 容器真正接管 ZeroTier 控制面
- [x] 发现 `DS224` 主机 `/dev/net/tun` 权限为 `600`，导致容器内 `zerotier-one`（UID 999）无法打开 TUN
- [x] 修复 TUN 权限并重启 `zerotier` 容器，成功拉起 `192` 与 `193` 双网络接口
- [x] 将 `DS224` 的容器节点 `16d72df3b4` 加入 `5cb1bf45e10c6865`，并在控制器中授权为 `192.168.193.188`
- [x] 确认 `4060 -> 192.168.193.188` 连通正常
- [x] 因 `macmini-self` 到 `DS224` 的 193 peer 仍不稳定，给 `ds224` 增加 `4060` 中继探测配置
- [x] 手动执行 `zt_latency_sync.sh`，验证 `ds224.z193_status=up`
- [x] 更新 planning / 项目文档 / Obsidian / 通知

### 当前状态
- `DS224` 现在已真正加入 `193` 自建网络
- `DS224` 静态地址：`192.168.193.188`
- `ds224.z193=22`
- `ds224.z193_status=up`
- `zt_latency_sync` 数据库健康：`quick_check=ok`

### 说明
- 当前 `ds224` 的 `z193` 由 `4060` 中继探测得到，原因是本机 `macmini-self` 到 `ds224` 的 peer 仍存在单点不稳定；但 `193` 网络本身已经真实可用。
