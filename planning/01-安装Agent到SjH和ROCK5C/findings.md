# 研究发现

## BE6500 (OpenWrt) 安装方式
- **发现**：使用 procd init.d 服务管理
- **位置**：`/etc/init.d/beszel-agent`
- **二进制路径**：`/opt/beszel-agent/beszel-agent`
- **环境变量**：
  - PORT=45876
  - KEY=ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINELUHo1RjGRB8vL9QrshyHCvtc0Qwi8bXgMJf370NpH
  - TOKEN=347b3cd5-baf8-4fbb-92de-cd7aee98e2db

## 设备架构
| 设备 | 系统 | 架构 | 推荐 Agent |
|------|------|------|-----------|
| ROCK5C | Ubuntu | aarch64 | beszel-agent-linux-arm64 |
| SjH | OpenWrt | aarch64 | beszel-agent-linux-arm64 |

## API 端点
- 认证: POST /api/collections/users/auth-with-password
- 创建系统: POST /api/collections/systems/records
- 创建指纹: POST /api/collections/fingerprints/records
