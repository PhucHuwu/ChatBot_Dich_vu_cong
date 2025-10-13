#!/bin/bash

# Script tự động xóa các package không cần thiết cho deployment chatbot
# Dự án chạy trong Docker container, chỉ cần giữ các package cần thiết trên host

set -e

echo "================================================"
echo "Cleanup System Packages - ChatBot Dịch vụ công"
echo "================================================"
echo ""
echo "⚠️  CẢNH BÁO: Script này sẽ xóa các package không cần thiết"
echo "Vui lòng đọc kỹ danh sách trước khi xác nhận!"
echo ""

# Packages QUAN TRỌNG - KHÔNG XÓA
# - docker-* (Docker engine)
# - nginx* (Reverse proxy)
# - certbot*, python3-certbot* (SSL certificates)
# - git* (Version control)
# - curl, wget (Download tools, health checks)
# - ssh*, openssh* (Remote access)
# - systemd, udev (System core)
# - python3, python3-* (có thể cần cho scripts)
# - coreutils, util-linux (basic utilities)

# ==========================================
# DANH SÁCH PACKAGES CÓ THỂ XÓA
# ==========================================

# 1. MongoDB - Dự án KHÔNG sử dụng MongoDB
MONGODB_PACKAGES=(
    mongodb-database-tools
    mongodb-mongosh
    mongodb-org-database-tools-extra
    mongodb-org-database
    mongodb-org-mongos
    mongodb-org-server
    mongodb-org-shell
    mongodb-org-tools
    mongodb-org
)

# 2. LXD - Container system không sử dụng
LXD_PACKAGES=(
    lxd-agent-loader
    lxd-installer
)

# 3. Landscape - Canonical management tool
LANDSCAPE_PACKAGES=(
    landscape-common
)

# 4. FTP clients - Không cần
FTP_PACKAGES=(
    ftp
    tnftp
)

# 5. Telnet - Không bảo mật, không cần
TELNET_PACKAGES=(
    telnet
    inetutils-telnet
)

# 6. Apport - Crash reporting
APPORT_PACKAGES=(
    apport
    apport-symptoms
    apport-core-dump-handler
)

# 7. Plymouth - Boot splash screen
PLYMOUTH_PACKAGES=(
    plymouth
    plymouth-theme-ubuntu-text
)

# 8. Snap - Nếu không dùng snap packages
SNAP_PACKAGES=(
    snapd
)

# 9. Update notifier - Không cần trên production server
UPDATE_NOTIFIER_PACKAGES=(
    update-notifier-common
    ubuntu-release-upgrader-core
    update-manager-core
)

# 10. ModemManager - Không cần modem trên server
MODEM_PACKAGES=(
    modemmanager
    libmbim-glib4
    libmbim-proxy
    libmbim-utils
    libqmi-glib5
    libqmi-proxy
    libqmi-utils
)

# 11. Development tools - Chỉ cần nếu build packages trên host
# Tuy nhiên, Docker container đã có build tools, host không cần
# CẢNH BÁO: Chỉ xóa nếu chắc chắn không build gì trên host
DEV_TOOLS_PACKAGES=(
    build-essential
    gcc-13
    g++-13
    make
    dpkg-dev
    Bỏ comment nếu muốn xóa
)

# 12. Byobu, Screen, TMux - Terminal multiplexers (giữ lại nếu dùng)
# Uncomment để xóa nếu không dùng
TERMINAL_PACKAGES=(
    byobu
    screen  
    tmux
)

# 13. Các tools ít dùng
MISC_PACKAGES=(
    pastebinit
    needrestart
    deborphan
    bc
    ed
    mtr-tiny
    bolt
    fwupd
    fwupd-signed
    pollinate
    friendly-recovery
    motd-news-config
)

# ==========================================
# HỎI XÁC NHẬN
# ==========================================

echo "Các packages sẽ bị XÓA:"
echo ""
echo "✓ MongoDB (không sử dụng): ${#MONGODB_PACKAGES[@]} packages"
echo "✓ LXD containers: ${#LXD_PACKAGES[@]} packages"
echo "✓ Landscape: ${#LANDSCAPE_PACKAGES[@]} packages"
echo "✓ FTP clients: ${#FTP_PACKAGES[@]} packages"
echo "✓ Telnet: ${#TELNET_PACKAGES[@]} packages"
echo "✓ Apport (crash reporting): ${#APPORT_PACKAGES[@]} packages"
echo "✓ Plymouth (boot splash): ${#PLYMOUTH_PACKAGES[@]} packages"
echo "✓ Snapd: ${#SNAP_PACKAGES[@]} packages"
echo "✓ Update notifiers: ${#UPDATE_NOTIFIER_PACKAGES[@]} packages"
echo "✓ ModemManager: ${#MODEM_PACKAGES[@]} packages"
echo "✓ Misc unused tools: ${#MISC_PACKAGES[@]} packages"
echo ""

# Tổng hợp tất cả packages cần xóa
ALL_REMOVE_PACKAGES=(
    "${MONGODB_PACKAGES[@]}"
    "${LXD_PACKAGES[@]}"
    "${LANDSCAPE_PACKAGES[@]}"
    "${FTP_PACKAGES[@]}"
    "${TELNET_PACKAGES[@]}"
    "${APPORT_PACKAGES[@]}"
    "${PLYMOUTH_PACKAGES[@]}"
    "${SNAP_PACKAGES[@]}"
    "${UPDATE_NOTIFIER_PACKAGES[@]}"
    "${MODEM_PACKAGES[@]}"
    "${MISC_PACKAGES[@]}"
    "${DEV_TOOLS_PACKAGES[@]}"
    "${TERMINAL_PACKAGES[@]}"
)

echo "Tổng cộng: ${#ALL_REMOVE_PACKAGES[@]} packages"
echo ""

# Ước tính dung lượng giải phóng
echo "📊 Ước tính dung lượng giải phóng: ~500MB - 1GB"
echo ""

read -p "⚠️  Bạn có chắc chắn muốn tiếp tục? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Đã hủy."
    exit 1
fi

echo ""
echo "🔄 Bắt đầu gỡ cài đặt packages..."
echo ""

# ==========================================
# THỰC HIỆN XÓA
# ==========================================

# Xóa từng nhóm và log kết quả
remove_packages() {
    local package_name=$1
    shift
    local packages=("$@")
    
    echo "→ Đang xóa: $package_name..."
    
    # Lọc chỉ những package thực sự đã cài
    local to_remove=()
    for pkg in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii.*$pkg "; then
            to_remove+=("$pkg")
        fi
    done
    
    if [ ${#to_remove[@]} -eq 0 ]; then
        echo "  ℹ️  Không có package nào cần xóa"
        return
    fi
    
    sudo apt-get remove -y "${to_remove[@]}" 2>&1 | grep -E "(Removing|Purging|The following)" || true
    echo "  ✓ Đã xóa ${#to_remove[@]} packages"
}

# Xóa từng nhóm
remove_packages "MongoDB" "${MONGODB_PACKAGES[@]}"
remove_packages "LXD" "${LXD_PACKAGES[@]}"
remove_packages "Landscape" "${LANDSCAPE_PACKAGES[@]}"
remove_packages "FTP" "${FTP_PACKAGES[@]}"
remove_packages "Telnet" "${TELNET_PACKAGES[@]}"
remove_packages "Apport" "${APPORT_PACKAGES[@]}"
remove_packages "Plymouth" "${PLYMOUTH_PACKAGES[@]}"
remove_packages "Snapd" "${SNAP_PACKAGES[@]}"
remove_packages "Update Notifier" "${UPDATE_NOTIFIER_PACKAGES[@]}"
remove_packages "ModemManager" "${MODEM_PACKAGES[@]}"
remove_packages "Misc" "${MISC_PACKAGES[@]}"

if [ ${#DEV_TOOLS_PACKAGES[@]} -gt 0 ]; then
    remove_packages "Dev Tools" "${DEV_TOOLS_PACKAGES[@]}"
fi

if [ ${#TERMINAL_PACKAGES[@]} -gt 0 ]; then
    remove_packages "Terminal Tools" "${TERMINAL_PACKAGES[@]}"
fi

echo ""
echo "🧹 Dọn dẹp packages không sử dụng..."

# Autoremove các dependencies không cần
sudo apt-get autoremove -y

# Xóa cache
sudo apt-get autoclean

echo ""
echo "✅ HOÀN TẤT!"
echo ""
echo "📊 Kiểm tra dung lượng đã giải phóng:"
df -h /

echo ""
echo "🔍 Kiểm tra các services quan trọng vẫn hoạt động:"
echo ""

# Kiểm tra Docker
if systemctl is-active --quiet docker; then
    echo "✓ Docker: OK"
else
    echo "✗ Docker: FAILED - Vui lòng kiểm tra!"
fi

# Kiểm tra Nginx
if systemctl is-active --quiet nginx; then
    echo "✓ Nginx: OK"
else
    echo "⚠️  Nginx: Not running (có thể chưa bật)"
fi

# Kiểm tra SSH
if systemctl is-active --quiet ssh; then
    echo "✓ SSH: OK"
else
    echo "✗ SSH: FAILED - Vui lòng kiểm tra!"
fi

echo ""
echo "✅ Script hoàn tất. Hệ thống đã được tối ưu!"
echo ""
echo "💡 Các bước tiếp theo:"
echo "   1. Reboot server: sudo reboot"
echo "   2. Kiểm tra Docker: docker ps"
echo "   3. Kiểm tra chatbot: docker compose up"
echo ""
