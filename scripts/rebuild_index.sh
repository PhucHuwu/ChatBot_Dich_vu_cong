#!/bin/bash
# Script để rebuild FAISS index
# Sử dụng: ./scripts/rebuild_index.sh [batch_size]

set -e  # Exit on error

BATCH_SIZE=${1:-32}

echo "=========================================="
echo "Rebuilding FAISS Index"
echo "Batch size: $BATCH_SIZE"
echo "=========================================="

# Activate virtual environment nếu có
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Run rebuild
python -c "
from rag import build_index
from config import settings

print(f'Environment: {settings.APP_ENV}')
print(f'Embedding model: {settings.EMBEDDING_MODEL}')
print('Starting index rebuild...')

build_index(batch_size=$BATCH_SIZE)

print('Index rebuild completed successfully!')
"

echo "=========================================="
echo "Index rebuild finished!"
echo "Files created:"
ls -lh embeddings/
echo "=========================================="
