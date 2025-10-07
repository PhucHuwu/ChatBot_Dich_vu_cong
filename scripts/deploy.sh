#!/bin/bash
# Production deployment script
# Sử dụng: ./scripts/deploy.sh [environment]

set -e

ENVIRONMENT=${1:-production}

echo "=========================================="
echo "Deploying ChatBot Dịch vụ công"
echo "Environment: $ENVIRONMENT"
echo "=========================================="

# 1. Pull latest code
echo "Step 1: Pulling latest code..."
git pull origin main

# 2. Check .env file
if [ ! -f ".env" ]; then
    echo "Error: .env file not found!"
    echo "Please copy .env.example to .env and configure it."
    exit 1
fi

# 3. Build Docker image
echo "Step 2: Building Docker image..."
docker-compose build

# 4. Stop existing containers
echo "Step 3: Stopping existing containers..."
docker-compose down

# 5. Start new containers
echo "Step 4: Starting new containers..."
docker-compose up -d

# 6. Wait for service to be ready
echo "Step 5: Waiting for service to start..."
sleep 10

# 7. Health check
echo "Step 6: Running health check..."
./scripts/health_check.sh localhost 8000

echo "=========================================="
echo "Deployment completed successfully!"
echo "=========================================="
echo ""
echo "Useful commands:"
echo "  - View logs: docker-compose logs -f"
echo "  - Stop: docker-compose down"
echo "  - Rebuild index: docker-compose exec chatbot python -c 'from rag import build_index; build_index()'"
echo ""
