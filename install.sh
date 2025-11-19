#!/bin/bash

echo "=========================================="
echo "🚀 Telegram Bot 部署脚本 (含 Nginx 自动配置)"
echo "=========================================="

# --- 第一部分：Docker 部署 ---

# 1. 环境检查
if ! command -v docker &> /dev/null; then
    echo "📦 正在安装 Docker..."
    curl -fsSL https://get.docker.com | sh
fi

# 2. 收集 Docker 配置
echo ""
echo "👇 [1/2] 机器人基础配置"
read -p "1. Bot Token: " TOKEN
read -p "2. 管理员群组 ID: " GROUP_ID
read -p "3. 管理员 ID (逗号分隔): " ADMIN_IDS
echo ""
echo "🔢 端口设置"
read -p "4. 请输入 VPS 空闲端口 (默认 8080): " INPUT_PORT
HOST_PORT=${INPUT_PORT:-8080}

read -p "5. 请输入你的域名 (例如 bot.domain.com): " DOMAIN_URL
# 提取纯域名 (去掉 https://)
DOMAIN_ONLY=$(echo "$DOMAIN_URL" | sed -e 's|^[^/]*//||' -e 's|/.*$||')

# 3. 生成环境文件
echo "BOT_TOKEN=$TOKEN" > .env
echo "ADMIN_GROUP_ID=$GROUP_ID" >> .env
echo "ADMIN_IDS=$ADMIN_IDS" >> .env
echo "DB_PATH=/app/data/bot.sqlite" >> .env
echo "HOST_PORT=$HOST_PORT" >> .env

# 4. 启动容器
echo ""
echo "🐳 正在启动 Bot 容器..."
docker compose down 2>/dev/null
docker compose up -d --build

# --- 第二部分：Nginx 自动配置 ---

echo ""
echo "👇 [2/2] Nginx 自动配置"

# 检查 Nginx 是否存在
if ! command -v nginx &> /dev/null; then
    echo "⚠️ 未检测到 Nginx，跳过自动配置。请手动配置反向代理。"
else
    echo "✅ 检测到 Nginx，正在准备生成配置文件..."
    
    echo ""
    echo "⚠️ 为了自动配置 HTTPS，我需要知道你的 SSL 证书路径。"
    echo "通常在 /www/server/panel/vhost/cert/ (宝塔) 或 /etc/letsencrypt/live/ (Certbot)"
    echo ""
    read -p "👉 请输入证书文件(.pem/.crt)的绝对路径: " SSL_CERT
    read -p "👉 请输入私钥文件(.key)的绝对路径: " SSL_KEY

    # 检查文件是否存在
    if [ ! -f "$SSL_CERT" ] || [ ! -f "$SSL_KEY" ]; then
        echo "❌ 错误：找不到证书文件，跳过 Nginx 配置。请稍后手动配置。"
    else
        # 定义 Nginx 配置文件路径
        NGINX_CONF="/etc/nginx/conf.d/tg_bot_${DOMAIN_ONLY}.conf"
        
        # 如果 conf.d 不存在，尝试 sites-enabled (Debian/Ubuntu 风格)
        if [ ! -d "/etc/nginx/conf.d" ]; then
            if [ -d "/etc/nginx/sites-enabled" ]; then
                NGINX_CONF="/etc/nginx/sites-enabled/tg_bot_${DOMAIN_ONLY}.conf"
            else
                echo "⚠️ 找不到标准的 Nginx 配置目录，跳过自动配置。"
                exit 1
            fi
        fi

        # 写入 Nginx 配置文件
        cat > "$NGINX_CONF" <<EOF
server {
    listen 443 ssl;
    server_name $DOMAIN_ONLY;

    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;

    # 基础 SSL 优化参数
    ssl_session_timeout 5m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    location / {
        proxy_pass http://127.0.0.1:$HOST_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
        echo "📄 已生成配置文件: $NGINX_CONF"
        
        # 测试并重载
        echo "🔍 正在测试 Nginx 配置语法..."
        if nginx -t; then
            echo "✅ 语法正确，正在重载 Nginx..."
            nginx -s reload || systemctl reload nginx
            echo "🎉 Nginx 配置成功生效！"
            
            # 自动设置 Webhook
            echo ""
            echo "🔗 正在激活 Webhook..."
            sleep 2
            # 确保 URL 有 https
            if [[ "$DOMAIN_URL" != https* ]]; then DOMAIN_URL="https://$DOMAIN_URL"; fi
            curl -s "https://api.telegram.org/bot$TOKEN/setWebhook?url=$DOMAIN_URL/"
            
            echo ""
            echo "✅ 全部完成！机器人已上线。"
        else
            echo "❌ Nginx 配置测试失败！为了防止影响其他网站，已自动删除刚才生成的配置文件。"
            rm "$NGINX_CONF"
            echo "请检查你的证书路径是否正确，或者查看上面的错误信息手动配置。"
        fi
    fi
fi
