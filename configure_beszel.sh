#!/bin/bash

# ============================================
# Beszel 自动配置脚本
# ============================================

BASE_URL="http://localhost:38005/api"
EMAIL="442333521@qq.com"
PASSWORD="!Wangzeyu66!@#"

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# ============================================
# 1. 登录获取 Token
# ============================================
log_info "正在登录 Beszel..."
TOKEN=$(curl -s -X POST "$BASE_URL/collections/users/auth-with-password" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" | jq -r '.token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    log_error "登录失败，请检查用户名和密码"
    exit 1
fi

log_info "登录成功"
log_info "Token: ${TOKEN:0:50}..."
echo ""

# 保存 token 到文件
echo "$TOKEN" > /tmp/beszel_token.txt
log_info "Token 已保存到 /tmp/beszel_token.txt"
echo ""

# ============================================
# 2. 配置用户设置（邮件和钉钉通知）
# ============================================
log_info "配置用户设置..."

# 先获取现有的用户设置 ID
USER_SETTINGS_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/collections/user_settings/records" | jq -r '.items[0].id')

if [ "$USER_SETTINGS_ID" != "null" ] && [ ! -z "$USER_SETTINGS_ID" ]; then
    # 更新现有设置
    log_info "更新现有的用户设置 (ID: $USER_SETTINGS_ID)"
    curl -s -X PATCH "$BASE_URL/collections/user_settings/records/$USER_SETTINGS_ID" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "settings": {
          "chartTime": "1h",
          "emails": ["442333521@qq.com"],
          "webhooks": [
            "generic://oapi.dingtalk.com/robot/send?access_token=7d37088634657d310642583a6f93e0da1594ab6134beff8589caa2690031d539&template=json&$msgtype=text"
          ]
        }
      }' | jq .
else
    # 创建新设置
    log_info "创建新的用户设置"
    # 先获取用户 ID
    USER_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
      "$BASE_URL/collections/users/records" | jq -r '.items[0].id')

    curl -s -X POST "$BASE_URL/collections/user_settings/records" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"user\": \"$USER_ID\",
        \"settings\": {
          \"chartTime\": \"1h\",
          \"emails\": [\"442333521@qq.com\"],
          \"webhooks\": [
            \"generic://oapi.dingtalk.com/robot/send?access_token=7d37088634657d310642583a6f93e0da1594ab6134beff8589caa2690031d539&template=json&\$msgtype=text\"
          ]
        }
      }" | jq .
fi

echo ""

# ============================================
# 3. 查看现有系统
# ============================================
log_info "查看现有系统..."
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/collections/systems/records" | jq '.items[] | {id: .id, name: .name, host: .host, status: .status}'
echo ""

# ============================================
# 4. 创建告警规则
# ============================================
log_info "创建告警规则..."

# 获取所有系统 ID
SYSTEM_IDS=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/collections/systems/records" | jq -r '.items[].id')

if [ -z "$SYSTEM_IDS" ]; then
    log_warn "没有找到任何系统，请先添加服务器"
    log_info "提示：访问 http://localhost:38005 手动添加服务器"
else
    log_info "找到系统: $SYSTEM_IDS"

    # CPU 告警
    log_info "创建 CPU 告警（阈值: 80%，持续时间: 10分钟）"
    for sys_id in $SYSTEM_IDS; do
        curl -s -X POST "$BASE_URL/api/beszel/user-alerts" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d "{
            \"name\": \"CPU\",
            \"value\": 80,
            \"min\": 10,
            \"systems\": [\"$sys_id\"],
            \"overwrite\": true
          }" | jq .
    done
    echo ""

    # 内存告警
    log_info "创建内存告警（阈值: 90%，持续时间: 5分钟）"
    for sys_id in $SYSTEM_IDS; do
        curl -s -X POST "$BASE_URL/api/beszel/user-alerts" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d "{
            \"name\": \"Memory\",
            \"value\": 90,
            \"min\": 5,
            \"systems\": [\"$sys_id\"],
            \"overwrite\": true
          }" | jq .
    done
    echo ""

    # 磁盘告警
    log_info "创建磁盘告警（阈值: 85%，立即触发）"
    for sys_id in $SYSTEM_IDS; do
        curl -s -X POST "$BASE_URL/api/beszel/user-alerts" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d "{
            \"name\": \"Disk\",
            \"value\": 85,
            \"min\": 0,
            \"systems\": [\"$sys_id\"],
            \"overwrite\": true
          }" | jq .
    done
    echo ""
fi

# ============================================
# 5. 查看已配置的告警
# ============================================
log_info "查看已配置的告警..."
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/collections/alerts/records" | jq '.items[] | {id: .id, name: .name, value: .value, min: .min, triggered: .triggered}'
echo ""

# ============================================
# 6. 配置总结
# ============================================
log_info "================================"
log_info "配置完成！"
log_info "================================"
echo ""
log_info "访问地址: http://localhost:38005"
log_info "用户名: $EMAIL"
log_info "密码: $PASSWORD"
echo ""
log_info "已配置："
echo "  ✓ 钉钉告警 Webhook"
echo "  ✓ 邮件通知 (442333521@qq.com)"
echo "  ✓ CPU 告警 (80%)"
echo "  ✓ 内存告警 (90%)"
echo "  ✓ 磁盘告警 (85%)"
echo ""
log_info "下一步："
echo "  1. 访问 http://localhost:38005 查看仪表板"
echo "  2. 添加新的服务器（使用 SSH 方式）"
echo "  3. 查看 Docker 容器监控"
echo ""

# ============================================
# 7. 添加新服务器的说明
# ============================================
log_info "================================"
log_info "如何添加新服务器："
log_info "================================"
echo ""
echo "方式一：通过 Web 界面"
echo "  1. 访问 http://localhost:38005"
echo "  2. 点击右上角 'Add System'"
echo "  3. 填写服务器信息"
echo "  4. 复制安装命令并在目标服务器执行"
echo ""
echo "方式二：通过 Docker Compose（推荐）"
echo "  1. 使用 WinSCP 连接到目标服务器"
echo "  2. 创建目录: mkdir -p ~/beszel-agent && cd ~/beszel-agent"
echo "  3. 创建 docker-compose.yml:"
cat << 'EOF'
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
      HUB_URL: http://YOUR_HUB_IP:38005
      KEY: 'ssh-ed25519 YOUR_PUBLIC_KEY'
EOF
echo ""
echo "方式三：使用 SSH 密钥（已在本地生成）"
echo "  私钥: /Users/wzy/projects/08-Beszel/keys/beszel_agent"
echo "  公钥: /Users/wzy/projects/08-Beszel/keys/beszel_agent.pub"
echo ""
echo "  将公钥添加到目标服务器的 ~/.ssh/authorized_keys"
echo "  然后在 Web 界面添加服务器"
echo ""

log_info "================================"
log_info "常用命令："
log_info "================================"
echo ""
echo "查看容器状态:"
echo "  cd /Users/wzy/projects/08-Beszel && docker compose ps"
echo ""
echo "查看日志:"
echo "  docker compose logs -f beszel"
echo "  docker compose logs -f beszel-agent"
echo ""
echo "重启服务:"
echo "  docker compose restart"
echo ""
echo "停止服务:"
echo "  docker compose down"
echo ""