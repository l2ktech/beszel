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
