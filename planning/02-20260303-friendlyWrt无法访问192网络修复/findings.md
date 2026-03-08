# 研究发现

## 现场网络状态（2026-03-03 14:11 CST）
- **发现**：本机可达 `192.168.193.15`，不可达 `192.168.192.15`。
- **来源**：本机命令 `ping` / `route -n get` / `arp -an`。
- **影响**：friendlyWrt 的 `192` 侧地址不可用，导致其下游访问 192 网络失败。

## 路由与邻居证据
- **发现**：`192.168.192.15` 为 `ARP incomplete` 且路由出现 `REJECT`；`192.168.193.15` 有完整 MAC 邻居项。
- **来源**：本机 `netstat -rn`、`arp -an`。
- **影响**：问题位于 friendlyWrt 的 `192` 网络成员状态/接口层，不是 Beszel 展示问题。

## Beszel 延迟时间线
- **发现**：`friendlyWrt` 长时间 `z192=-1`，`z193` 正常（约 15-80ms）。
- **来源**：`/Users/wzy/Library/Logs/com.wzy.beszel.zt-latency-sync.log`。
- **影响**：可确认故障持续存在，不是瞬时抖动。

## 外部检索（Grok 优先）
- **发现**：OpenWrt + ZeroTier 单网段不可达常见原因为 network 未分配地址、接口未绑定防火墙 zone、或成员离网。
- **来源**：
  - https://docs.zerotier.com/faq/
  - https://docs.zerotier.com/route-between-phys-and-virt/
  - https://forum.openwrt.org/t/zerotier-unreachable/172142
  - https://discuss.zerotier.com/t/new-to-zerotier-and-failing-at-routing-via-openwrt/4178
- **影响**：修复优先顺序应为：`listnetworks` -> `restart/join` -> `ip addr` -> `firewall/forward`。

## friendlyWrt 设备侧实测（SSH 已执行）
- **发现**：friendlyWrt 同时存在主实例（`/var/lib/zerotier-one`，nodeId=`8b7d0422ba`）和副实例（`/var/lib/zerotier-self`，nodeId=`1a958af09d`，193网）。主配置还残留过 `c329...` 网络节。
- **来源**：`/etc/config/zerotier`、`/etc/init.d/zerotier-self`、`ps`、`zerotier-cli listnetworks`。
- **影响**：已清理主实例多余网络并保留 `565...`；副实例改为非开机自启（当前手动运行）。

## 防火墙修复
- **发现**：`ztr2qynjg3` 原先未放行 INPUT，已改为 `zerotier.top.fw_allow_input='1'` 并重载防火墙，nft 已出现 `Accept ZeroTier input ztr2qynjg3` 规则。
- **来源**：`uci show zerotier`、`nft list ruleset`。
- **影响**：解决了设备侧明确的防火墙缺陷，但未完全恢复与所有 192 节点互通。

## 官方网络侧限制（当前阻塞项）
- **发现**：主实例显示 `565...` 为 `OK` 且已分配 `192.168.192.15`，但从 friendlyWrt 到 `192.168.192.13/.16/.1` 仍失败，仅对少数节点可达；本机到 `192.168.192.15` 仍不可达。
- **来源**：双向 `ping`、`ip neigh`、`zerotier-cli info/listnetworks/listpeers`。
- **影响**：问题已超出设备本地配置范畴，需在官方 ZeroTier 控制面（my.zerotier.com，网络 `565799d8f61f7c2d`）校验成员 `8b7d0422ba` 的授权状态与 Flow Rules。

## 自建 ZeroTier 授权结果（2026-03-03 14:45 CST）
- **发现**：`txy` 的 SSH 入口（`192.168.193.1`/`192.168.192.1`/`1.116.61.176`）均为 `Connection refused`，无法通过 SSH 操作控制器。
- **来源**：本机 SSH 实测。
- **影响**：改用 Zero-UI API 执行成员授权。

- **发现**：自建网络 `5cb1bf45e10c6865` 中成员 `8b7d0422ba (friendlyWrt-official)` 原为 `authorized=false`，已成功改为 `authorized=true`（HTTP 200）。
- **来源**：`POST /api/network/5cb1bf45e10c6865/member/8b7d0422ba`。
- **影响**：该成员已获授权；当前仍 `online=0`、未分配 193 地址（这是预期，因它不一定加入该自建网络）。

## 双网段复测结果（2026-03-03 15:40 CST）
- **发现**：本机 `193` 网段基本全通（仅 `.203` 不通），`192` 网段仅部分节点可达；同一批节点在 `193` 延迟正常、`192` 长期 `-1`。
- **来源**：本机 `ping` 矩阵、`/Users/wzy/Library/Logs/com.wzy.beszel.zt-latency-sync.log`。
- **影响**：可排除“本机双网都断”与“193 全局故障”，问题集中在官方 `192` 网络成员侧连通性。

## 交叉验证（friendlyWrt 与本机一致）
- **发现**：从 `friendlyWrt (192.168.193.15)` 发起对 `192` 网段探测，仍呈现“部分可达、部分不可达”的同分布现象（例如 `.13/.17/.20` 可达，`.1/.9/.10/.14/.16/.18/.201/.202/.203` 不可达）。
- **来源**：SSH 到 friendlyWrt 后执行 `zerotier-cli listnetworks` 与批量 `ping`。
- **影响**：可排除单机路由问题，故障位于 `565799d8f61f7c2d` 控制面策略/成员状态或各节点 `192` 接口防火墙。

## 根因推断（当前最可能）
- **发现**：`193`（自建网络）与 `192`（官方网络）行为明显分化，且 `192` 内部呈“选择性可达”。
- **来源**：本地实测 + 既有结论 + ZeroTier 文档（Rules / Connection Issues / Ping FAQ）。
- **影响**：高概率为 `565799d8f61f7c2d` 的成员授权/Flow Rules/Managed Routes 配置导致微分段，叠加部分节点本地防火墙未放行 `192` 接口流量。

## 2026-03-05 193 下挂访问故障复现
- **发现**：friendlyWrt 自身可访问 `192.168.193.*`，但防火墙中仅存在 `br-lan -> ztr2qynjg3`（192 网）转发与 masquerade；缺少 `br-lan -> ztdfilglme`（193 网）对应规则。
- **来源**：设备实测 `ip route`、`nft list chain inet fw4 forward/srcnat`、`uci show firewall`。
- **影响**：下挂设备（`192.168.2.0/24`）访问 193 网段时返回路径缺失，导致“路由器本机可达、下挂终端不可达”。

## 2026-03-05 Grok 检索结论（193 下挂访问）
- **发现**：OpenWrt + ZeroTier 下挂终端访问远端网段的稳定方案是：独立 zone + `lan->zt` forwarding + `masquerade`，避免远端节点依赖回程静态路由。
- **来源**：
  - https://openwrt.org/docs/guide-user/services/vpn/zerotier
  - https://docs.zerotier.com/route-between-phys-and-virt/
  - https://github.com/mwarning/zerotier-openwrt/wiki/Configure-ZeroTier-routing-in-OpenWrt
  - https://discuss.zerotier.com/t/new-to-zerotier-and-failing-at-routing-via-openwrt/4178
- **影响**：本次按该策略为 193 网络补齐 zone/forward/masq。

## 2026-03-05 修复落地与回滚
- **发现**：首次方案将 `ztdfilglme` 绑定至 `network.zt193` 后触发 `network reload`，导致 `192.168.193.15` 入口短时失联。
- **来源**：现场执行日志（`network reload` 后 193 SSH 超时，192 SSH 可达）。
- **影响**：确认 `zerotier-self` 动态接口不应由 netifd 直接接管。

- **发现**：最终方案改为仅在 firewall 中使用 `zone zt193 + device ztdfilglme + lan<->zt193 forwarding + masq`，并重启 `zerotier-self` 恢复接口。
- **来源**：`uci show firewall`、`zerotier-cli -D/var/lib/zerotier-self -p29993 listnetworks`、`ip addr show ztdfilglme`、`nft list chain inet fw4 srcnat_zt193`。
- **影响**：193 接口恢复，NAT 链路具备持久化规则，不再依赖临时命令。

## 2026-03-05 回归验证（路由器侧）
- **发现**：friendlyWrt 可再次稳定访问 `192.168.193.13/.10/.1/.18`，`ztdfilglme` 接口与 `192.168.193.15/24` 路由恢复。
- **来源**：设备侧批量 `ping` + `ip route` 查询。
- **影响**：路由器侧修复完成；下挂终端只需现场复测即可闭环。
