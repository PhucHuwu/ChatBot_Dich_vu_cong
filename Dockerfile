# ===== Stage 1: Builder - Cài đặt dependencies =====
FROM python:3.12.3-slim as builder

WORKDIR /build

# Chỉ cài công cụ build cần thiết
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

COPY requirements-prod.txt .

# Cài torch CPU-only trước để tránh tải CUDA version (tiết kiệm ~1GB)
RUN pip install --no-cache-dir --user \
    torch==2.8.0 \
    --index-url https://download.pytorch.org/whl/cpu

# Cài các dependencies còn lại (sentence-transformers sẽ dùng torch đã cài)
RUN pip install --no-cache-dir --user \
    -r requirements-prod.txt \
    --extra-index-url https://download.pytorch.org/whl/cpu

# Verify torch được cài đặt
RUN python -c "import torch; print(f'Torch version: {torch.__version__}')"

# Cleanup để giảm dung lượng image
RUN rm -rf /root/.cache/pip && \
    find /root/.local -type f -name "*.pyc" -delete && \
    find /root/.local -type f -name "*.pyo" -delete && \
    find /root/.local -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

# ===== Stage 2: Runtime - Image chạy thực tế =====
FROM python:3.12.3-slim

WORKDIR /app

# Chỉ cài curl cho healthcheck, tối ưu size
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && rm -rf /tmp/* /var/tmp/*

# Copy dependencies đã được tối ưu từ builder
COPY --from=builder /root/.local /root/.local

ENV PATH=/root/.local/bin:$PATH

# Copy source code (tối ưu layer caching)
COPY app.py rag.py embedding.py chunking.py config.py \
     llm_client.py logger_utils.py cache.py ./

# Copy dữ liệu và frontend
COPY data/ ./data/
COPY frontend/ ./frontend/

# Tạo thư mục embeddings
RUN mkdir -p embeddings

# Copy và set permission cho entrypoint
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    APP_ENV=production \
    DEBUG=False \
    # Tối ưu Python runtime
    PYTHONDONTWRITEBYTECODE=1 \
    # Giảm memory footprint của Python
    MALLOC_MMAP_THRESHOLD_=131072 \
    MALLOC_TRIM_THRESHOLD_=131072 \
    MALLOC_TOP_PAD_=131072

EXPOSE 8000

# Healthcheck nhẹ hơn
HEALTHCHECK --interval=45s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]

# CMD để trống vì entrypoint.sh đã handle gunicorn command
CMD []
