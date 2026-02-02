#!/bin/bash

# ============================================
# Beszel 命令行添加服务器脚本
# ============================================

BASE_URL="http://localhost:38005/api"
EMAIL="442333521@qq.com"
PASSWORD="!Wangzeyu66!@#"

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
echo ""

# 保存 token
echo "$TOKEN" > /tmp/beszel_token.txt

# ============================================
# 2. 获取用户 ID
# ============================================
USER_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/collections/users/records" | jq -r '.items[0].id')

if [ "$USER_ID" == "null" ] || [ -z "$USER_ID" ]; then
    log_error "获取用户 ID 失败"
    exit 1
fi

log_info "用户 ID: $USER_ID"
echo ""

# ============================================
# 3. 检查参数
# ============================================
if [ $# -lt 3 ]; then
    echo "用法: $0 <系统名称> <主机/IP> <SSH端口> [SSH密钥]"
    echo ""
    echo "示例:"
    echo "  $0 生产服务器 192.168.1.100 22"
    echo "  $0 本地服务器 localhost 45876"
    echo ""
    echo "SSH 密钥（可选，默认使用已生成的密钥）:"
    echo "  ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAq8t3HXdYTMp8kWBwUuCbuezv/i74jcGgTlWvSaKJVA"
    exit 1
fi

SYSTEM_NAME="$1"
SYSTEM_HOST="$2"
SYSTEM_PORT="$3"
SSH_KEY="${4:-ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAq8t3HXdYTMp8kWBwUuCbuezv/i74jcGgTlWvSaKJVA}"

log_info "准备添加服务器:"
echo "  名称: $SYSTEM_NAME"
echo "  主机: $SYSTEM_HOST"
echo "  端口: $SYSTEM_PORT"
echo "  SSH 密钥: ${SSH_KEY:0:50}..."
echo ""

# ============================================
# 4. 创建系统记录
# ============================================
log_info "创建系统记录..."

SYSTEM_RESPONSE=$(curl -s -X POST "$BASE_URL/collections/systems/records" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$SYSTEM_NAME\",
    \"host\": \"$SYSTEM_HOST\",
    \"port\": \"$SYSTEM_PORT\",
    \"status\": \"down\",
    \"users\": [\"$USER_ID\"]
  }")

SYSTEM_ID=$(echo "$SYSTEM_RESPONSE" | jq -r '.id')

if [ "$SYSTEM_ID" == "null" ] || [ -z "$SYSTEM_ID" ]; then
    log_error "创建系统失败"
    echo "$SYSTEM_RESPONSE" | jq .
    exit 1
fi

log_info "系统创建成功，ID: $SYSTEM_ID"
echo ""

# ============================================
# 5. 生成 Agent Token
# ============================================
log_info "生成 Agent Token..."
AGENT_TOKEN=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")

log_info "Agent Token: $AGENT_TOKEN"
echo ""

# ============================================
# 6. 创建指纹记录
# ============================================
log_info "创建指纹记录..."

FINGERPRINT_RESPONSE=$(curl -s -X POST "$BASE_URL/collections/fingerprints/records" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"system\": \"$SYSTEM_ID\",
    \"token\": \"$AGENT_TOKEN\",
    \"fingerprint\": \"$SSH_KEY\",
    \"updated\": \"$(date -u +"%Y-%m-%d %H:%M:%S")\"
  }")

FINGERPRINT_ID=$(echo "$FINGERPRINT_RESPONSE" | jq -r '.id')

if [ "$FINGERPRINT_ID" == "null" ] || [ -z "$FINGERPRINT_ID" ]; then
    log_error "创建指纹失败"
    echo "$FINGERPRINT_RESPONSE" | jq .
    exit 1
fi

log_info "指纹创建成功，ID: $FINGERPRINT_ID"
echo ""

# ============================================
# 7. 生成 Agent 配置
# ============================================
log_info "================================"
log_info "服务器添加成功！"
log_info "================================"
echo ""
echo "系统信息:"
echo "  ID: $SYSTEM_ID"
echo "  名称: $SYSTEM_NAME"
echo "  主机: $SYSTEM_HOST:$SYSTEM_PORT"
echo ""
echo "Agent 配置:"
echo "  Agent Token: $AGENT_TOKEN"
echo "  SSH 密钥: $SSH_KEY"
echo ""
echo "================================"
echo "在目标服务器上执行以下命令:"
echo "================================"
echo ""
echo "# 1. 创建目录"
echo "mkdir -p ~/beszel-agent && cd ~/beszel-agent"
echo ""
echo "# 2. 创建 docker-compose.yml"
echo "cat > docker-compose.yml << 'EOF'"
cat << EOF
services:
  beszel-agent:
    image: henrygd/beszel-agent
    container_name: beszel-agent
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./beszel_agent_data:/var/lib/beszel-agent
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      PORT: 45876
      KEY: '$SSH_KEY'
      TOKEN: '$AGENT_TOKEN'
      # FILESYSTEM: /dev/vda1  # 根据实际情况修改
EOF
echo "EOF"
echo ""
echo "# 3. 启动 Agent"
echo "docker compose up -d"
echo ""
echo "================================"
echo "或使用 SSH 连接方式（推荐）:"
echo "================================"
echo ""
echo "1. 将 Hub 的公钥添加到目标服务器:"
echo "   echo '$SSH_KEY' >> ~/.ssh/authorized_keys"
echo ""
echo "2. 在 Beszel Web 界面中，系统会自动连接"
echo ""
echo "================================"
echo "访问地址: http://localhost:38005"
echo "================================"
echo ""

# ============================================
# 8. 验证系统已添加
# ============================================
log_info "验证系统已添加..."
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/collections/systems/records" | jq '.items[] | {id: .id, name: .name, host: .host, port: .port, status: .status}'

echo ""
log_info "完成！"