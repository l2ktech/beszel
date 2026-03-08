# Beszel 全设备监控部署

## 目标
在所有 ZeroTier 网络设备上部署 Beszel Agent，实现统一监控

## 阶段清单

### [x] 阶段1：准备工作
- [x] 更新 Beszel 文档密码
- [x] 创建 planning 文件
- [x] 获取 Hub JWT Token
- [x] 检查 BE6500 安装方式作为参考

### [x] 阶段2：部署所有设备 Agent
- [x] BE6500 (OpenWrt) - Docker
- [x] friendlyWrt (OpenWrt) - Docker
- [x] gw-4060 (Ubuntu) - Docker
- [x] gw-5800x (Ubuntu) - Docker
- [x] macmini (macOS) - 二进制 + launchd
- [x] ROCK5C (Ubuntu) - 二进制 + systemd
- [x] SjH-OpenWrt (OpenWrt) - 二进制 + procd
- [x] thinkbook16 (Ubuntu WSL) - Docker
- [x] txy (TencentOS) - Docker
- [x] us-google (Debian) - Docker + WebSocket 模式
- [x] jetson (Ubuntu) - Docker
- [x] macbook (macOS) - 二进制 + launchd
- [x] top-rustdesk (Arch) - 二进制 + systemd
- [x] 15Xpro-wsl (Windows WSL2) - 二进制 + Windows 端口转发

### [x] 阶段3：Hub 配置
- [x] 在 Hub 添加所有系统记录
- [x] 配置正确端口 (45876)
- [x] us-google 配置 WebSocket 模式

### [x] 阶段4：验证
- [x] 验证所有 14 个设备连接成功

## 错误日志
- 2026-02-15 公钥配置错误 → 使用 Hub 公钥 INELUHo1RjGRB8vL9QrshyHCvtc0Qwi8bXgMJf370NpH
- 2026-02-15 端口配置错误 (22) → 更新为 Agent 端口 45876
- 2026-02-15 GitHub 下载超时 → 本机 HTTP 服务器中转
- 2026-02-16 数据库误删 → 重新添加所有系统记录并更新 Token
- 2026-02-16 15Xpro-wsl WSL2 端口不可达 → 配置 Windows 端口转发 + 防火墙规则

## 进度
- 当前：**全部完成**
- 最终状态：14 个设备全部成功连接到 Beszel Hub

## 已连接设备 (14个)

| 设备 | IP | 安装方式 | Token |
|------|-----|----------|-------|
| 15Xpro-wsl | 192.168.192.17 | 二进制 + WSL端口转发 | a1bc917d-1c60-487c-a583-3188122537ea |
| BE6500 | 192.168.192.16 | Docker | 1f841805-01e6-4ab8-9d06-72537f865572 |
| friendlyWrt | 192.168.192.15 | Docker | 28ce648f-909b-4f9b-8b11-0367830d467a |
| gw-4060 | 192.168.192.10 | Docker | e328ff5e-de80-4479-9c64-f80fa2adb2e8 |
| gw-5800x | 192.168.192.14 | Docker | 45e32fa6-81aa-4c8e-99a4-8724fbe5444c |
| macmini | 192.168.192.13 | 二进制 | 395d8cdd-edeb-43e6-b602-dff447d5a249 |
| ROCK5C | 192.168.192.202 | 二进制 | 94bc6f8a-c505-48f4-82e7-1e1f444b2abd |
| SjH-OpenWrt | 192.168.192.203 | 二进制 | 38ef8a20-7194-4207-9929-5cdc2821416b |
| thinkbook16 | 192.168.192.20 | Docker | d62f584b-676c-45b6-8d34-aae820d79a25 |
| txy | 192.168.192.1 | Docker | a0f1bd85-5435-4ac1-85b0-9731d32cf3b6 |
| us-google | us.l2k.tech | Docker+WS | c3c7ca12-22a0-4683-9563-68eb4f3a5a86 |
| jetson | 192.168.192.201 | Docker | 94a957c4-406a-4cac-879a-e97c22fd310b |
| macbook | 192.168.192.18 | 二进制 | 6e561412-6f05-4e4c-b2cf-7ca046d6b92f |
| top-rustdesk | 192.168.192.9 | 二进制 | ec79f36e-a241-4684-ad6e-05b9f5e98ed6 |

## 无法添加的设备
- n1-docker: SSH 超时
- dsm224-zerotier: 无 Agent

## 关键配置信息
- Hub URL: https://beszel.l2k.tech:38005
- Hub 内部: http://127.0.0.1:8090
- 公钥: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINELUHo1RjGRB8vL9QrshyHCvtc0Qwi8bXgMJf370NpH
- Agent 端口: 45876
- 登录: 442333521@qq.com
