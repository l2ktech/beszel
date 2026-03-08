# 研究发现

## 代码路径
- **发现**：Beszel 通过 `internal/alerts/alerts.go` 调用 `shoutrrr.Send(...)` 发送 Webhook。
- **来源**：本地源码检索。
- **影响**：通知能力受 Shoutrrr URL 协议和服务实现限制。

## 当前用户配置
- **发现**：`user_settings.settings` 当前仅有 `emails`，未配置 `webhooks`。
- **来源**：`sqlite3 beszel_data/data.db` 查询 `user_settings`。
- **影响**：即使告警触发，也不会发送 webhook 通知。

## Shoutrrr 能力边界
- **发现**：当前依赖 `github.com/nicholas-fedor/shoutrrr v0.13.1` 无 `dingtalk://` 专用服务，仅能通过 `generic://` 发送通用 webhook。
- **来源**：Shoutrrr `docs/services/overview.md` 与本地模块源码检索。
- **影响**：钉钉“加签”所需动态 `timestamp/sign` 不能通过静态 URL 原生满足。

## 钉钉接口实测（2026-03-03 15:49 CST）
- **发现**：未带关键词时返回 `errcode=310000`（关键词不匹配）。
- **来源**：直接 `curl` 调用你提供的 webhook。
- **影响**：机器人安全策略启用了关键词校验，消息内容必须包含关键词。

- **发现**：带关键词但不加签时返回 `errcode=310000`（签名不匹配）。
- **来源**：直接 `curl` 调用你提供的 webhook。
- **影响**：机器人安全策略启用了“加签”校验，必须附带 `timestamp` 与 `sign`。

- **发现**：带关键词 + 正确签名 + 正确 payload（`msgtype=text` 且 `text.content`）返回 `errcode=0`。
- **来源**：本地 HMAC-SHA256 生成签名后 `curl` 验证。
- **影响**：Webhook 本身可用，故障不在钉钉机器人不可达。

- **发现**：错误 payload（`{\"msgtype\":\"text\",\"message\":\"...\"}`）返回 `errcode=400201`（缺少 `text` 参数）。
- **来源**：直接 `curl` 调用钉钉接口。
- **影响**：钉钉要求固定 JSON 结构，Shoutrrr generic 默认 `message` 字段不兼容钉钉 text 消息格式。

## Beszel 测试通知“假成功”机制
- **发现**：Shoutrrr generic 仅按 HTTP 状态码判定成功，不检查响应体 `errcode`；钉钉即使返回业务错误（HTTP 200 + `errcode!=0`）也会被 Beszel 视为发送成功。
- **来源**：`pkg/services/specialized/generic/generic.go`（仅检查 `res.StatusCode >= 300`）与 `internal/alerts/alerts.go`。
- **影响**：UI 中“Test notification sent”可能出现，但群内实际无消息。

## 外部检索（Grok 优先）
- **发现**：钉钉官方要求加签算法为 `HmacSHA256(timestamp + '\\n' + secret, secret)`，并要求 `text.content` 字段。
- **来源**：
  - https://open.dingtalk.com/document/dingstart/customize-robot-security-settings
  - https://open.dingtalk.com/document/dingstart/custom-bot-send-message-type
  - https://open.dingtalk.com/document/dingstart/custom-bot-to-send-group-chat-messages
- **影响**：当前仓库文档中的旧 `generic://...&template=json&$msgtype=text` 配置不满足“加签 + 正确 payload”双要求。
