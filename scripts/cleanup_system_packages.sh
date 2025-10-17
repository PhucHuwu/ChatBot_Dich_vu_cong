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

# 1. Cloud/VM tools - Không cần cho bare metal hoặc production server
CLOUD_PACKAGES=(
    cloud-init
    cloud-guest-utils
    cloud-initramfs-copymods
    cloud-initramfs-dyn-netconf
    open-vm-tools
)

# 2. Development headers & tools - Build trong Docker, không cần trên host
DEV_PACKAGES=(
    linux-headers-6.8.0-31-generic
    linux-headers-6.8.0-31
    linux-headers-generic
    linux-headers-virtual
    linux-libc-dev
    libc-dev-bin
    libc-devtools
    libc6-dev
    libcrypt-dev
    libexpat1-dev
    libpython3-dev
    libpython3.12-dev
    python3-dev
    python3.12-dev
    systemd-dev
    libssl-dev
    libsasl2-dev
    librdkafka-dev
    liblz4-dev
    libzstd-dev
    manpages-dev
    binutils
    binutils-common
    binutils-x86-64-linux-gnu
)

# 3. Desktop/GUI/Font packages - Server không cần
GUI_PACKAGES=(
    fonts-dejavu-core
    fonts-dejavu-mono
    fonts-ubuntu-console
    fontconfig-config
    libfontconfig1
    libfreetype6
    libx11-6
    libx11-data
    libxau6
    libxcb1
    libxdmcp6
    libxext6
    libxpm4
    libxmuu1
    xauth
    xdg-user-dirs
    xkb-data
)

# 4. Image processing libraries - Không cần trên server
IMAGE_LIBS=(
    libgd3
    libjpeg-turbo8
    libjpeg8
    libjbig0
    libpng16-16t64
    libtiff6
    libwebp7
    libsharpyuv0
    libheif1
    libheif-plugin-aomdec
    libheif-plugin-aomenc
    libheif-plugin-libde265
    libde265-0
    libaom3
)

# 5. Multimedia - Không cần
MULTIMEDIA_PACKAGES=(
    libgstreamer1.0-0
)

# 6. Hardware tools - Không cần cho server ảo
HARDWARE_TOOLS=(
    bcache-tools
    dmidecode
    efibootmgr
    hdparm
    lshw
    pciutils
    pci.ids
    usbutils
    usb.ids
    sg3-utils
    sg3-utils-udev
)

# 7. Filesystem tools không dùng
FILESYSTEM_TOOLS=(
    btrfs-progs
    dosfstools
    ntfs-3g
    xfsprogs
    gdisk
    gpart
)

# 8. Advanced storage - Không sử dụng LVM/RAID/multipath
STORAGE_TOOLS=(
    lvm2
    dmsetup
    dmeventd
    libdevmapper-event1.02.1
    liblvm2cmd2.03
    thin-provisioning-tools
    multipath-tools
    mdadm
    kpartx
)

# 9. iSCSI - Không sử dụng
ISCSI_PACKAGES=(
    open-iscsi
    libisns0t64
    libopeniscsiusr
)

# 10. Network tools ít dùng
NETWORK_TOOLS=(
    bind9-dnsutils
    bind9-host
    bind9-libs
    tcpdump
    net-tools
    netcat-openbsd
    traceroute
    iputils-tracepath
)

# 11. Documentation & man pages
DOC_PACKAGES=(
    man-db
    manpages
    info
    groff-base
)

# 12. Debugging/monitoring tools không cần thiết
DEBUG_TOOLS=(
    strace
    trace-cmd
    sosreport
)

# 13. Update/upgrade tools - Quản lý manual
UPDATE_PACKAGES=(
    unattended-upgrades
    ubuntu-pro-client
    ubuntu-pro-client-l10n
    command-not-found
)

# 14. PolicyKit/PackageKit - Không cần trên server
POLICY_PACKAGES=(
    polkitd
    packagekit
    packagekit-tools
    libpolkit-agent-1-0
    libpolkit-gobject-1-0
    libpackagekit-glib2-18
)

# 15. Misc utilities không cần thiết
MISC_PACKAGES=(
    localepurge
    appstream
    iso-codes
    shared-mime-info
    javascript-common
    libjs-jquery
    libjs-sphinxdoc
    libjs-underscore
    xml-core
    sgml-base
    media-types
)

# ==========================================
# HỎI XÁC NHẬN
# ==========================================

echo "Các packages sẽ bị XÓA:"
echo ""
echo "✓ Cloud/VM tools: ${#CLOUD_PACKAGES[@]} packages"
echo "✓ Development headers/tools: ${#DEV_PACKAGES[@]} packages"
echo "✓ Desktop/GUI/Fonts: ${#GUI_PACKAGES[@]} packages"
echo "✓ Image processing libs: ${#IMAGE_LIBS[@]} packages"
echo "✓ Multimedia: ${#MULTIMEDIA_PACKAGES[@]} packages"
echo "✓ Hardware tools: ${#HARDWARE_TOOLS[@]} packages"
echo "✓ Filesystem tools: ${#FILESYSTEM_TOOLS[@]} packages"
echo "✓ Storage tools (LVM/RAID): ${#STORAGE_TOOLS[@]} packages"
echo "✓ iSCSI: ${#ISCSI_PACKAGES[@]} packages"
echo "✓ Network tools: ${#NETWORK_TOOLS[@]} packages"
echo "✓ Documentation: ${#DOC_PACKAGES[@]} packages"
echo "✓ Debug tools: ${#DEBUG_TOOLS[@]} packages"
echo "✓ Update tools: ${#UPDATE_PACKAGES[@]} packages"
echo "✓ PolicyKit/PackageKit: ${#POLICY_PACKAGES[@]} packages"
echo "✓ Misc utilities: ${#MISC_PACKAGES[@]} packages"
echo ""

# Tổng hợp tất cả packages cần xóa
ALL_REMOVE_PACKAGES=(
    "${CLOUD_PACKAGES[@]}"
    "${DEV_PACKAGES[@]}"
    "${GUI_PACKAGES[@]}"
    "${IMAGE_LIBS[@]}"
    "${MULTIMEDIA_PACKAGES[@]}"
    "${HARDWARE_TOOLS[@]}"
    "${FILESYSTEM_TOOLS[@]}"
    "${STORAGE_TOOLS[@]}"
    "${ISCSI_PACKAGES[@]}"
    "${NETWORK_TOOLS[@]}"
    "${DOC_PACKAGES[@]}"
    "${DEBUG_TOOLS[@]}"
    "${UPDATE_PACKAGES[@]}"
    "${POLICY_PACKAGES[@]}"
    "${MISC_PACKAGES[@]}"
)

echo "Tổng cộng: ${#ALL_REMOVE_PACKAGES[@]} packages"
echo ""

# Ước tính dung lượng giải phóng
echo "📊 Ước tính dung lượng giải phóng: ~1GB - 2GB"
echo ""
echo "⚠️  LƯU Ý: Các packages QUAN TRỌNG sau sẽ KHÔNG bị xóa:"
echo "   • Docker (docker-ce, docker-compose-plugin, etc.)"
echo "   • Nginx & SSL (nginx, certbot, python3-certbot-nginx)"
echo "   • SSH (openssh-server, openssh-client)"
echo "   • Git (git)"
echo "   • Python3 & pip (cần cho scripts và certbot)"
echo "   • Curl, wget (health checks & downloads)"
echo "   • Systemd & core utilities"
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
remove_packages "Cloud/VM Tools" "${CLOUD_PACKAGES[@]}"
remove_packages "Development Headers/Tools" "${DEV_PACKAGES[@]}"
remove_packages "Desktop/GUI/Fonts" "${GUI_PACKAGES[@]}"
remove_packages "Image Processing Libraries" "${IMAGE_LIBS[@]}"
remove_packages "Multimedia" "${MULTIMEDIA_PACKAGES[@]}"
remove_packages "Hardware Tools" "${HARDWARE_TOOLS[@]}"
remove_packages "Filesystem Tools" "${FILESYSTEM_TOOLS[@]}"
remove_packages "Storage Tools (LVM/RAID)" "${STORAGE_TOOLS[@]}"
remove_packages "iSCSI" "${ISCSI_PACKAGES[@]}"
remove_packages "Network Tools" "${NETWORK_TOOLS[@]}"
remove_packages "Documentation" "${DOC_PACKAGES[@]}"
remove_packages "Debug Tools" "${DEBUG_TOOLS[@]}"
remove_packages "Update Tools" "${UPDATE_PACKAGES[@]}"
remove_packages "PolicyKit/PackageKit" "${POLICY_PACKAGES[@]}"
remove_packages "Misc Utilities" "${MISC_PACKAGES[@]}"

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
