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

# Cài dependencies với tối ưu dung lượng
RUN pip install --no-cache-dir --user -r requirements-prod.txt && \
    # Xóa cache pip
    rm -rf /root/.cache/pip && \
    # Xóa các file không cần thiết (sử dụng -delete thay vì -exec rm để an toàn hơn)
    find /root/.local -type d -name "tests" -prune -exec rm -rf {} \; 2>/dev/null || true && \
    find /root/.local -type d -name "test" -prune -exec rm -rf {} \; 2>/dev/null || true && \
    find /root/.local -type d -name "__pycache__" -prune -exec rm -rf {} \; 2>/dev/null || true && \
    find /root/.local -name "*.pyc" -delete && \
    find /root/.local -name "*.pyo" -delete

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
     llm_client.py logger_utils.py cache.py context_analyzer.py ./

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

# Giảm workers mặc định để tiết kiệm RAM
CMD ["gunicorn", "app:app", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--bind", "0.0.0.0:8000", \
     "--workers", "2", \
     "--timeout", "180", \
     "--keep-alive", "5", \
     "--max-requests", "1000", \
     "--max-requests-jitter", "100", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "--log-level", "info"]
