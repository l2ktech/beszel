# 进度日志

## 会话 2026-02-16
### 完成
- [x] 恢复数据库误删后的所有系统记录
- [x] 添加 jetson 到 Hub (Docker Agent)
- [x] 添加 macbook 到 Hub (二进制 Agent)
- [x] 添加 top-rustdesk 到 Hub (二进制 Agent)
- [x] 更新所有设备 Agent Token
- [x] 添加 15Xpro-wsl 到 Hub (WSL2 + Windows 端口转发)
- [x] 验证全部 14 个设备连接成功

### 问题与解决
1. **问题**: 数据库 data.db 被误删
   - **解决**: 重新创建所有系统记录，更新 Agent Token

2. **问题**: 15Xpro-wsl 端口 45876 不可达
   - **解决**: 配置 Windows 端口转发 + 防火墙规则
   ```powershell
   # 获取 WSL IP
   $wslIp = (wsl hostname -I).Split()[0]
   # 端口转发
   netsh interface portproxy add v4tov4 listenport=45876 listenaddress=0.0.0.0 connectport=45876 connectaddress=$wslIp
   # 防火墙
   New-NetFireWallRule -DisplayName "WSL Beszel Agent" -Direction Inbound -LocalPort 45876 -Protocol TCP -Action Allow
   ```

### 关键配置
- Hub URL: https://beszel.l2k.tech:38005
- Hub 内部: http://127.0.0.1:8090
- 公钥: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINELUHo1RjGRB8vL9QrshyHCvtc0Qwi8bXgMJf370NpH
- Agent 端口: 45876

## 会话 2026-02-15
### 完成
- [x] 更新 Beszel 文档密码为 !Wangzeyu166!@#
- [x] 获取 Hub JWT Token
- [x] 通过 API 创建 ROCK5C 和 SjH 系统记录
- [x] 生成 Agent Token 并创建 fingerprint 记录
- [x] ROCK5C 安装 beszel-agent 二进制 (通过 HTTP 服务器下载)
- [x] SjH 安装 beszel-agent 二进制
- [x] 配置 ROCK5C systemd 服务
- [x] 配置 SjH procd init.d 服务
- [x] 更新 Hub 中系统的 Host 和 Port 配置
- [x] **ROCK5C 连接成功 - 状态 up**
- [x] **SjH-OpenWrt 连接成功 - 状态 up**

### 问题与解决
1. **问题**: 公钥配置错误，使用了错误的公钥
   - **解决**: 使用 Hub 的公钥 `INELUHo1RjGRB8vL9QrshyHCvtc0Qwi8bXgMJf370NpH`

2. **问题**: 端口配置错误，设置为 22 而非 Agent 端口
   - **解决**: 更新为 Agent 监听端口 45876

3. **问题**: 网络下载 GitHub 文件超时
   - **解决**: 本机启动 HTTP 服务器，设备从本机下载
