# friendlyWrt 无法访问 192 网络修复

## 目标
通过 SSH 登录 friendlyWrt，定位并修复 `192.168.192.15` 不可达问题，恢复其下游设备对 192 网络访问能力。

## Planning 查重与复用记录
- 检索时间：2026-03-03 14:22 CST
- 检索范围：`planning/`、`planning/done/`（覆盖 `task_plan.md`、`findings.md`、`progress.md`）
- Top1：`planning/01-安装Agent到SjH和ROCK5C/`（相似度 62%）
- Top2：无
- Top3：无
- 最高相似度：62%
- 决策：新建目录 `02-20260303-friendlyWrt无法访问192网络修复`。原因：历史任务目标是“批量部署 Agent”，本任务目标是“单节点网络故障修复”，阶段和约束不同，不满足复用阈值（>=80%）。

### 增量复用判定（2026-03-05 friendlyWrt 下挂设备无法访问 193 网络）
- 检索时间：2026-03-05 09:35:22 CST
- 检索范围：`planning/`、`planning/done/`（覆盖 `task_plan.md`、`findings.md`、`progress.md`）
- Top1：`planning/02-20260303-friendlyWrt无法访问192网络修复/`（相似度 94%）
- Top2：`planning/05-20260303-192193网络波动掉线采集告警/`（相似度 82%）
- Top3：`planning/03-20260303-项目运行状态检查/`（相似度 41%）
- 最高相似度：94%
- 决策：复用本目录继续执行。原因：同一设备（friendlyWrt）与同一故障域（ZeroTier 192/193 互访）的增量排障，满足复用阈值（>=40%）。

## 阶段清单

### [x] 阶段1：现场信息收集
- [x] 校验本机到 `192.168.192.15` / `192.168.193.15` 连通性
- [x] 校验 ZeroTier 接口与路由状态
- [x] 校验 Beszel 延迟回填日志时间线

### [x] 阶段2：SSH 登录并修复 friendlyWrt
- [x] 登录设备并确认 ZeroTier 双网络状态
- [x] 执行本机侧可行修复（清理残留网络、重启实例、修复防火墙 INPUT）
- [x] 记录变更命令

### [ ] 阶段3：本地验证
- [x] 回测 `192.168.192.15` ICMP 连通（仍失败）
- [ ] 回测 Beszel z192 延迟恢复（待官方控制器侧授权/规则修复后复测）

### [x] 阶段4：文档与同步
- [x] 更新 planning `findings.md` / `progress.md`
- [x] 更新项目文档（实现变更与验证结果）
- [x] 同步 Obsidian（planning/implementation/completion/project_summary/usage_guide）

### [x] 阶段5：friendlyWrt 下挂设备到 193 网段修复（2026-03-05）
- [x] SSH 登录 friendlyWrt 核查路由、转发与防火墙
- [x] 复现“下挂设备访问 193 失败”并定位阻塞点
- [x] 落地修复并完成路由器侧回归验证
- [ ] 下挂终端侧最终回归（待用户现场复测）

## 错误日志
- [2026-03-03] `ssh root@192.168.193.15` 权限拒绝（publickey,password） -> 改用 `~/.ssh/id_rsa_github` 登录成功
- [2026-03-03] `565799d8f61f7c2d` 更换新 nodeId 后 `ACCESS_DENIED` -> 已回滚旧身份 `8b7d0422ba`
- [2026-03-03] OpenWrt `opkg update` 卡住占锁 -> 已手动清理锁与进程
- [2026-03-05] 首次修复将 `ztdfilglme` 绑定到 `network.zt193` 并执行 `network reload` 后，`192.168.193.15` 管理入口短时丢失 -> 已通过 `192.168.192.15` 回连并回滚为 `firewall.device=ztdfilglme` 方案。

## 进度
- 当前：阶段5（已完成 193 转发/NAT 修复与路由器侧回归）
- 下一步：由用户在 friendlyWrt 下挂终端复测 `192.168.193.*` 访问并回传结果
