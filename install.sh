#!/bin/bash

echo "=========================================="
echo "🚀 Telegram Bot 自定义端口部署脚本"
echo "=========================================="

# 1. 环境检查
if ! command -v docker &> /dev/null; then
    echo "📦 正在安装 Docker..."
    curl -fsSL https://get.docker.com | sh
fi

# 2. 收集配置
echo ""
echo "👇 请输入基础配置："
read -p "1. Bot Token: " TOKEN
read -p "2. 管理员群组 ID: " GROUP_ID
read -p "3. 管理员 ID (逗号分隔): " ADMIN_IDS
echo ""

# --- 关键修改：询问端口 ---
echo "🔢 端口设置："
echo "因为你的 80/443 端口被占用，请选择一个空闲端口给 Bot 使用。"
read -p "请输入 VPS 端口 (默认 8080): " INPUT_PORT
HOST_PORT=${INPUT_PORT:-8080} # 如果用户直接回车，默认为 8080

echo ""
read -p "🌐 请输入你的域名 (例如 https://bot.yourdomain.com): " DOMAIN_URL

# 3. 生成配置文件
echo "BOT_TOKEN=$TOKEN" > .env
echo "ADMIN_GROUP_ID=$GROUP_ID" >> .env
echo "ADMIN_IDS=$ADMIN_IDS" >> .env
echo "DB_PATH=/app/data/bot.sqlite" >> .env
echo "HOST_PORT=$HOST_PORT" >> .env # 写入用户选择的端口

# 4. 启动容器
echo ""
echo "🐳 正在在端口 $HOST_PORT 上启动 Bot..."
docker compose down 2>/dev/null
docker compose up -d --build

# 5. Webhook 设置提醒
echo ""
echo "=========================================="
echo "✅ 容器部署完成！"
echo "=========================================="
echo "⚠️ 重要步骤：你现在需要配置你的 Nginx/Apache！"
echo ""
echo "请在你的 Nginx 配置文件中添加以下反代规则："
echo "-------------------------------------"
echo "location / {"
echo "    proxy_pass http://127.0.0.1:$HOST_PORT;"
echo "    proxy_set_header Host \$host;"
echo "    proxy_set_header X-Real-IP \$remote_addr;"
echo "}"
echo "-------------------------------------"
echo ""
echo "配置好 Nginx 并重启后，请复制下面的链接在浏览器访问一次，以激活机器人："
echo "https://api.telegram.org/bot$TOKEN/setWebhook?url=$DOMAIN_URL/"
echo ""
