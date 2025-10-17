#!/bin/bash

# Script dọn dẹp bổ sung để giải phóng thêm dung lượng
# Chạy sau cleanup_system_packages.sh

set -e

echo "================================================"
echo "Dọn dẹp Bổ sung - ChatBot Dịch vụ công"
echo "================================================"
echo ""

# 1. Dọn dẹp Docker
echo "🐳 Dọn dẹp Docker..."
echo "   → Xóa các container đã dừng..."
docker container prune -f
echo "   → Xóa các image không sử dụng..."
docker image prune -a -f
echo "   → Xóa các volume không sử dụng..."
docker volume prune -f
echo "   → Xóa build cache..."
docker builder prune -f
echo "   ✓ Docker đã được dọn dẹp"
echo ""

# 2. Dọn dẹp journald logs (giữ 3 ngày gần nhất)
echo "📝 Dọn dẹp Journal logs..."
echo "   Dung lượng hiện tại:"
sudo journalctl --disk-usage
echo "   → Giữ logs 3 ngày gần nhất..."
sudo journalctl --vacuum-time=3d
echo "   → Giới hạn tối đa 100MB..."
sudo journalctl --vacuum-size=100M
echo "   Dung lượng sau khi dọn:"
sudo journalctl --disk-usage
echo ""

# 3. Dọn dẹp APT
echo "📦 Dọn dẹp APT cache..."
sudo apt-get clean
sudo apt-get autoclean
sudo apt-get autoremove -y
echo "   ✓ APT cache đã được dọn dẹp"
echo ""

# 4. Dọn dẹp temporary files
echo "🗑️  Dọn dẹp temporary files..."
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
echo "   ✓ Temporary files đã được xóa"
echo ""

# 5. Dọn dẹp log files cũ
echo "📚 Dọn dẹp log files cũ..."
sudo find /var/log -type f -name "*.gz" -delete
sudo find /var/log -type f -name "*.1" -delete
sudo find /var/log -type f -name "*.old" -delete
echo "   ✓ Log files cũ đã được xóa"
echo ""

# 5a. Dọn dẹp các log files lớn
echo "📊 Dọn dẹp log files lớn..."
# Truncate btmp (failed login attempts) - giữ file nhưng xóa nội dung
if [ -f "/var/log/btmp" ]; then
    BTMP_SIZE=$(du -h /var/log/btmp | cut -f1)
    echo "   btmp hiện tại: $BTMP_SIZE"
    sudo truncate -s 0 /var/log/btmp
    echo "   ✓ btmp đã được truncate"
fi

# Rotate auth.log nếu quá lớn (>50MB)
if [ -f "/var/log/auth.log" ]; then
    AUTH_SIZE=$(stat -f%z /var/log/auth.log 2>/dev/null || stat -c%s /var/log/auth.log 2>/dev/null)
    if [ "$AUTH_SIZE" -gt 52428800 ]; then
        echo "   auth.log: $(du -h /var/log/auth.log | cut -f1) - đang rotate..."
        sudo logrotate -f /etc/logrotate.d/rsyslog
        echo "   ✓ auth.log đã được rotate"
    else
        echo "   auth.log: OK (< 50MB)"
    fi
fi

# Dọn MongoDB logs nếu có
if [ -d "/var/log/mongodb" ]; then
    MONGO_LOG_SIZE=$(du -sh /var/log/mongodb | cut -f1)
    echo "   MongoDB logs: $MONGO_LOG_SIZE"
    read -p "   Xóa MongoDB logs? (yes/no): " REMOVE_MONGO_LOGS
    if [ "$REMOVE_MONGO_LOGS" = "yes" ]; then
        sudo rm -rf /var/log/mongodb/*
        echo "   ✓ MongoDB logs đã được xóa"
    else
        echo "   ⊘ Bỏ qua MongoDB logs"
    fi
fi
echo ""

# 6. Dọn dẹp Python cache trong project
echo "🐍 Dọn dẹp Python cache..."
if [ -d "$HOME/ChatBot_Dich_vu_cong" ]; then
    cd $HOME/ChatBot_Dich_vu_cong
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -type f -name "*.pyc" -delete 2>/dev/null || true
    find . -type f -name "*.pyo" -delete 2>/dev/null || true
    echo "   ✓ Python cache đã được xóa"
else
    echo "   ℹ️  Không tìm thấy thư mục project"
fi
echo ""

# 7. Xóa old kernels (giữ kernel hiện tại + 1 kernel cũ)
echo "🔧 Kiểm tra old kernels..."
CURRENT_KERNEL=$(uname -r)
echo "   Kernel hiện tại: $CURRENT_KERNEL"
OLD_KERNELS=$(dpkg -l | grep linux-image | grep -v "$CURRENT_KERNEL" | awk '{print $2}' | grep -v linux-image-generic)
if [ -n "$OLD_KERNELS" ]; then
    echo "   Tìm thấy old kernels:"
    echo "$OLD_KERNELS"
    read -p "   Xóa old kernels? (yes/no): " REMOVE_KERNELS
    if [ "$REMOVE_KERNELS" = "yes" ]; then
        sudo apt-get remove -y $OLD_KERNELS
        sudo apt-get autoremove -y
        echo "   ✓ Old kernels đã được xóa"
    else
        echo "   ⊘ Bỏ qua xóa kernels"
    fi
else
    echo "   ℹ️  Không có old kernels"
fi
echo ""

# 8. Kiểm tra và xóa MongoDB nếu không sử dụng
echo "🗄️  Kiểm tra MongoDB..."
if systemctl is-active --quiet mongod 2>/dev/null; then
    echo "   ⚠️  MongoDB đang chạy"
    echo "   Nếu chatbot KHÔNG sử dụng MongoDB, bạn có thể xóa để giải phóng ~600MB"
    read -p "   Dừng và xóa MongoDB? (yes/no): " REMOVE_MONGO
    if [ "$REMOVE_MONGO" = "yes" ]; then
        sudo systemctl stop mongod
        sudo systemctl disable mongod
        sudo apt-get remove -y mongodb mongodb-org mongodb-org-server 2>/dev/null || sudo apt-get remove -y mongodb-* 2>/dev/null || true
        sudo rm -rf /var/lib/mongodb
        sudo rm -rf /var/log/mongodb
        sudo apt-get autoremove -y
        echo "   ✓ MongoDB đã được xóa"
    else
        echo "   ⊘ Giữ MongoDB"
    fi
elif dpkg -l | grep -q mongodb; then
    echo "   MongoDB đã cài nhưng không chạy"
    MONGO_SIZE=$(du -sh /var/lib/mongodb 2>/dev/null | cut -f1 || echo "0")
    echo "   Dung lượng data: $MONGO_SIZE"
    read -p "   Xóa MongoDB? (yes/no): " REMOVE_MONGO
    if [ "$REMOVE_MONGO" = "yes" ]; then
        sudo apt-get remove -y mongodb mongodb-org mongodb-org-server 2>/dev/null || sudo apt-get remove -y mongodb-* 2>/dev/null || true
        sudo rm -rf /var/lib/mongodb
        sudo rm -rf /var/log/mongodb
        sudo apt-get autoremove -y
        echo "   ✓ MongoDB đã được xóa"
    else
        echo "   ⊘ Giữ MongoDB"
    fi
else
    echo "   ℹ️  MongoDB không cài đặt"
fi
echo ""

# 9. Xóa snapd nếu không sử dụng snap packages
echo "📦 Kiểm tra Snapd..."
if dpkg -l | grep -q snapd; then
    SNAP_COUNT=$(snap list 2>/dev/null | wc -l || echo "0")
    SNAPD_SIZE=$(du -sh /var/lib/snapd 2>/dev/null | cut -f1 || echo "0")
    echo "   Snap packages: $((SNAP_COUNT - 1))"
    echo "   Dung lượng: $SNAPD_SIZE"
    if [ "$SNAP_COUNT" -le 1 ]; then
        read -p "   Không có snap packages nào. Xóa snapd? (yes/no): " REMOVE_SNAP
        if [ "$REMOVE_SNAP" = "yes" ]; then
            sudo systemctl stop snapd
            sudo systemctl disable snapd
            sudo apt-get remove -y snapd
            sudo rm -rf /var/lib/snapd
            sudo apt-get autoremove -y
            echo "   ✓ Snapd đã được xóa"
        else
            echo "   ⊘ Giữ snapd"
        fi
    else
        echo "   ℹ️  Đang sử dụng snap packages, giữ snapd"
    fi
else
    echo "   ℹ️  Snapd không cài đặt"
fi
echo ""

# 10. Tối ưu journald config để giới hạn log size
echo "⚙️  Tối ưu journald config..."
JOURNALD_CONF="/etc/systemd/journald.conf"
if [ -f "$JOURNALD_CONF" ]; then
    sudo sed -i 's/#SystemMaxUse=/SystemMaxUse=100M/' $JOURNALD_CONF
    sudo sed -i 's/#RuntimeMaxUse=/RuntimeMaxUse=50M/' $JOURNALD_CONF
    sudo systemctl restart systemd-journald
    echo "   ✓ Journald đã được giới hạn: SystemMaxUse=100M, RuntimeMaxUse=50M"
else
    echo "   ⚠️  Không tìm thấy $JOURNALD_CONF"
fi
echo ""

echo "✅ DỌN DẸP HOÀN TẤT!"
echo ""
echo "📊 Dung lượng sau khi dọn dẹp:"
df -h /
echo ""

echo "💡 Khuyến nghị thêm:"
echo "   1. Thiết lập logrotate cho application logs"
echo "   2. Định kỳ chạy: docker system prune -a (1 tuần/lần)"
echo "   3. Monitoring disk usage: ./scripts/analyze_disk_usage.sh"
echo "   4. Truncate btmp định kỳ: sudo truncate -s 0 /var/log/btmp"
echo "   5. Nếu dung lượng vẫn không đủ, cân nhắc nâng cấp VPS"
echo ""
echo "⚡ Ước tính đã giải phóng: ~500MB - 1.5GB"
echo ""
