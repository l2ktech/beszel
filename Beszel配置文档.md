# Beszel 服务器监控系统配置文档

## 系统信息

- **项目名称**: Beszel
- **部署路径**: `/Users/wzy/projects/08-Beszel`
- **访问地址**: http://localhost:38005
- **版本**: 0.18.2

---

## 一、访问信息

### Web 管理界面
- **URL**: http://localhost:38005
- **用户名**: 442333521@qq.com
- **密码**: !Wangzeyu66!@#

### 容器管理
```bash
# 进入项目目录
cd /Users/wzy/projects/08-Beszel

# 查看容器状态
docker compose ps

# 查看日志
docker compose logs -f beszel         # Hub 服务日志
docker compose logs -f beszel-agent   # Agent 服务日志

# 重启服务
docker compose restart

# 停止服务
docker compose down

# 启动服务
docker compose up -d
```

---

## 二、服务器连接配置

### 方式一：通过 Web 界面添加服务器

1. 登录 http://localhost:38005
2. 点击右上角 **"Add System"** 按钮
3. 填写服务器信息并获取安装脚本

### 方式二：使用 SSH 连接远程服务器

#### 1. 准备 SSH 密钥
```bash
# SSH 密钥已生成在：
# 私钥: /Users/wzy/projects/08-Beszel/keys/beszel_agent
# 公钥: /Users/wzy/projects/08-Beszel/keys/beszel_agent.pub
```

#### 2. 连接远程服务器并安装 Agent
```bash
# 使用 WinSCP 或其他 SSH 工具连接到目标服务器

# 将公钥复制到目标服务器的 ~/.ssh/authorized_keys
cat beszel_agent.pub >> ~/.ssh/authorized_keys

# 在目标服务器上执行 Beszel Agent 安装命令
# 从 Web 界面的 "Add System" 对话框中复制安装命令
# 或使用以下 Docker 方式：

# 创建目录
mkdir -p ~/beszel-agent && cd ~/beszel-agent

# 创建 docker-compose.yml 文件
cat > docker-compose.yml << 'EOF'
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
EOF

# 启动 Agent
docker compose up -d
```

#### 3. 在 Web 界面完成添加
- 在 "Add System" 对话框中填写服务器信息
- Host/IP: 填写远程服务器 IP
- SSH 端口: 默认 22
- 点击 **"Add System"** 完成添加

---

## 三、告警配置

### 邮件告警配置

**邮件服务器信息**:
- **发件人**: qwzy@foxmail.com
- **收件人**: 442333521@qq.com
- **SMTP 服务器**: smtp.qq.com
- **端口**: 587 (SSL)
- **授权码**: wlxqztvxcreqebei

**配置步骤**:

1. 访问 http://localhost:38005
2. 进入 **设置** > **通知**
3. 添加邮件通知（使用 Generic Webhook）
4. 配置 URL（需要配置中间邮件服务）:

```
generic://your-mail-service.com?template=json
```

**注意事项**:
- Beszel 原生不支持 SMTP 邮件，需要使用通用 webhook 或第三方邮件服务
- 建议配置钉钉告警作为主要通知方式
- 可使用 [SendGrid](https://sendgrid.com/)、[Mailgun](https://www.mailgun.com/) 等邮件服务 API

### 钉钉告警配置

**钉钉机器人信息**:
- **Webhook URL**: https://oapi.dingtalk.com/robot/send?access_token=7d37088634657d310642583a6f93e0da1594ab6134beff8589caa2690031d539
- **加签密钥**: SECe4bda9a71c04798d20fc759cc7839c1a3b6a86bf8bd9977b8ef38d20a35e393c
- **Robot Code**: ding0re41bn9yex7xvwk

**配置步骤**:

1. 访问 http://localhost:38005
2. 进入 **设置** > **通知**
3. 点击 **添加通知**
4. 配置钉钉 Webhook URL:

```
generic://oapi.dingtalk.com/robot/send?access_token=7d37088634657d310642583a6f93e0da1594ab6134beff8589caa2690031d539&template=json&$msgtype=text
```

**钉钉消息格式**:
```json
{
  "title": "服务器告警",
  "message": "CPU 使用率超过阈值",
  "msgtype": "text"
}
```

**加签验证**:
如果钉钉启用了加签验证，需要使用中间服务来处理签名。建议使用：
- [Server酱](https://sct.ftqq.com/) - 支持钉钉推送
- [Bark](https://github.com/Finb/Bark) - 支持 iOS 推送
- 自建中间服务处理加签逻辑

---

## 四、Docker 镜像监控

### 监控配置

Beszel 自动监控所有 Docker 容器的以下指标：

- **CPU 使用率**: 每个容器的 CPU 占用
- **内存使用**: 每个容器的内存占用
- **网络流量**: 上传/下载流量统计
- **容器状态**: 运行中/停止/重启次数

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

**示例告警规则**:
- CPU 使用率 > 80% 持续 10 分钟
- 内存使用率 > 90% 持续 5 分钟
- 容器停止运行
- 磁盘使用率 > 85%

---

## 五、数据持久化

### 数据目录
```bash
# Hub 数据目录
/Users/wzy/projects/08-Beszel/beszel_data/

# Agent 数据目录
/Users/wzy/projects/08-Beszel/beszel_agent_data/
```

### 备份配置

在 http://localhost:38005 的 **设置** > **备份** 中配置：

1. **本地备份**: 备份到本地磁盘
2. **S3 备份**: 备份到 S3 兼容存储（阿里云 OSS、腾讯云 COS 等）

**自动备份配置**:
- 设置备份频率（每日/每周）
- 设置保留备份数量
- 配置 S3 凭证（如使用云存储）

---

## 六、常用操作

### 查看所有服务器状态
```bash
docker compose ps
```

### 查看实时日志
```bash
# Hub 服务日志
docker compose logs -f beszel

# Agent 服务日志
docker compose logs -f beszel-agent
```

### 更新到最新版本
```bash
cd /Users/wzy/projects/08-Beszel
docker compose pull
docker compose up -d
```

### 重启所有服务
```bash
docker compose restart
```

### 停止所有服务
```bash
docker compose down
```

### 清理未使用的 Docker 资源
```bash
docker system prune -a
```

---

## 七、故障排查

### 容器无法启动
```bash
# 查看容器日志
docker compose logs beszel

# 检查端口占用
lsof -i :38005

# 检查磁盘空间
df -h
```

### Agent 无法连接到 Hub
```bash
# 检查网络连接
ping hub-ip-address

# 检查防火墙规则
sudo ufw status

# 查看 Agent 日志
docker logs beszel-agent
```

### 告警未发送
```bash
# 检查通知配置
# 访问 http://localhost:38005/settings/notifications

# 测试 Webhook
curl -X POST https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN \
  -H 'Content-Type: application/json' \
  -d '{"msgtype":"text","text":{"content":"测试消息"}}'
```

---

## 八、安全建议

1. **修改默认端口**: 已修改为 38005
2. **启用 HTTPS**: 建议配置反向代理（Nginx/Caddy）并启用 SSL
3. **定期更新**: 定期执行 `docker compose pull && docker compose up -d`
4. **备份配置**: 配置自动备份到 S3 存储
5. **访问控制**: 配置防火墙规则，限制访问来源 IP

---

## 九、API 访问

Beszel 提供 REST API，可用于自动化管理。

**API 基础 URL**: http://localhost:38005/api/

**示例**:
```bash
# 获取所有系统
curl http://localhost:38005/api/collections/systems?sort=-name

# 获取告警列表
curl http://localhost:38005/api/collections/alerts

# 创建告警（需要认证）
curl -X POST http://localhost:38005/api/collections/alerts \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"CPU告警","metric":"cpu","threshold":80}'
```

详细 API 文档: https://beszel.dev/guide/rest-api

---

## 十、联系方式

- **项目主页**: https://github.com/henrygd/beszel
- **官方文档**: https://beszel.dev
- **问题反馈**: https://github.com/henrygd/beszel/issues
- **社区讨论**: https://github.com/henrygd/beszel/discussions

---

## 附录：SSH 密钥信息

**私钥路径**: `/Users/wzy/projects/08-Beszel/keys/beszel_agent`
**公钥路径**: `/Users/wzy/projects/08-Beszel/keys/beszel_agent.pub`

**公钥内容** (已复制到 authorized_keys):
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAq8t3HXdYTMp8kWBwUuCbuezv/i74jcGgTlWvSaKJVA beszel-agent@MacBook-Pro.local
```

---

**文档最后更新**: 2026-02-01
**Beszel 版本**: 0.18.2