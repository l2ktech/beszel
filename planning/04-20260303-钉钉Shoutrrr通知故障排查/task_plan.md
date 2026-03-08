# 钉钉 Shoutrrr 通知故障排查

## 目标
定位 Beszel 使用 Shoutrrr 发送钉钉通知失败的原因，并给出可落地的修复方案。

## Planning 查重与复用记录
- 检索时间：2026-03-03 15:50:00 CST
- 检索范围：`planning/`、`planning/done/`（覆盖 `task_plan.md`、`findings.md`、`progress.md`）
- Top1：`planning/03-20260303-项目运行状态检查/`（相似度 42%）
- Top2：`planning/02-20260303-friendlyWrt无法访问192网络修复/`（相似度 27%）
- Top3：`planning/01-安装Agent到SjH和ROCK5C/`（相似度 18%）
- 最高相似度：42%
- 决策：新建目录 `04-20260303-钉钉Shoutrrr通知故障排查`。原因：历史任务聚焦运行态与网络连通，当前任务是通知链路协议与签名机制排障，不满足复用阈值（>=80%）。

## 阶段清单

### [x] 阶段1：上下文收集
- [x] 检索项目内通知配置与代码路径
- [x] 确认当前用户通知设置存储位置

### [x] 阶段2：根因验证
- [x] 复核 Shoutrrr 对钉钉能力边界
- [x] 复现钉钉机器人加签调用并采集返回
- [x] 判定失败点（URL 格式/签名/平台限制）

### [x] 阶段3：修复与验证
- [x] 输出可用配置（含签名场景）
- [ ] 如需，提交脚本或文档修正
- [x] 本地验证通知链路

### [x] 阶段4：文档与同步
- [x] 更新 planning findings/progress
- [x] 同步 Obsidian（planning/implementation/completion/project_summary/usage_guide）

## 错误日志
- [2026-03-03] 初始检索发现项目中大量 `generic://oapi.dingtalk.com/...` 静态 URL 配置，疑似与“加签”机器人动态签名机制冲突。

## 进度
- 当前：已完成根因定位
- 下一步：若需要“Beszel 直连钉钉加签机器人”，可继续提交代码补丁（新增钉钉专用发送逻辑）
