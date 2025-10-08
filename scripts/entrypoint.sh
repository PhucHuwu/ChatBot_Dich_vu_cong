#!/bin/bash
set -e

echo "=== ChatBot Dịch vụ công - Container Starting ==="
echo "Environment: ${APP_ENV:-development}"
echo "Python version: $(python --version)"
echo "Working directory: $(pwd)"

# Kiểm tra biến môi trường bắt buộc
if [ -z "$GROQ_API_KEY" ]; then
    echo "ERROR: GROQ_API_KEY is not set. Please provide it via environment variable."
    exit 1
fi

echo "✓ GROQ_API_KEY is configured"

# Kiểm tra data directory
if [ ! -d "data" ]; then
    echo "ERROR: Data directory not found. Cannot proceed without source data."
    exit 1
fi

echo "✓ Data directory exists"

# Kiểm tra embeddings directory và index files
INDEX_PATH="${INDEX_PATH:-embeddings/faiss_index.bin}"
METADATA_PATH="${METADATA_PATH:-embeddings/metadata.pkl}"

if [ -f "$INDEX_PATH" ] && [ -f "$METADATA_PATH" ]; then
    echo "✓ Index files found. Skipping rebuild."
    echo "  - Index: $INDEX_PATH"
    echo "  - Metadata: $METADATA_PATH"
else
    echo "⚠ Index files not found. Building index..."
    echo "  This may take a few minutes on first run..."
    
    # Chạy script Python để build index
    python -c "
from rag import build_index
import sys
try:
    print('Starting index build...')
    build_index()
    print('✓ Index built successfully!')
    sys.exit(0)
except Exception as e:
    print(f'ERROR building index: {e}')
    import traceback
    traceback.print_exc()
    sys.exit(1)
"
    
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to build index. Check logs above."
        exit 1
    fi
fi

# Kiểm tra model có load được không
echo "Validating embedding model..."
python -c "
from embedding import get_embedding_model
try:
    model = get_embedding_model()
    print(f'✓ Embedding model loaded successfully')
except Exception as e:
    print(f'ERROR loading embedding model: {e}')
    import sys
    sys.exit(1)
"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to load embedding model."
    exit 1
fi

# Thiết lập workers từ biến môi trường hoặc mặc định
WORKERS=${WORKERS:-4}
echo "Gunicorn workers: $WORKERS"

echo "=== Starting Gunicorn Server ==="
echo ""

# Chạy Gunicorn với cấu hình động
exec gunicorn app:app \
    --workers "$WORKERS" \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:${PORT:-8000} \
    --timeout 180 \
    --keep-alive 5 \
    --access-logfile - \
    --error-logfile - \
    --log-level "${LOG_LEVEL:-info}" \
    "$@"
