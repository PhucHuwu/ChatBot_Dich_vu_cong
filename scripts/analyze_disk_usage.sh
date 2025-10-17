#!/bin/bash

# Script phân tích dung lượng ổ đĩa chi tiết
# Tìm các thư mục/file lớn đang chiếm dung lượng

echo "================================================"
echo "Phân tích Dung lượng Ổ đĩa - ChatBot DVC"
echo "================================================"
echo ""

echo "📊 Tổng quan hệ thống:"
df -h /
echo ""

echo "🔍 Top 10 thư mục lớn nhất trong /"
echo "   (Có thể mất 1-2 phút để quét...)"
sudo du -hx / 2>/dev/null | sort -rh | head -20
echo ""

echo "🐳 Docker sử dụng bao nhiêu dung lượng:"
docker system df
echo ""

echo "📝 Journal logs:"
sudo journalctl --disk-usage
echo ""

echo "📦 APT cache:"
du -sh /var/cache/apt/archives 2>/dev/null || echo "N/A"
echo ""

echo "🗑️  Temporary files:"
du -sh /tmp 2>/dev/null || echo "N/A"
du -sh /var/tmp 2>/dev/null || echo "N/A"
echo ""

echo "📚 Log files trong /var/log:"
sudo du -sh /var/log/* 2>/dev/null | sort -rh | head -10
echo ""

echo "🏠 Home directories:"
sudo du -sh /home/* 2>/dev/null | sort -rh
sudo du -sh /root 2>/dev/null
echo ""

echo "✅ Phân tích hoàn tất!"
