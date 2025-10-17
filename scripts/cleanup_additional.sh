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

# 8. Tối ưu journald config để giới hạn log size
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
echo "   3. Monitoring disk usage với script: ./scripts/analyze_disk_usage.sh"
echo "   4. Cân nhắc tăng dung lượng disk nếu cần thiết"
echo ""
