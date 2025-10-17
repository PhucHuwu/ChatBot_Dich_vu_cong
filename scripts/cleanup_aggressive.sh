#!/bin/bash

# Script dọn dẹp aggressive - giải phóng tối đa dung lượng
# Dành cho trường hợp cần giải phóng nhiều dung lượng

set -e

echo "================================================"
echo "Dọn dẹp Aggressive - ChatBot Dịch vụ công"
echo "================================================"
echo ""
echo "⚠️  Script này sẽ xóa:"
echo "   • MongoDB (nếu có) - ~560MB"
echo "   • Snapd (nếu không dùng snap) - ~200MB"
echo "   • Journal logs (giữ 1 ngày) - ~350MB"
echo "   • btmp log (failed logins) - ~146MB"
echo "   • Large log files - ~200MB"
echo "   • APT cache - ~131MB"
echo "   • Docker cache - ~26MB"
echo ""
echo "📊 Ước tính giải phóng: ~1.5GB - 2GB"
echo ""

read -p "⚠️  Bạn có chắc chắn muốn tiếp tục? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Đã hủy."
    exit 1
fi

echo ""
echo "🔄 Bắt đầu dọn dẹp aggressive..."
echo ""

# 1. Xóa MongoDB
echo "🗄️  [1/10] Xóa MongoDB..."
if systemctl is-active --quiet mongod 2>/dev/null; then
    echo "   → Dừng MongoDB service..."
    sudo systemctl stop mongod
    sudo systemctl disable mongod
fi

if dpkg -l | grep -q mongodb; then
    MONGO_SIZE=$(du -sh /var/lib/mongodb 2>/dev/null | cut -f1 || echo "0")
    echo "   → MongoDB data: $MONGO_SIZE"
    sudo apt-get remove -y mongodb* 2>/dev/null || true
    sudo rm -rf /var/lib/mongodb
    sudo rm -rf /var/log/mongodb
    sudo rm -rf /etc/mongodb*
    echo "   ✓ MongoDB đã được xóa (~560MB giải phóng)"
else
    echo "   ℹ️  MongoDB không được cài đặt"
fi
echo ""

# 2. Xóa Snapd nếu không dùng snap
echo "📦 [2/10] Xóa Snapd..."
if dpkg -l | grep -q snapd; then
    SNAP_COUNT=$(snap list 2>/dev/null | wc -l || echo "0")
    SNAPD_SIZE=$(du -sh /var/lib/snapd 2>/dev/null | cut -f1 || echo "0")
    echo "   → Snap packages: $((SNAP_COUNT - 1)), Size: $SNAPD_SIZE"
    
    if [ "$SNAP_COUNT" -le 1 ]; then
        sudo systemctl stop snapd 2>/dev/null || true
        sudo systemctl disable snapd 2>/dev/null || true
        sudo apt-get remove -y snapd 2>/dev/null || true
        sudo rm -rf /var/lib/snapd
        sudo rm -rf ~/snap
        echo "   ✓ Snapd đã được xóa (~200MB giải phóng)"
    else
        echo "   ⚠️  Đang có snap packages, bỏ qua"
    fi
else
    echo "   ℹ️  Snapd không được cài đặt"
fi
echo ""

# 3. Dọn dẹp Journal logs (giữ 1 ngày)
echo "📝 [3/10] Dọn dẹp Journal logs..."
echo "   Dung lượng hiện tại:"
sudo journalctl --disk-usage
echo "   → Giữ logs 1 ngày gần nhất..."
sudo journalctl --vacuum-time=1d
echo "   → Giới hạn tối đa 50MB..."
sudo journalctl --vacuum-size=50M
echo "   Dung lượng sau:"
sudo journalctl --disk-usage
echo "   ✓ Journal logs đã được dọn (~350MB giải phóng)"
echo ""

# 4. Truncate btmp (failed login logs)
echo "🔒 [4/10] Dọn dẹp btmp (failed login logs)..."
if [ -f "/var/log/btmp" ]; then
    BTMP_SIZE=$(du -h /var/log/btmp | cut -f1)
    echo "   → btmp hiện tại: $BTMP_SIZE"
    sudo truncate -s 0 /var/log/btmp
    echo "   ✓ btmp đã được truncate (~146MB giải phóng)"
else
    echo "   ℹ️  btmp không tồn tại"
fi
echo ""

# 5. Rotate và truncate large logs
echo "📚 [5/10] Dọn dẹp large log files..."

# auth.log
if [ -f "/var/log/auth.log" ]; then
    AUTH_SIZE=$(du -h /var/log/auth.log | cut -f1)
    echo "   → auth.log: $AUTH_SIZE"
    sudo bash -c "> /var/log/auth.log"
    echo "   ✓ auth.log truncated"
fi

# syslog
if [ -f "/var/log/syslog" ]; then
    SYSLOG_SIZE=$(du -h /var/log/syslog | cut -f1)
    echo "   → syslog: $SYSLOG_SIZE"
    sudo bash -c "tail -n 1000 /var/log/syslog > /var/log/syslog.tmp && mv /var/log/syslog.tmp /var/log/syslog"
    echo "   ✓ syslog giữ 1000 dòng cuối"
fi

# Xóa old rotated logs
sudo find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
sudo find /var/log -type f -name "*.1" -delete 2>/dev/null || true
sudo find /var/log -type f -name "*.old" -delete 2>/dev/null || true

echo "   ✓ Large logs đã được dọn (~200MB giải phóng)"
echo ""

# 6. Dọn dẹp APT
echo "📦 [6/10] Dọn dẹp APT cache..."
APT_SIZE=$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1 || echo "0")
echo "   → APT cache: $APT_SIZE"
sudo apt-get clean
sudo apt-get autoclean
sudo apt-get autoremove -y
echo "   ✓ APT cache đã được dọn (~131MB giải phóng)"
echo ""

# 7. Dọn dẹp Docker
echo "🐳 [7/10] Dọn dẹp Docker..."
docker system prune -a -f --volumes
echo "   ✓ Docker đã được dọn (~26MB giải phóng)"
echo ""

# 8. Dọn dẹp temporary files
echo "🗑️  [8/10] Dọn dẹp temporary files..."
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
echo "   ✓ Temporary files đã được xóa"
echo ""

# 9. Dọn dẹp Python cache
echo "🐍 [9/10] Dọn dẹp Python cache..."
if [ -d "$HOME/ChatBot_Dich_vu_cong" ]; then
    cd $HOME/ChatBot_Dich_vu_cong
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -type f -name "*.pyc" -delete 2>/dev/null || true
    echo "   ✓ Python cache đã được xóa"
else
    echo "   ℹ️  Không tìm thấy project directory"
fi
echo ""

# 10. Tối ưu journald config
echo "⚙️  [10/10] Tối ưu journald config..."
JOURNALD_CONF="/etc/systemd/journald.conf"
if [ -f "$JOURNALD_CONF" ]; then
    sudo sed -i 's/#SystemMaxUse=.*/SystemMaxUse=50M/' $JOURNALD_CONF
    sudo sed -i 's/SystemMaxUse=.*/SystemMaxUse=50M/' $JOURNALD_CONF
    sudo sed -i 's/#RuntimeMaxUse=.*/RuntimeMaxUse=25M/' $JOURNALD_CONF
    sudo sed -i 's/RuntimeMaxUse=.*/RuntimeMaxUse=25M/' $JOURNALD_CONF
    sudo systemctl restart systemd-journald
    echo "   ✓ Journald giới hạn: SystemMaxUse=50M, RuntimeMaxUse=25M"
else
    echo "   ⚠️  Không tìm thấy journald.conf"
fi
echo ""

echo "============================================"
echo "✅ DỌN DẸP AGGRESSIVE HOÀN TẤT!"
echo "============================================"
echo ""

echo "📊 Dung lượng sau khi dọn dẹp:"
df -h /
echo ""

echo "🔍 Kiểm tra services quan trọng:"
systemctl is-active --quiet docker && echo "✓ Docker: OK" || echo "✗ Docker: FAILED"
systemctl is-active --quiet nginx && echo "✓ Nginx: OK" || echo "⚠️  Nginx: Not running"
systemctl is-active --quiet ssh && echo "✓ SSH: OK" || echo "✗ SSH: FAILED"
echo ""

echo "💡 Khuyến nghị:"
echo "   1. Reboot server để giải phóng hoàn toàn: sudo reboot"
echo "   2. Sau reboot, chạy: df -h / để xem dung lượng"
echo "   3. Thiết lập cron job tự động dọn dẹp hàng tuần"
echo ""
