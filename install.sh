#!/bin/bash

echo "=========================================="
echo "🚀 Telegram Bot VPS 一键部署脚本"
echo "=========================================="

# 1. 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "📦 正在安装 Docker..."
    curl -fsSL https://get.docker.com | sh
else
    echo "✅ Docker 已安装"
fi

# 2. 获取用户输入
echo ""
read -p "🔑 请输入 Bot Token: " TOKEN
read -p "📢 请输入管理员群组 ID: " GROUP_ID
read -p "👤 请输入管理员 ID (多个用逗号分隔): " ADMIN_IDS
read -p "🌐 请输入 VPS 的域名 (例如 https://bot.com，无需结尾斜杠): " DOMAIN

# 3. 创建 .env 文件
echo "BOT_TOKEN=$TOKEN" > .env
echo "ADMIN_GROUP_ID=$GROUP_ID" >> .env
echo "ADMIN_IDS=$ADMIN_IDS" >> .env
echo "DB_PATH=/app/data/bot.sqlite" >> .env

# 4. 启动容器
echo ""
echo "🐳 正在构建并启动容器..."
docker compose down 2>/dev/null
docker compose up -d --build

# 5. 设置 Webhook
echo ""
echo "🔗 正在自动设置 Webhook..."
WEBHOOK_URL="$DOMAIN/"
curl -s "https://api.telegram.org/bot$TOKEN/setWebhook?url=$WEBHOOK_URL" > /dev/null

echo ""
echo "✅ 部署完成！"
echo "数据库位于: $(pwd)/data/bot.sqlite"
echo "日志查看: docker compose logs -f"