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

### 问题
- **问题**：Hub 原生采集在部分 SSH 系统上出现“状态不降级但采集线程卡住”，前端表现为除延迟外都“数据准备中”。
- **解决**：增加 SSH 解码与会话等待超时，避免无限阻塞；重建 Hub 后原生 `1m` 采样恢复。
