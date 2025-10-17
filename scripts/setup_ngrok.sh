#!/bin/bash
# Script cài đặt và cấu hình Ngrok tunnel cho ChatBot
# Chạy với quyền root: sudo bash setup_ngrok.sh

set -e

NGROK_TOKEN="${1:-}"
CHATBOT_PORT="${2:-8000}"

echo "=========================================="
echo "🌐 Ngrok Setup for ChatBot"
echo "=========================================="

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Vui lòng chạy với quyền root: sudo bash setup_ngrok.sh"
    exit 1
fi

# Kiểm tra token
if [ -z "$NGROK_TOKEN" ]; then
    echo "❌ Thiếu ngrok token!"
    echo "Usage: sudo bash setup_ngrok.sh <NGROK_TOKEN> [PORT]"
    echo "Example: sudo bash setup_ngrok.sh 340d7opQdIVY5tESBHxuOSNw3aR_2Z4vapovmzgRUxZ8bZ1JJ 8000"
    exit 1
fi

echo "Port: $CHATBOT_PORT"
echo ""

# 1. Cài đặt ngrok nếu chưa có
if ! command -v ngrok &> /dev/null; then
    echo "📦 Đang cài đặt ngrok..."
    
    # Download ngrok
    cd /tmp
    wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
    tar -xzf ngrok-v3-stable-linux-amd64.tgz
    
    # Move to /usr/local/bin
    mv ngrok /usr/local/bin/
    chmod +x /usr/local/bin/ngrok
    
    # Cleanup
    rm -f ngrok-v3-stable-linux-amd64.tgz
    
    echo "✅ Ngrok đã được cài đặt"
else
    echo "✅ Ngrok đã có sẵn"
fi

# 2. Cấu hình ngrok với authtoken
echo "🔑 Đang cấu hình ngrok authtoken..."
ngrok config add-authtoken "$NGROK_TOKEN"
echo "✅ Token đã được cấu hình"
echo ""

# 3. Tạo systemd service cho ngrok
echo "⚙️  Tạo systemd service..."

cat > /etc/systemd/system/ngrok-chatbot.service << EOF
[Unit]
Description=Ngrok Tunnel for ChatBot Dich vu cong
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/chatbot-dichvucong
ExecStart=/usr/local/bin/ngrok http $CHATBOT_PORT --log=stdout
Restart=always
RestartSec=10
StandardOutput=append:/var/log/ngrok-chatbot.log
StandardError=append:/var/log/ngrok-chatbot.log

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Service file đã được tạo"
echo ""

# 4. Tạo script để lấy URL
cat > /usr/local/bin/ngrok-url << 'EOF'
#!/bin/bash
# Script để lấy URL của ngrok tunnel

echo "🔍 Đang lấy Ngrok URL..."
sleep 2

# Thử lấy từ API của ngrok
URL=$(curl -s http://localhost:4040/api/tunnels | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['tunnels'][0]['public_url'] if data.get('tunnels') else 'No tunnel found')" 2>/dev/null)

if [ -z "$URL" ] || [ "$URL" = "No tunnel found" ]; then
    echo "❌ Không tìm thấy tunnel. Kiểm tra service:"
    echo "   systemctl status ngrok-chatbot"
    echo "   journalctl -u ngrok-chatbot -f"
    exit 1
fi

echo ""
echo "✅ Ngrok URL:"
echo "   $URL"
echo ""
echo "📋 Cập nhật URL này vào frontend Vercel"
EOF

chmod +x /usr/local/bin/ngrok-url

echo "✅ Script ngrok-url đã được tạo"
echo ""

# 5. Reload systemd và enable service
echo "🔄 Đang reload systemd..."
systemctl daemon-reload
systemctl enable ngrok-chatbot.service
echo "✅ Service đã được enable"
echo ""

# 6. Start service
echo "🚀 Đang khởi động ngrok service..."
systemctl start ngrok-chatbot.service
echo "✅ Service đã được khởi động"
echo ""

# 7. Wait và lấy URL
echo "⏳ Đợi ngrok khởi tạo tunnel (5s)..."
sleep 5

echo ""
echo "=========================================="
echo "✅ HOÀN TẤT CÀI ĐẶT!"
echo "=========================================="
echo ""
echo "📋 Các lệnh hữu ích:"
echo ""
echo "1. Xem URL ngrok:"
echo "   ngrok-url"
echo ""
echo "2. Xem logs ngrok:"
echo "   tail -f /var/log/ngrok-chatbot.log"
echo "   hoặc: journalctl -u ngrok-chatbot -f"
echo ""
echo "3. Restart ngrok:"
echo "   systemctl restart ngrok-chatbot"
echo ""
echo "4. Stop ngrok:"
echo "   systemctl stop ngrok-chatbot"
echo ""
echo "5. Xem status:"
echo "   systemctl status ngrok-chatbot"
echo ""
echo "6. Ngrok dashboard:"
echo "   http://localhost:4040"
echo ""
echo "=========================================="
echo ""

# Lấy URL ngrok
/usr/local/bin/ngrok-url

echo ""
echo "⚠️  LƯU Ý BẢO MẬT:"
echo "   Nên reset ngrok authtoken vì đã public:"
echo "   https://dashboard.ngrok.com/get-started/your-authtoken"
echo ""
