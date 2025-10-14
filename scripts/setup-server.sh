#!/bin/bash

# Script setup server Ubuntu cho auto deployment
# Chạy với quyền root: sudo bash setup-server.sh

set -e

echo "================================================"
echo "🚀 Setup Server for Auto Deployment"
echo "================================================"

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Vui lòng chạy với quyền root: sudo bash setup-server.sh"
    exit 1
fi

# Update system
echo "📦 Updating system packages..."
apt-get update
apt-get upgrade -y

# Cài đặt Docker
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    systemctl enable docker
    systemctl start docker
    
    echo "✅ Docker installed successfully"
else
    echo "✅ Docker already installed"
fi

# Cài đặt Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "🐳 Installing Docker Compose..."
    apt-get install -y docker-compose
    echo "✅ Docker Compose installed successfully"
else
    echo "✅ Docker Compose already installed"
fi

# Cài đặt Git
if ! command -v git &> /dev/null; then
    echo "📦 Installing Git..."
    apt-get install -y git
    echo "✅ Git installed successfully"
else
    echo "✅ Git already installed"
fi

# Cài đặt Nginx
if ! command -v nginx &> /dev/null; then
    echo "🌐 Installing Nginx..."
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
    echo "✅ Nginx installed successfully"
else
    echo "✅ Nginx already installed"
fi

# Cài đặt Certbot (cho SSL)
if ! command -v certbot &> /dev/null; then
    echo "🔐 Installing Certbot..."
    apt-get install -y certbot python3-certbot-nginx
    echo "✅ Certbot installed successfully"
else
    echo "✅ Certbot already installed"
fi

# Tạo thư mục deploy
DEPLOY_DIR="/opt/chatbot-dichvucong"
echo "📁 Creating deploy directory: $DEPLOY_DIR"
mkdir -p $DEPLOY_DIR

# Setup SSH authorized_keys
echo "🔑 Setting up SSH..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh

if [ ! -f /root/.ssh/authorized_keys ]; then
    touch /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
fi

# Cấu hình Nginx reverse proxy
echo "🌐 Configuring Nginx..."
cat > /etc/nginx/sites-available/chatbot << 'EOF'
server {
    listen 80;
    server_name _;  # Thay bằng domain của bạn nếu có

    client_max_body_size 10M;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Static files caching
    location /frontend {
        proxy_pass http://localhost:8000;
        expires 1h;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/chatbot /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test và reload Nginx
nginx -t
systemctl reload nginx

# Setup firewall
echo "🔥 Configuring firewall..."
ufw --force enable
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw status

# Tạo script giám sát
cat > /usr/local/bin/chatbot-status << 'EOF'
#!/bin/bash
echo "================================================"
echo "📊 Chatbot Service Status"
echo "================================================"
cd /opt/chatbot-dichvucong
docker-compose ps
echo ""
echo "🌐 Nginx Status:"
systemctl status nginx --no-pager | head -5
echo ""
echo "🐳 Docker Stats:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
echo ""
echo "📝 Recent Logs (last 20 lines):"
docker-compose logs --tail=20
EOF

chmod +x /usr/local/bin/chatbot-status

# Tạo script xem logs
cat > /usr/local/bin/chatbot-logs << 'EOF'
#!/bin/bash
cd /opt/chatbot-dichvucong
docker-compose logs -f --tail=100
EOF

chmod +x /usr/local/bin/chatbot-logs

# Tạo script restart
cat > /usr/local/bin/chatbot-restart << 'EOF'
#!/bin/bash
cd /opt/chatbot-dichvucong
echo "🔄 Restarting chatbot service..."
docker-compose restart
echo "✅ Service restarted"
docker-compose ps
EOF

chmod +x /usr/local/bin/chatbot-restart

echo ""
echo "================================================"
echo "✅ Server setup completed!"
echo "================================================"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Copy SSH public key vào GitHub:"
echo "   - Truy cập: Settings > Secrets and variables > Actions"
echo "   - Thêm secrets sau:"
echo "     • SSH_PRIVATE_KEY: Nội dung file ssh-key-1742876126983-private.pem"
echo "     • SERVER_IP: 123.30.48.155"
echo "     • SERVER_USER: root"
echo "     • GROQ_API_KEY: Your Groq API key"
echo ""
echo "2. Kiểm tra thông tin:"
docker --version
docker-compose --version
git --version
nginx -v
echo ""
echo "3. Các command hữu ích:"
echo "   • chatbot-status  : Xem trạng thái service"
echo "   • chatbot-logs    : Xem logs realtime"
echo "   • chatbot-restart : Restart service"
echo ""
echo "4. Test deployment thủ công:"
echo "   cd /opt/chatbot-dichvucong"
echo "   git clone https://github.com/YOUR_USERNAME/ChatBot_Dich_vu_cong.git ."
echo "   # Tạo file .env với GROQ_API_KEY"
echo "   docker-compose up -d --build"
echo ""
echo "5. Truy cập: http://123.30.48.155"
echo ""
echo "================================================"
