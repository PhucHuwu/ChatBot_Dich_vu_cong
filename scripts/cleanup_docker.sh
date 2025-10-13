#!/bin/bash

# Script cleanup Docker để tiết kiệm dung lượng
# Sử dụng: ./cleanup_docker.sh [--aggressive]

set -e

echo "==================================="
echo "Docker Cleanup Script"
echo "==================================="
echo ""

# Kiểm tra dung lượng trước cleanup
echo "📊 Disk usage TRƯỚC cleanup:"
echo "-----------------------------------"
df -h / | grep -E 'Filesystem|/dev'
echo ""
docker system df
echo ""

# Hỏi xác nhận
read -p "⚠️  Bạn có muốn tiếp tục cleanup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Đã hủy."
    exit 1
fi

echo ""
echo "🧹 Bắt đầu cleanup..."
echo ""

# Stop containers (không xóa)
echo "1️⃣  Stopping containers..."
docker-compose down 2>/dev/null || true

# Cleanup từng bước
echo "2️⃣  Removing stopped containers..."
docker container prune -f

echo "3️⃣  Removing dangling images..."
docker image prune -f

echo "4️⃣  Removing unused networks..."
docker network prune -f

# Nếu --aggressive được chỉ định
if [[ "$1" == "--aggressive" ]]; then
    echo ""
    echo "⚡ AGGRESSIVE MODE"
    read -p "⚠️  Xóa TẤT CẢ images không dùng? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "5️⃣  Removing ALL unused images..."
        docker image prune -a -f
        
        echo "6️⃣  Removing unused volumes..."
        docker volume prune -f
        
        echo "7️⃣  Removing build cache..."
        docker builder prune -a -f
    fi
fi

echo ""
echo "✅ Cleanup hoàn tất!"
echo ""

# Kiểm tra dung lượng sau cleanup
echo "📊 Disk usage SAU cleanup:"
echo "-----------------------------------"
df -h / | grep -E 'Filesystem|/dev'
echo ""
docker system df
echo ""

# Tính dung lượng đã giải phóng (rough estimate)
echo "💡 TIP: Để cleanup toàn bộ (cẩn thận!):"
echo "   docker system prune -a -f --volumes"
echo ""
echo "💡 Khởi động lại container:"
echo "   docker-compose up -d"
echo ""
