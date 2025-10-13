#!/bin/bash

# Script build Docker image với tối ưu tối đa
# Sử dụng: ./optimize_build.sh

set -e

echo "==========================================="
echo "  Optimized Docker Build Script"
echo "==========================================="
echo ""

# Kiểm tra requirements
command -v docker >/dev/null 2>&1 || { echo "❌ Docker chưa cài đặt!"; exit 1; }

# Kiểm tra dung lượng
echo "📊 Kiểm tra dung lượng hiện tại..."
df -h / | grep -E 'Filesystem|/dev'
echo ""

available=$(df / | tail -1 | awk '{print $4}')
required=3000000  # 3GB in KB

if [ "$available" -lt "$required" ]; then
    echo "⚠️  WARNING: Dung lượng thấp (< 3GB free)"
    echo "Chạy cleanup trước khi build:"
    echo "  ./scripts/cleanup_docker.sh --aggressive"
    echo ""
    read -p "Tiếp tục build? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Cleanup trước khi build
echo "🧹 Cleanup Docker cache cũ..."
docker builder prune -f
echo ""

# Build với BuildKit
echo "🔨 Building Docker image với tối ưu..."
echo ""

export DOCKER_BUILDKIT=1
export BUILDKIT_PROGRESS=plain

IMAGE_NAME="chatbot-dichvucong"
TAG="optimized"

# Build
time docker build \
    --tag ${IMAGE_NAME}:${TAG} \
    --tag ${IMAGE_NAME}:latest \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    .

echo ""
echo "✅ Build thành công!"
echo ""

# Kiểm tra kích thước
echo "📦 Thông tin image:"
echo "-----------------------------------"
docker images ${IMAGE_NAME} --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
echo ""

# Kiểm tra layers
echo "📊 Image layers:"
docker history ${IMAGE_NAME}:${TAG} --human --no-trunc | head -20
echo ""

# Phân tích image size
echo "🔍 Phân tích dung lượng image..."
docker run --rm ${IMAGE_NAME}:${TAG} du -sh / 2>/dev/null || true
echo ""

# Recommendations
size=$(docker images ${IMAGE_NAME}:${TAG} --format "{{.Size}}")
echo "💡 RECOMMENDATIONS:"
echo "-----------------------------------"
echo "✓ Image size: $size"

if [[ "$size" == *"GB"* ]]; then
    size_num=$(echo $size | sed 's/GB//')
    if (( $(echo "$size_num > 1.5" | bc -l) )); then
        echo "⚠️  Image lớn hơn 1.5GB. Xem xét:"
        echo "   - Kiểm tra .dockerignore"
        echo "   - Loại bỏ dependencies không cần thiết"
        echo "   - Prebuild embeddings bên ngoài"
    else
        echo "✓ Kích thước hợp lý cho server nhỏ"
    fi
fi

echo ""
echo "🚀 Sẵn sàng deploy:"
echo "   docker-compose up -d"
echo ""
echo "📊 Giám sát resources:"
echo "   ./scripts/monitor_resources.sh"
echo ""
