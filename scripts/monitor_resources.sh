#!/bin/bash

# Script giám sát tài nguyên Docker container
# Sử dụng: ./monitor_resources.sh [interval_seconds]

INTERVAL=${1:-5}
CONTAINER_NAME="chatbot-dichvucong"

echo "========================================"
echo "  Resource Monitor - Chatbot Container  "
echo "========================================"
echo "Press Ctrl+C to stop"
echo ""

# Màu sắc
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Hàm kiểm tra ngưỡng
check_threshold() {
    local value=$1
    local warning=$2
    local critical=$3
    
    if (( $(echo "$value >= $critical" | bc -l) )); then
        echo -e "${RED}${value}${NC}"
    elif (( $(echo "$value >= $warning" | bc -l) )); then
        echo -e "${YELLOW}${value}${NC}"
    else
        echo -e "${GREEN}${value}${NC}"
    fi
}

# Kiểm tra container có chạy không
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Container '${CONTAINER_NAME}' không chạy!"
    echo ""
    echo "Khởi động container:"
    echo "  docker-compose up -d"
    exit 1
fi

echo "📊 Monitoring container: ${CONTAINER_NAME}"
echo "⏱️  Interval: ${INTERVAL}s"
echo ""

# Counter để refresh header
counter=0

while true; do
    # Refresh header mỗi 10 lần
    if [ $counter -eq 0 ]; then
        clear
        echo "========================================"
        echo "  Resource Monitor - $(date '+%Y-%m-%d %H:%M:%S')"
        echo "========================================"
        echo ""
        
        # System overview
        echo "🖥️  SYSTEM RESOURCES:"
        echo "-----------------------------------"
        free -h | grep -E 'total|Mem|Swap'
        echo ""
        df -h / | grep -E 'Filesystem|/dev'
        echo ""
        
        echo "🐳 DOCKER RESOURCES:"
        echo "-----------------------------------"
        docker system df
        echo ""
        
        echo "📦 CONTAINER STATS:"
        echo "-----------------------------------"
        printf "%-12s %-15s %-15s %-10s %-10s\n" "TIME" "CPU %" "MEMORY" "MEM %" "NET I/O"
        echo "-----------------------------------"
    fi
    
    # Lấy stats
    stats=$(docker stats --no-stream --format "{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}" $CONTAINER_NAME)
    
    # Parse values
    cpu=$(echo "$stats" | cut -f1 | sed 's/%//')
    mem_usage=$(echo "$stats" | cut -f2)
    mem_perc=$(echo "$stats" | cut -f3 | sed 's/%//')
    net_io=$(echo "$stats" | cut -f4)
    
    # Display với màu sắc
    timestamp=$(date '+%H:%M:%S')
    cpu_colored=$(check_threshold $cpu 50 80)
    mem_colored=$(check_threshold $mem_perc 70 85)
    
    printf "%-12s %s%-13s %s  %-15s %s%-8s %s  %-10s\n" \
        "$timestamp" \
        "" "$cpu_colored" "%" \
        "$mem_usage" \
        "" "$mem_colored" "%" \
        "$net_io"
    
    # Cảnh báo nếu vượt ngưỡng
    if (( $(echo "$mem_perc >= 85" | bc -l) )); then
        echo -e "${RED}⚠️  WARNING: Memory usage cao! Xem xét restart hoặc giảm WORKERS${NC}"
    fi
    
    if (( $(echo "$cpu >= 80" | bc -l) )); then
        echo -e "${YELLOW}⚠️  WARNING: CPU usage cao!${NC}"
    fi
    
    # Container health
    health=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER_NAME 2>/dev/null || echo "none")
    if [ "$health" != "healthy" ] && [ "$health" != "none" ]; then
        echo -e "${RED}❌ Container health: $health${NC}"
    fi
    
    # Tăng counter và reset sau 10
    counter=$((counter + 1))
    if [ $counter -ge 10 ]; then
        counter=0
    fi
    
    sleep $INTERVAL
done
