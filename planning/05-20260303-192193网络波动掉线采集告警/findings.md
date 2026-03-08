# 研究发现

## 现有采集机制
- **发现**：`scripts/zt_latency_sync.sh` 每 60 秒探测并写入 `systems.info.z192/z193`，`-1` 表示不可达。
- **来源**：脚本源码与 launchd 配置。
- **影响**：具备基础延迟采集，但缺少抖动和掉线状态衍生指标。

## 现有告警机制边界
- **发现**：当前 Beszel 内建告警主要覆盖 CPU/Memory/Disk/Status；192/193 网络延迟字段未接入原生告警规则。
- **来源**：项目文档与现有 API 用法。
- **影响**：需在采集脚本侧补充“网络专用告警”能力。

## Grok 检索结论（阈值与防抖策略）
- **发现**：网络掉线告警应使用“连续样本触发”而非单次失败；波动告警应使用“抖动阈值 + 连续次数”避免瞬时抖动误报。
- **来源**：
  - https://www.kentik.com/kentipedia/network-monitoring-alerts/
  - https://www.ilert.com/blog/6-best-practices-for-tuning-network-monitoring-alerts
  - https://web-alert.io/blog/ping-monitoring-latency-packet-loss-uptime
- **影响**：最终采用 `offline_streak`、`jitter_warn_ms`、`jitter_streak`、`cooldown_sec` 四维策略。

## Grok 检索结论（钉钉加签）
- **发现**：钉钉机器人需 `timestamp + sign(HmacSHA256)` 且 payload 必须是 `msgtype=text` + `text.content`。
- **来源**：
  - https://open.dingtalk.com/document/dingstart/customize-robot-security-settings
  - https://open.dingtalk.com/document/dingstart/custom-bot-send-message-type
- **影响**：告警发送逻辑实现了签名计算与 `errcode` 校验，避免“HTTP 200 但业务失败”的误判。

## 实现落地
- **发现**：`scripts/zt_latency_sync.sh` 已扩展采集字段：
  - `z192_jitter/z193_jitter`
  - `z192_status/z193_status`
  - `z192_down_streak/z193_down_streak`
  - `z192_jitter_streak/z193_jitter_streak`
  - `z192_flap_count/z193_flap_count`
  - `z192/z193` 的 `last_*_alert_ts`
- **来源**：脚本改造与 DB 实测。
- **影响**：每台设备双网络的波动与掉线已进入持续采集。

## 本地验证结果
- **发现**：数据库已写入新增字段；示例：`BE6500` 的 `z192_down_streak=2` 且 `z192_last_offline_alert_ts` 已更新。
- **来源**：`sqlite3 beszel_data/data.db` 查询验证。
- **影响**：掉线状态机工作正常。

- **发现**：已成功触发并发送钉钉离线告警（`BE6500`、`net=192`），日志返回 `dingtalk send ok`。
- **来源**：脚本定向测试（`ALERT_SYSTEM_FILTER_REGEX='^BE6500$'`）。
- **影响**：告警链路可用，后续可按阈值策略运行。

- **发现**：Webhook 自检成功（HTTP 200 且 `errcode=0`），说明机器人 token/加签可用，非链路故障。
- **来源**：本机签名发送脚本测试。
- **影响**：若“看不到告警”，更可能是触发条件与冷却策略导致，而非 webhook 失效。

- **发现**：已将告警策略调整为“首次越阈值 + 冷却周期持续提醒”，避免长期掉线只报一次。
- **来源**：`scripts/zt_latency_sync.sh` 条件逻辑更新与 BE6500 复测日志。
- **影响**：持续异常场景可周期性通知，满足运维追踪需求。

## 2026-03-04 运行异常定位
- **发现**：`zt_latency_sync.sh` 在告警分支触发 `line 40: ${1,,}: bad substitution`，导致事务提交前中断，出现“日志在跑但数据不连续落库”。
- **来源**：`~/Library/Logs/com.wzy.beszel.zt-latency-sync.log` 与脚本源码 `is_true()`。
- **影响**：采集链路不稳定，`systems.zt_probe_ts` 与历史数据表现为间歇停更。

## 2026-03-04 仅193采集改造结果
- **发现**：已去除 192 探测，脚本仅探测 193 网络；`systems.info.z192_status` 固化为 `disabled`，193 状态机与告警继续工作。
- **来源**：`scripts/zt_latency_sync.sh` 改造后日志与 DB 查询。
- **影响**：减少无效探测与误告警，符合“只测试193”的需求。

## 2026-03-04 曲线数据接入结果
- **发现**：每次采样会写入 `system_stats.type='zt1m'`，字段为 `stats.z193l / stats.z193j / stats.z193s`。
- **来源**：`sqlite3 beszel_data/data.db` 查询验证（`type='zt1m'`）。
- **影响**：193 延迟具备独立时序数据源，可用于前端曲线展示且不干扰原有 CPU/内存图。

## 2026-03-04 数据持续更新验证
- **发现**：70 秒复测中，`zt1m` 记录数从 `56` 增加到 `70`，`BE6500` 的 `zt_probe_ts` 从 `1772613450` 增加到 `1772613514`。
- **来源**：两次间隔查询（2026-03-04 16:38:12 与 16:39:22 CST）。
- **影响**：修复后数据已恢复分钟级持续更新。

## 2026-03-04 系统地址 192->193 批量替换
- **发现**：`systems.host` 中 `192.168.192.*` 已全部替换为 `192.168.193.*`（替换前 11 台，替换后 0 台）。
- **来源**：`sqlite3 beszel_data/data.db` 批量更新与前后计数对比。
- **影响**：Hub 与采集脚本统一走 193 网段，避免继续命中 192 路由不通。

## 2026-03-04 切换后在线状态
- **发现**：Hub 重启并等待一个采集周期后，状态从 `up=5/down=9` 改善到 `up=12/down=2`。
- **来源**：`docker compose restart beszel` 后的 `systems.status` 聚合查询。
- **影响**：批量地址切换已直接恢复大部分节点在线，仅剩 `15Xpro-wsl`、`SjH-OpenWrt` 两台离线待单独排障。

## 2026-03-04 th16 访问 `192.168.193.13:38005` 排查
- **发现**：目标地址 `http://192.168.193.13:38005/` 当前服务正常；本机 `nc` 端口可连通，`curl` 返回 `HTTP 200`，页面可返回 Beszel HTML。
- **来源**：本机实测命令 `nc -vz -w 3 192.168.193.13 38005`、`curl -I http://192.168.193.13:38005/`（2026-03-04 16:54 CST）。
- **影响**：故障不在 `.13` 服务端监听或进程存活层面。

- **发现**：同网段另一节点 `192.168.193.10` 反向访问 `.13:38005` 同样返回 `HTTP 200`。
- **来源**：SSH 到 `wzy@192.168.193.10:35622` 后执行 `curl -I http://192.168.193.13:38005/`（2026-03-04 16:54 CST）。
- **影响**：`192.168.193.*` 横向连通性正常，问题更可能位于 `th16` 本机网络栈/代理/浏览器策略。

- **发现**：`192.168.193.*` 存活探测中，`1/9/10/13/14/15/16/18/20/201/202` 均可 ping；`17/203` 不通（历史上也可能为未启用节点）。
- **来源**：本机 ICMP 批量探测（2026-03-04 16:53 CST）。
- **影响**：当前网段整体在线，不支持“193 网段整体掉线”的假设。

- **发现**：`win-cli` SSH MCP 当前不可用（response decode error），`192.168.193.16:35622` 仅支持 `ssh-rsa` 且现有密钥鉴权失败，无法直接登录 th16 执行远端命令。
- **来源**：MCP 调用返回与 SSH 实测。
- **影响**：th16 侧需用户在本机补执行 2-3 条命令完成最终定位（`curl`/`nc`/`ip route`）。

## 2026-03-04 首页/记录页193延迟缺失定位与修复
- **发现**：首页缺失 `193` 延迟的直接原因是 `internal/site/src/components/systems-table/systems-table-columns.tsx` 未定义 `z193` 列，导致 Home 表格永远不渲染该指标。
- **来源**：源码检索与列定义核查（`home.tsx` -> `SystemsTable` -> `systems-table-columns.tsx`）。
- **影响**：用户在首页无法快速看到每台机器 `193` 延迟状态，只能进入系统详情页看曲线。

- **发现**：记录页（Alert History）仅订阅 `alerts_history` 集合，不包含 `system_stats.type='zt1m'`，因此看不到 `193` 延迟采样记录。
- **来源**：`internal/site/src/components/routes/settings/alerts-history-data-table.tsx`。
- **影响**：用户无法在“记录页”查看按时间落库的 193 延迟明细，误判为未采集。

- **发现**：已完成前端修复：首页新增 `ZT 193 Latency` 列；记录页新增 `ZT 193 Latency` 表（`system_stats.type='zt1m'`，含 `latency/jitter/state/created`）并接入实时订阅。
- **来源**：`systems-table-columns.tsx`、`alerts-history-data-table.tsx`、`types.d.ts`。
- **影响**：193 延迟在首页与记录页均可见，且记录页会随新采样自动刷新。

- **发现**：数据链路仍在持续更新，65 秒复测中 `zt1m` 记录从 `966` 增长到 `980`，`max(created)` 从 `2026-03-04 09:49:12.644Z` 前进到 `2026-03-04 09:50:17.529Z`。
- **来源**：`sqlite3 beszel_data/data.db` 前后对比查询。
- **影响**：可排除“采集停更”，当前问题属于前端展示缺口，已修复。

## 2026-03-05 “数据准备中”回归问题定位与修复
- **发现**：问题发生时 `system_stats` 仅 `zt1m` 在增长，原生统计类型停更（例如 `10m` 停在 `2026-03-04 11:10:00Z`，`20m` 停在 `2026-03-04 11:20:00Z`，`1m` 几乎为空）。
- **来源**：`sqlite3 beszel_data/data.db` 统计查询与 75 秒前后对比。
- **影响**：系统详情页除 `ZT 193 Latency` 外的大部分图表会长期显示“Waiting for enough records to display（数据准备中）”。

- **发现**：重启 Hub 后可短暂恢复 `1m` 写入，但覆盖系统不完整，说明不是 `zt1m` 脚本停更，而是 Hub 原生 SSH 采集线程存在阻塞风险。
- **来源**：重启前后 `1m` 分布对比与 `systems.updated` 时间线。
- **影响**：部分系统状态看似 `up`，但原生指标不会持续刷新，造成“延迟有数据、其余无数据”的假象。

- **发现**：`internal/hub/systems/system.go` 的 SSH 读取路径对 `cbor/json decode` 与 `session.Wait()` 缺少超时保护，遇到异常响应可能导致 goroutine 卡住。
- **来源**：源码审查（`fetchDataViaSSH`）。
- **影响**：单系统采集协程可无限阻塞，后续不再写 `1m`，且状态可能长期不更新。

- **发现**：已修复为超时保护：新增 `decodeWithTimeout` 与 `waitWithTimeout`，并在 SSH 读取流程中统一使用；超时会触发重试/降级而非永久卡死。
- **来源**：代码变更 `internal/hub/systems/system.go`。
- **影响**：采集协程可从异常响应中恢复，避免再次出现“其他图表一直数据准备中”。

- **发现**：修复部署后，12 台 `up` 系统均恢复 `1m` 样本写入（每台均有最近记录），`zt1m` 同时保持连续增长。
- **来源**：部署后多轮 DB 复测。
- **影响**：首页/历史页/系统详情的数据链路恢复一致，用户可同时看到延迟与原生资源曲线。

## 2026-03-05 “数据准备中”二次复发定位与修复
- **发现**：用户反馈“仍在收集足够数据”，复测发现 `zt1m` 持续增长，但 `1m` 在 `2026-03-05 00:39:19Z` 后再次停更；停更期间首页/详情页会再次出现“数据准备中”。
- **来源**：`sqlite3` 查询 `system_stats` 类型分布与 `max(created)`。
- **影响**：仅靠 `decode/wait` 超时仍不足以覆盖所有 SSH 卡死点，原生图表存在二次回归风险。

- **发现**：`fetchDataViaSSH` 仍可能在 `session.Shell()` / 编码写入等阶段挂起，`runSSHOperation` 缺少“整次会话操作总超时”，会导致 updater goroutine 卡住且状态不及时降级。
- **来源**：源码审查 `internal/hub/systems/system.go` 与停更分布（仅少数系统持续写入）。
- **影响**：出现“状态看似 up，但 1m 不再写入”的假在线。

- **发现**：已新增会话级总超时保护：`runSSHOperation(sessionTimeout, operationTimeout, ...)`，超时后主动 `session.Close()` 并触发重试/重连。
- **来源**：代码变更 `internal/hub/systems/system.go`。
- **影响**：任何 SSH 阶段阻塞都不会无限卡死，`1m` 采样恢复持续写入。

- **发现**：重建部署后 85 秒复测，`1m` 计数 `155 -> 181`，13 台在线主机均写入新样本，仅 `SjH-OpenWrt` 仍 `down`。
- **来源**：`docker build/up` 后两次 DB 对比查询。
- **影响**：二次回归已消除，图表“数据准备中”恢复正常退出。

## 2026-03-05 两台 down 设备修复结果
- **发现**：`15Xpro-wsl` 可通过 `192.168.193.17:22022` SSH 登录，agent 进程与 `45877` 监听正常；此前 `down` 为连接抖动导致，恢复后状态已转 `up` 并持续写入 `1m`。
- **来源**：SSH 实测（`pgrep/ss`）与 DB 状态对比。
- **影响**：`15Xpro-wsl` 监控链路恢复。

- **发现**：`SjH-OpenWrt` 本机 agent 正常（`/etc/init.d/beszel-agent`，`TOKEN=38ef8a20-7194-4207-9929-5cdc2821416b`，`PORT=45876`），但 `192.168.193.203` 对应网络长期 `REQUESTING_CONFIGURATION`，短期无法恢复到 193 地址。
- **来源**：经 `rock5c` 跳板 SSH 到 `192.168.1.1:35622`，执行 `zerotier-cli` 与进程检查。
- **影响**：根因在 ZeroTier 控制面分配，不是 agent 进程故障。

- **发现**：已执行兜底恢复：将 `SjH-OpenWrt.host` 临时改为 `192.168.1.1` 并重启 Hub，随后状态转 `up`，`1m` 新样本恢复写入。
- **来源**：DB 更新 + Hub 重启 + `system_stats` 验证。
- **影响**：当前 `up=14/down=0`，采集与图表全部恢复；后续可在控制面修复后再切回 `192.168.193.203`。

## 2026-03-05 系统表“流量偏高/多系统数值一致”定位
- **发现**：`BE6500` 与 `SjH-OpenWrt` 出现近似相同的 CPU/内存/磁盘/网络值，根因是 `SjH-OpenWrt` 仍使用临时兜底地址 `192.168.1.1:45876`，与 `BE6500` 的 `192.168.193.16` 实际为同一台设备。
- **来源**：数据库 `systems` 主机映射查询 + SSH host key 指纹比对（`192.168.193.16:35622` 与 `192.168.1.1:35622` 指纹一致 `SHA256:6fYNQn5g8laa033Qsp5T3IInNBAV2zQD1wn9QJIPa34`）。
- **影响**：UI 显示为“两个系统”，但数据源相同，导致看起来“多客户端数值一致/流量重复”。

- **发现**：`BE6500` 的网络值偏高本身是合理现象：该设备为网关，统计口径覆盖转发流量（含 LAN 客户端出网/回流），并非单一终端应用流量。
- **来源**：最新 `system_stats(1m)` 中 `ni` 接口明细（`eth1/eth1.1/pppoe-wan/utun` 等均有持续吞吐）。
- **影响**：网关类设备网络吞吐显著高于普通终端属正常行为。

## 2026-03-05 修复动作与结果
- **发现**：已将 `SjH-OpenWrt` 回切到真实目标 `192.168.193.203:45876`，并清空临时缓存指标（`info={}`）防止继续展示旧值。
- **来源**：`sqlite3 beszel_data/data.db` 更新 `systems` 记录。
- **影响**：`SjH-OpenWrt` 当前显示 `down`（待 193 网络恢复），不再复用 `BE6500` 数据。

- **发现**：Hub 服务可用性正常（`/api/health` 返回 200）。
- **来源**：`docker compose up -d beszel` + `curl http://127.0.0.1:38005/api/health`。
- **影响**：修复未引入服务可用性回归。

## 2026-03-08 UI 未更新 / 数据停更根因
- **发现**：运行中容器 `beszel:zt-latency-email` 已启动，但 `system_stats.type in ('1m','zt1m')` 的最新样本一度停在 `2026-03-05`，与用户反馈“界面没更新、很多数据不刷新”一致。
- **来源**：`docker compose ps`、`sqlite3 beszel_data/data.db "select type, max(created), count(*) ..."`。
- **影响**：问题首先是采集链路停更，不是单纯前端刷新问题。

## 2026-03-08 数据库损坏确认
- **发现**：`beszel_data/data.db` 执行 `PRAGMA quick_check` 报 `database disk image is malformed`，损坏集中在 `system_stats` 相关页与索引。
- **来源**：`sqlite3 beszel_data/data.db 'pragma quick_check;'`。
- **影响**：Hub 原生 `1m` 写入与自定义 `zt1m` 查询都会受影响，直接导致页面长期显示旧数据或“数据准备中”。

## 2026-03-08 现有修改影响评估
- **发现**：当前未提交的 `internal/hub/systems/system.go` 是 SSH 采集总超时保护，`go build ./internal/cmd/hub` 通过；该改动属于稳态增强，不会破坏主功能。
- **来源**：`git diff`、`go build ./internal/cmd/hub`。
- **影响**：用户之前的后端改动不是本次停更根因，应保留并一并部署。

## 2026-03-08 WAL / bind mount 风险确认
- **发现**：PocketBase 默认以 `journal_mode(WAL)` 连接 SQLite；在当前 macOS + OrbStack + bind mount `./beszel_data:/beszel_data` 环境下，恢复库一旦以 WAL 模式重新打开，查询很快再次报 malformed。
- **来源**：本地依赖源码 `github.com/pocketbase/pocketbase@v0.36.1/core/db_connect.go` 与实测（恢复库上线后普通查询再次失败，但 `immutable=1` 读取主库正常）。
- **影响**：若不调整 journal mode，仅恢复 `data.db` 不能根治，后续仍有再次损坏风险。

## 2026-03-08 修复方案与结果
- **发现**：为 Hub 新增可配置 SQLite pragma（`BESZEL_HUB_SQLITE_JOURNAL_MODE` / `BESZEL_HUB_SQLITE_SYNCHRONOUS`），当前部署设置为 `DELETE/FULL`；同时使用 `.recover` 离线恢复数据库并重新部署镜像。
- **来源**：`internal/cmd/hub/hub.go`、`docker-compose.yml`、`docker-compose.override.zt.yml`、`docker build -f internal/dockerfile_hub -t beszel:zt-latency-email .`。
- **影响**：恢复后 `pragma journal_mode=delete`、`pragma quick_check=ok`，数据库恢复到可稳定写入状态。

## 2026-03-08 回归验证
- **发现**：85 秒复测中，`1m` 从 `550` 增长到 `568`，`zt1m` 从 `13230` 增长到 `13272`，最新样本时间前进到 `2026-03-08 08:25:30+08:00`。
- **来源**：两次 `sqlite3 beszel_data/data.db "select type, max(created), count(*) ..."` 对比，以及 `./scripts/zt_latency_sync.sh` 手动补跑验证。
- **影响**：UI 所依赖的原生资源数据与 193 延迟数据均已恢复连续刷新，主功能可用。

## 2026-03-08 剩余问题
- **发现**：当前仍有两个历史节点状态未收口：`jetson=down`、`SjH-OpenWrt=paused`。
- **来源**：`sqlite3 beszel_data/data.db "select name,status,updated from systems"`。
- **影响**：这两个节点属于设备侧可用性问题，不影响本次“页面不刷新 / 数据停更 / 主链路失效”的主问题闭环。

## 2026-03-08 193 延迟列空白根因
- **发现**：`zt_latency_sync.sh` 实际每分钟都探测并写入 `z193/z193_jitter/z193_status`，日志显示最新值正常；但首页读取的 `systems.info.z193*` 在多数在线节点上被覆盖为空。
- **来源**：`/Users/wzy/Library/Logs/com.wzy.beszel.zt-latency-sync.log` 与 `sqlite3 beszel_data/data.db "select json_extract(info,'$.z193') ... from systems"` 对比。
- **影响**：问题不是 193 探测失败，而是 Hub 在保存系统状态时整块覆盖 `systems.info`，把脚本注入的自定义字段擦掉，导致首页 `ZT 193 Latency` 列显示空白。

## 2026-03-08 系统页“Waiting for enough records”判断
- **发现**：数据库中 12 台 `up` 节点的 `1m` 样本持续增长，最近样本推进到 `2026-03-08 08:44:45 CST`；前台根页面已切到新构建资产 `index-DVLGcacx.js`。
- **来源**：`sqlite3 beszel_data/data.db` 查询与 `curl http://127.0.0.1:38005/`。
- **影响**：系统页长期“Waiting for enough records to display”更可能是之前前端旧包/旧页面状态导致；当前运行包已更新，刷新后应按最新 `1m` 数据正常显示。

## 2026-03-08 客户端列表只显示 7 个根因
- **发现**：首页系统表使用虚拟滚动容器，默认 `max-h-[calc(100dvh-17rem)]`，视觉上只显示约 7 行，其余需要滚动。
- **来源**：`internal/site/src/components/systems-table/systems-table.tsx`。
- **影响**：这不是数据条数限制，而是前端表格容器高度限制；已按“小规模系统列表直接全展开”修复。


## 2026-03-08 top-rustdesk 磁盘占用根因
- **发现**：`top-rustdesk(192.168.193.9:35622)` 根分区 `98G` 中已使用 `92G`，主要占用来自 `/var/lib/docker` 的 `57GB`。
- **来源**：SSH 执行 `df -h /`、`du -x -d1 /var/lib`、`docker system df -v`。
- **影响**：并非系统盘被普通家目录吃满，而是 Docker 卷占用异常膨胀。

## 2026-03-08 top-rustdesk 实际大头
- **发现**：最大卷为 `langfuse_langfuse_clickhouse_data`，约 `48GB`；进一步确认是 ClickHouse 系统日志表异常膨胀：`system.trace_log≈40.92GiB`、`system.text_log≈1.86GiB`、`system.metric_log≈1.04GiB`、`system.asynchronous_metric_log≈1011MiB`。
- **来源**：`docker system df -v` 与 `docker exec langfuse-clickhouse-1 clickhouse-client ... FROM system.parts ...`。
- **影响**：这是 Langfuse 所带 ClickHouse 的系统日志堆积，不是 Beszel 或 RustDesk 业务数据本身。

## 2026-03-08 top-rustdesk 清理结果
- **发现**：停掉 `langfuse-clickhouse-1` 后，直接清空 4 个系统日志表对应的数据目录并重启容器，根盘使用率从 `99%` 降到 `50%`，可用空间恢复到约 `47GB`。
- **来源**：SSH 执行目录级清理与清理后 `df -h /` 复核。
- **影响**：磁盘告警已解除，Langfuse Web / Worker / ClickHouse 容器均恢复运行。后续如不加 retention，系统日志仍可能再次增长。


## 2026-03-08 Status 开关与 zT 通知关系确认
- **发现**：UI 小铃铛中的 `Status` 开关在数据库中对应 `alerts` 表里 `name='Status'` 的记录；`jetson` 与 `SjH-OpenWrt` 当前都没有该记录。
- **来源**：`alerts-sheet.tsx`、`sqlite3 beszel_data/data.db` 查询。
- **影响**：只要脚本读取 `alerts` 表中的 `Status` 记录，就能与界面开关直接联动。

## 2026-03-08 zT 通知联动修复
- **发现**：`zt_latency_sync.sh` 已调整为仅在设备存在 `Status` 告警记录时，才发送 zT 的 `offline/recovery/jitter` 钉钉通知；关闭小铃铛中的 `Status` 后，该设备虽然仍会采样 `z193`，但不会再发 zT 消息。
- **来源**：`scripts/zt_latency_sync.sh` 修改与手动执行验证。
- **影响**：界面 `Status` 开关现在就是 zT 钉钉通知开关。

## 2026-03-08 关闭状态后的验证
- **发现**：在 `jetson`、`SjH-OpenWrt` 均无 `Status` 告警记录的前提下，手动执行脚本后，两台的 `z193_last_offline_alert_ts` 保持不变，且日志中未出现新的 `alert event` / `dingtalk send`。
- **来源**：执行前后对比 `json_extract(info,'$.z193_last_offline_alert_ts')` 与脚本日志。
- **影响**：已满足“关掉某台设备的 Status 后，这台 zT 离线/恢复/抖动通知都不再发送”的目标。


## 2026-03-08 MacBook 短暂红色掉线根因判断
- **发现**：`macbook` 会出现约 `48s` 的 `Status down -> up` 抖动，且同一时间 `z193_status` 也同步从 `up` 短暂变成 `down` 后恢复。
- **来源**：`alerts_history` 中 `Status` 事件时长与 `zt_latency_sync.log` 同时段日志对比。
- **影响**：问题不是前端误报，而是 `MacBook -> Hub` 的现有 SSH/ZeroTier 采集链路存在短暂不可达。

## 2026-03-08 MacBook WebSocket 切换
- **发现**：已将 `MacBook` 的 launchd 配置改为带 `HUB_URL + TOKEN` 的 WebSocket 优先模式，并为当前 Hub 刷新了新的专属 token；切换后 `systems.info.ct` 从 `1(SSH)` 变为 `2(WebSocket)`。
- **来源**：远端 `~/Library/LaunchAgents/com.beszel.agent.plist`、agent 日志 `WebSocket connected host=192.168.193.13:38005`、数据库 `json_extract(info,'$.ct')`。
- **影响**：MacBook 不再依赖分钟级 SSH 轮询作为主连接路径，可显著降低短暂红色掉线。

## 2026-03-08 MacBook 切换后验证
- **发现**：切换后至少 75 秒观察窗口内，`macbook` 状态保持 `up`，未新增新的 `Status` 掉线历史记录。
- **来源**：切换后轮询 `systems.status/info.ct` 与 `alerts_history`。
- **影响**：本次切换已初步生效；后续若再偶发掉线，应优先排查 MacBook 本机网络瞬断，而不是 Beszel 轮询机制。
