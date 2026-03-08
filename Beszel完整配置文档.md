# Beszel 服务器监控系统 - 完整配置文档

## 📋 项目信息

- **项目名称**: Beszel
- **部署路径**: `/Users/wzy/projects/08-Beszel`
- **访问地址**: http://localhost:38005
- **版本**: 0.18.2
- **配置日期**: 2026-02-01
- **最近更新**: 2026-03-03（新增全量延迟回填 + 修复 15Xpro-wsl 掉线 + friendlyWrt 192 网络排障）

---

## 🔐 访问信息

### Web 管理界面
- **URL**: http://localhost:38005
- **用户名**: 442333521@qq.com
- **密码**: !Wangzeyu166!@#

### API Token
```bash
# 获取 Token
TOKEN=$(curl -s -X POST http://localhost:38005/api/collections/_superusers/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity":"442333521@qq.com","password":"!Wangzeyu166!@#"}' | jq -r '.token')

# Token 文件位置
/tmp/beszel_token.txt
```

说明：
- 当前部署建议使用 `_superusers` 登录端点。
- 若 `/api/collections/users/auth-with-password` 返回 500，请改用上面的 `_superusers` 端点。

---

## 🆕 2026-03 新增功能与修复

### 1) 全量实时延迟回填 + 波动/掉线告警（z192 / z193，每分钟）

已上线并启用：
- 脚本：`/Users/wzy/projects/08-Beszel/scripts/zt_latency_sync.sh`
- 告警配置：`/Users/wzy/projects/08-Beszel/scripts/zt_alert.env`（模板：`scripts/zt_alert.env.example`）
- launchd：`/Users/wzy/Library/LaunchAgents/com.wzy.beszel.zt-latency-sync.plist`
- 执行周期：`run interval = 60 seconds`
- 主日志：`/Users/wzy/Library/Logs/com.wzy.beszel.zt-latency-sync.log`
- stdout/stderr：
  - `/Users/wzy/Library/Logs/com.wzy.beszel.zt-latency-sync.out.log`
  - `/Users/wzy/Library/Logs/com.wzy.beszel.zt-latency-sync.err.log`

字段说明：
- `info.z192`：到 `192.168.192.x` 的延迟（ms）
- `info.z193`：到 `192.168.193.x` 的延迟（ms）
- `-1`：当前不可达或非 192/193 主机（例如域名）
- `info.z192_jitter / info.z193_jitter`：相邻两次采样延迟差值（ms）
- `info.z192_status / info.z193_status`：`up` / `down` / `na`
- `info.z192_down_streak / info.z193_down_streak`：连续不可达次数
- `info.z192_jitter_streak / info.z193_jitter_streak`：连续高抖动次数
- `info.z192_flap_count / info.z193_flap_count`：状态切换计数
- `info.z192_last_offline_alert_ts` 等：各类告警上次发送时间戳

告警触发逻辑（脚本内置）：
- 掉线告警：`down_streak >= ALERT_OFFLINE_STREAK`
- 波动告警：`jitter >= ALERT_JITTER_WARN_MS` 且 `jitter_streak >= ALERT_JITTER_STREAK`
- 恢复告警：`down -> up` 且此前已达到掉线阈值
- 冷却去重：同类告警受 `ALERT_COOLDOWN_SEC` 控制

默认阈值（可在 `scripts/zt_alert.env` 调整）：
- `ALERT_OFFLINE_STREAK=2`
- `ALERT_JITTER_WARN_MS=80`
- `ALERT_JITTER_STREAK=3`
- `ALERT_COOLDOWN_SEC=600`

快速检查：
```bash
launchctl print gui/$(id -u)/com.wzy.beszel.zt-latency-sync | sed -n '1,80p'
tail -n 30 /Users/wzy/Library/Logs/com.wzy.beszel.zt-latency-sync.log
sqlite3 /Users/wzy/projects/08-Beszel/beszel_data/data.db \
  "SELECT name, json_extract(info,'$.z192'), json_extract(info,'$.z193'), json_extract(info,'$.z192_status'), json_extract(info,'$.z193_status') FROM systems ORDER BY name;"
```

### 2) 15Xpro-wsl 掉线修复（已恢复）

最终状态：
- 系统：`15Xpro-wsl`
- Hub 记录：`192.168.193.17:45877`
- 当前状态：`up`

修复结论：
- `45876` 在 15X 的 WSL 环境存在端口占用冲突，导致 agent 无法稳定监听。
- 切换为 `45877` 后恢复正常，并已验证 Hub 可正常拉取数据。

当前运行方式（15X 机器）：
- 启动脚本：`/home/wzy/start_beszel_agent_45877.sh`
- 自启方式：`crontab @reboot` 启动该脚本
- 进程日志：`/home/wzy/beszel-agent-45877.log`

快速检查：
```bash
# 在 15X 主机
pgrep -a -f '/home/wzy/.local/bin/beszel-agent -l :45877'
ss -lntp | grep 45877

# 在 Hub 主机
TOKEN=$(curl -s -X POST http://localhost:38005/api/collections/_superusers/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity":"442333521@qq.com","password":"!Wangzeyu166!@#"}' | jq -r '.token')
curl -s "http://localhost:38005/api/collections/systems/records/nd1k86f9xfwcq4a" \
  -H "Authorization: Bearer $TOKEN" | jq '{name,host,port,status,updated,info}'
```

### 3) friendlyWrt 192 网络排障（进行中）

当前结论（2026-03-03 14:41 +0800）：
- `friendlyWrt` 主实例：`565799d8f61f7c2d` 显示 `OK`，IP 为 `192.168.192.15`
- 设备侧已修复项：`zerotier.top.fw_allow_input=1`，防火墙已出现 `Accept ZeroTier input ztr2qynjg3`
- 仍存在问题：`192.168.192.15` 对部分节点不可达（例如 `192.168.192.13/16/1`），`193.15` 可达

已执行操作：
- 清理主实例残留网络（移除 `c329...` / `5cb...` from main）
- 停用 `zerotier-self` 自启（当前为手动运行，避免重启后漂移）
- 进行主实例身份旋转测试：新 nodeId 加入 `565...` 返回 `ACCESS_DENIED`，已回滚旧身份 `8b7d0422ba`
- 已在自建控制器（`5cb1bf45e10c6865`）中将成员 `8b7d0422ba` 授权为 `authorized=true`

下一步（需控制面处理）：
- 在官方 ZeroTier 控制台（my.zerotier.com）检查网络 `565799d8f61f7c2d` 中成员 `8b7d0422ba`
- 重点核对：`authorized`、IP 分配冲突、Flow Rules 是否限制该成员与其他节点互通
- 控制面修复后，执行本地复测：
```bash
ping -c 3 192.168.192.15
ssh root@192.168.192.15
```

---

## 🖥️ 服务器配置

### 已添加的服务器

#### 1. 本地服务器
- **名称**: 本地服务器
- **ID**: vpyadqj5zavicfm
- **主机**: localhost
- **端口**: 45876
- **状态**: pending（等待 Agent 连接）
- **用户**: 442333521@qq.com

#### 2. 15Xpro-wsl
- **名称**: 15Xpro-wsl
- **ID**: nd1k86f9xfwcq4a
- **主机**: 192.168.193.17
- **端口**: 45877
- **状态**: up
- **说明**: 该主机已从 45876 调整到 45877（WSL 端口冲突规避）

### 添加新服务器

#### 方式一：Web 界面
1. 访问 http://localhost:38005
2. 点击右上角 **"Add System"**
3. 填写服务器信息：
   - **System Name**: 服务器名称
   - **Host/IP**: 服务器 IP 地址
   - **SSH Port**: SSH 端口（默认 22）
4. 点击 **"Add System"**
5. 复制显示的安装命令
6. 在目标服务器执行安装命令

#### 方式二：使用 SSH 密钥
```bash
# 1. 使用 WinSCP 或其他 SSH 工具连接到目标服务器
# 2. 将本地公钥添加到目标服务器的 authorized_keys
cat /Users/wzy/projects/08-Beszel/keys/beszel_agent.pub >> ~/.ssh/authorized_keys

# 3. 在 Web 界面添加服务器
# Host/IP: 填写目标服务器 IP
# SSH Port: 默认 22
# 点击 "Add System"
```

#### 方式三：Docker Compose（推荐）
在目标服务器上创建 `docker-compose.yml`：

```yaml
services:
  beszel-agent:
    image: henrygd/beszel-agent:latest
    container_name: beszel-agent
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./beszel_agent_data:/var/lib/beszel-agent
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      HUB_URL: http://your-hub-ip:38005
      TOKEN: <token-from-web-ui>
      KEY: "<public-key-from-web-ui>"
```

启动 Agent：
```bash
docker compose up -d
```

---

## 📢 告警配置

### 通知方式

#### 1. 钉钉告警
- **Webhook URL**: https://oapi.dingtalk.com/robot/send?access_token=7d37088634657d310642583a6f93e0da1594ab6134beff8589caa2690031d539
- **加签密钥**: SECe4bda9a71c04798d20fc759cc7839c1a3b6a86bf8bd9977b8ef38d20a35e393c
- **Robot Code**: ding0re41bn9yex7xvwk
- **状态**: ✅ 已配置

#### 2. 邮件告警
- **发件人**: qwzy@foxmail.com
- **收件人**: 442333521@qq.com
- **SMTP 服务器**: smtp.qq.com
- **端口**: 587 (SSL)
- **授权码**: wlxqztvxcreqebei
- **状态**: ✅ 已配置

### 告警规则

#### 已配置的告警（本地服务器）

| 告警类型 | 阈值 | 持续时间 | 状态 |
|---------|------|---------|------|
| CPU 使用率 | 80% | 10 分钟 | ✅ 已创建 |
| 内存使用率 | 90% | 5 分钟 | ✅ 已创建 |
| 磁盘使用率 | 85% | 立即触发 | ✅ 已创建 |

#### 通过命令行创建告警
```bash
TOKEN=$(cat /tmp/beszel_token.txt)
SYSTEM_ID="vpyadqj5zavicfm"

# CPU 告警
curl -s -X POST http://localhost:38005/api/beszel/user-alerts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"CPU\",
    \"value\": 80,
    \"min\": 10,
    \"systems\": [\"$SYSTEM_ID\"],
    \"overwrite\": true
  }"

# 内存告警
curl -s -X POST http://localhost:38005/api/beszel/user-alerts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Memory\",
    \"value\": 90,
    \"min\": 5,
    \"systems\": [\"$SYSTEM_ID\"],
    \"overwrite\": true
  }"

# 磁盘告警
curl -s -X POST http://localhost:38005/api/beszel/user-alerts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Disk\",
    \"value\": 85,
    \"min\": 0,
    \"systems\": [\"$SYSTEM_ID\"],
    \"overwrite\": true
  }"
```

---

## 🐳 Docker 监控

Beszel 自动监控所有 Docker 容器的以下指标：

- **CPU 使用率**: 每个容器的 CPU 占用
- **内存使用**: 每个容器的内存占用
- **网络流量**: 上传/下载流量统计
- **容器状态**: 运行中/停止/重启次数
- **健康状态**: 容器健康检查结果

### 查看方式

1. 访问 http://localhost:38005
2. 点击左侧菜单的 **系统** (Systems)
3. 选择要查看的服务器
4. 在 **容器** (Containers) 标签页查看

### 告警配置

为 Docker 容器配置告警：

1. 进入 **设置** > **告警** (Alerts)
2. 为每个系统创建告警规则
3. 可配置的指标：
   - CPU 使用率阈值
   - 内存使用率阈值
   - 容器状态变化
   - 磁盘使用率

---

## 🔧 容器管理

### Docker Compose 命令

```bash
cd /Users/wzy/projects/08-Beszel

# 查看容器状态
docker compose ps

# 查看实时日志
docker compose logs -f beszel         # Hub 服务日志
docker compose logs -f beszel-agent   # Agent 服务日志

# 重启服务
docker compose restart

# 重启单个服务
docker compose restart beszel
docker compose restart beszel-agent

# 停止服务
docker compose down

# 停止并删除数据
docker compose down -v

# 启动服务
docker compose up -d

# 更新到最新版本
docker compose pull
docker compose up -d

# 查看资源占用
docker stats beszel beszel-agent

# 查看容器详情
docker inspect beszel
docker inspect beszel-agent
```

### 网络配置
```bash
# 查看网络配置
docker network ls | grep beszel
docker network inspect 08-beszel_default

# 查看 agent 连接到 hub 的日志
docker logs beszel-agent --tail=50
```

---

## 💾 数据持久化

### 数据目录
```bash
# Hub 数据目录（包含数据库、配置等）
/Users/wzy/projects/08-Beszel/beszel_data/

# Agent 数据目录（包含监控数据）
/Users/wzy/projects/08-Beszel/beszel_agent_data/

# 数据库文件
/Users/wzy/projects/08-Beszel/beszel_data/data.db
```

### 备份配置

在 http://localhost:38005 的 **设置** > **备份** 中配置：

1. **本地备份**: 备份到本地磁盘
2. **S3 备份**: 备份到 S3 兼容存储（阿里云 OSS、腾讯云 COS 等）

**自动备份配置**:
- 设置备份频率（每日/每周）
- 设置保留备份数量
- 配置 S3 凭证（如使用云存储）

### 手动备份
```bash
# 备份数据库
cp /Users/wzy/projects/08-Beszel/beszel_data/data.db /backup/beszel_backup_$(date +%Y%m%d).db

# 备份整个数据目录
tar -czf /backup/beszel_data_$(date +%Y%m%d).tar.gz /Users/wzy/projects/08-Beszel/beszel_data/
```

---

## 🔑 SSH 密钥信息

### 生成的密钥对
- **私钥路径**: `/Users/wzy/projects/08-Beszel/keys/beszel_agent`
- **公钥路径**: `/Users/wzy/projects/08-Beszel/keys/beszel_agent.pub`

### 公钥内容
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAq8t3HXdYTMp8kWBwUuCbuezv/i74jcGgTlWvSaKJVA beszel-agent@MacBook-Pro.local
```

### 使用方法
```bash
# 将公钥添加到目标服务器的 authorized_keys
cat /Users/wzy/projects/08-Beszel/keys/beszel_agent.pub >> ~/.ssh/authorized_keys

# 使用私钥连接（如需要）
ssh -i /Users/wzy/projects/08-Beszel/keys/beszel_agent user@hostname
```

---

## 📝 自动配置脚本

### 使用方法
```bash
cd /Users/wzy/projects/08-Beszel
bash configure_beszel.sh
```

### 脚本功能
- ✅ 自动登录 Beszel
- ✅ 配置钉钉告警通知
- ✅ 配置邮件通知
- ✅ 创建 CPU/内存/磁盘告警规则
- ✅ 显示配置状态
- ✅ 显示使用说明

### 脚本位置
`/Users/wzy/projects/08-Beszel/configure_beszel.sh`

---

## 🔌 API 端点参考

### 认证
```bash
# 登录获取 Token
POST /api/collections/users/auth-with-password
Content-Type: application/json
{
  "identity": "442333521@qq.com",
  "password": "!Wangzeyu166!@#"
}
```

### 用户设置
```bash
# 获取用户设置
GET /api/collections/user_settings/records
Authorization: Bearer {token}

# 更新用户设置
PATCH /api/collections/user_settings/records/{id}
Authorization: Bearer {token}
Content-Type: application/json
{
  "settings": {
    "emails": ["442333521@qq.com"],
    "webhooks": ["generic://..."]
  }
}
```

### 系统管理
```bash
# 获取所有系统
GET /api/collections/systems/records
Authorization: Bearer {token}

# 创建系统
POST /api/collections/systems/records
Authorization: Bearer {token}
Content-Type: application/json
{
  "name": "服务器名称",
  "host": "localhost",
  "port": "45876",
  "status": "up",
  "users": ["user-id"]
}

# 删除系统
DELETE /api/collections/systems/records/{id}
Authorization: Bearer {token}
```

### 告警规则
```bash
# 获取所有告警
GET /api/collections/alerts/records
Authorization: Bearer {token}

# 创建告警
POST /api/beszel/user-alerts
Authorization: Bearer {token}
Content-Type: application/json
{
  "name": "CPU",
  "value": 80,
  "min": 10,
  "systems": ["system-id"],
  "overwrite": true
}
```

### 容器监控
```bash
# 获取系统容器列表
GET /api/beszel/containers/{systemId}
Authorization: Bearer {token}
```

---

## 🛠️ 故障排查

### 容器无法启动
```bash
# 查看容器日志
docker compose logs beszel

# 检查端口占用
lsof -i :38005

# 检查磁盘空间
df -h

# 检查 Docker 状态
docker ps -a
```

### Agent 无法连接到 Hub
```bash
# 检查网络连接
ping hub-ip-address

# 查看 Agent 日志
docker logs beszel-agent --tail=100

# 检查防火墙规则
sudo ufw status

# 测试端口连通性
telnet hub-ip-address 38005
```

### 告警未发送
```bash
# 检查通知配置
TOKEN=$(cat /tmp/beszel_token.txt)
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:38005/api/collections/user_settings/records | jq .

# 测试钉钉 Webhook
curl -X POST 'https://oapi.dingtalk.com/robot/send?access_token=7d37088634657d310642583a6f93e0da1594ab6134beff8589caa2690031d539' \
  -H 'Content-Type: application/json' \
  -d '{"msgtype":"text","text":{"content":"测试消息"}}'
```

### 数据库问题
```bash
# 检查数据库文件
ls -la /Users/wzy/projects/08-Beszel/beszel_data/data.db

# 查看数据库表
sqlite3 /Users/wzy/projects/08-Beszel/beszel_data/data.db ".tables"

# 查看用户数据
sqlite3 /Users/wzy/projects/08-Beszel/beszel_data/data.db "SELECT * FROM users"

# 查看系统数据
sqlite3 /Users/wzy/projects/08-Beszel/beszel_data/data.db "SELECT * FROM systems"
```

---

## 🔒 安全建议

1. **修改默认端口**: ✅ 已修改为 38005
2. **启用 HTTPS**: 建议配置反向代理（Nginx/Caddy）并启用 SSL
3. **定期更新**: 定期执行 `docker compose pull && docker compose up -d`
4. **备份配置**: 配置自动备份到 S3 存储
5. **访问控制**: 配置防火墙规则，限制访问来源 IP
6. **密码强度**: 使用强密码并定期更换
7. **SSH 密钥保护**: 私钥文件权限设置为 600

---

## 📊 监控指标说明

### 系统指标
- **CPU**: CPU 使用率百分比
- **Memory**: 内存使用率百分比
- **Disk**: 磁盘使用率百分比
- **Temperature**: CPU 温度（摄氏度）
- **Bandwidth**: 网络带宽（上传/下载速度）
- **LoadAvg1**: 1 分钟平均负载
- **LoadAvg5**: 5 分钟平均负载
- **LoadAvg15**: 15 分钟平均负载
- **Battery**: 电池状态（百分比）

### 容器指标
- **CPU**: 容器 CPU 占用百分比
- **Memory**: 容器内存使用量（MB/GB）
- **Network**: 上传/下载流量（KB/s）
- **Health**: 容器健康状态（healthy/unhealthy/none）

---

## 📁 文件清单

```
/Users/wzy/projects/08-Beszel/
├── docker-compose.yml              # Docker Compose 配置
├── configure_beszel.sh             # 自动配置脚本
├── Beszel完整配置文档.md           # 本文档
├── keys/                           # SSH 密钥目录
│   ├── beszel_agent               # 私钥
│   └── beszel_agent.pub           # 公钥
├── beszel_data/                   # Hub 数据目录
│   └── data.db                    # 数据库文件
└── beszel_agent_data/             # Agent 数据目录
```

---

## 📞 支持与帮助

- **项目主页**: https://github.com/henrygd/beszel
- **官方文档**: https://beszel.dev
- **API 文档**: https://beszel.dev/guide/rest-api
- **问题反馈**: https://github.com/henrygd/beszel/issues
- **社区讨论**: https://github.com/henrygd/beszel/discussions

---

## 📌 快速参考

### 访问地址
- **Web 界面**: http://localhost:38005
- **用户名**: 442333521@qq.com
- **密码**: !Wangzeyu166!@#

### 常用命令
```bash
cd /Users/wzy/projects/08-Beszel

# 查看状态
docker compose ps

# 查看日志
docker compose logs -f

# 重启服务
docker compose restart

# 自动配置
bash configure_beszel.sh
```

### 已配置的服务器
- **本地服务器**: vpyadqj5zavicfm (localhost:45876)
- **15Xpro-wsl**: nd1k86f9xfwcq4a (192.168.193.17:45877)

### 已配置的告警
- ✅ CPU 使用率 > 80% (10 分钟)
- ✅ 内存使用率 > 90% (5 分钟)
- ✅ 磁盘使用率 > 85% (立即)

### 已配置的通知
- ✅ 钉钉 Webhook
- ✅ 邮件通知 (442333521@qq.com)

---

**文档最后更新**: 2026-03-03
**Beszel 版本**: 0.18.2
**配置工具版本**: v1.0
**维护者**: 442333521@qq.com
