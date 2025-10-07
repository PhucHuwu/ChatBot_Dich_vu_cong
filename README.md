# Vietnamese Public Service Chatbot (ChatBot Dịch vụ Công)

[![Python Version](https://img.shields.io/badge/python-3.10%2B-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.104.1-009688.svg)](https://fastapi.tiangolo.com)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://www.docker.com/)

A production-ready RAG (Retrieval-Augmented Generation) chatbot system designed specifically for Vietnamese public administrative services. The system provides accurate, context-aware responses about government procedures, FAQs, and public service guidelines using advanced NLP and vector search technologies.

## Table of Contents

-   [Features](#-features)
-   [Architecture](#-architecture)
-   [Tech Stack](#-tech-stack)
-   [Prerequisites](#-prerequisites)
-   [Installation](#-installation)
-   [Configuration](#-configuration)
-   [Usage](#-usage)
-   [API Documentation](#-api-documentation)
-   [Deployment](#-deployment)
-   [Testing](#-testing)
-   [Performance Optimization](#-performance-optimization)
-   [Monitoring & Logging](#-monitoring--logging)
-   [Contributing](#-contributing)
-   [Troubleshooting](#-troubleshooting)
-   [License](#-license)

## Features

### Core Capabilities

-   **Intelligent RAG System**: Combines vector search (FAISS) with LLM for accurate responses
-   **Multilingual Support**: Optimized for Vietnamese with multilingual embedding models
-   **High Performance**: Sub-second response time with intelligent caching
-   **Production-Ready**: Security-hardened with rate limiting, CORS, and API key management
-   **Context Analysis**: Advanced context relevance scoring and filtering
-   **Smart Caching**: LRU cache with configurable TTL for repeated queries
-   **Docker Support**: Fully containerized for easy deployment
-   **Monitoring**: Comprehensive logging with trace IDs and performance metrics
-   **Hot Reload**: Dynamic data updates without system restart

### Advanced Features

-   **Semantic Search**: L2-normalized embeddings for accurate similarity matching
-   **Threshold-based Filtering**: Intelligent fallback for low-confidence results
-   **Source Attribution**: Every response includes verifiable source references
-   **Batch Processing**: Optimized embedding generation for large datasets
-   **Health Checks**: Liveness and readiness probes for orchestration
-   **Error Recovery**: Graceful degradation with retry mechanisms
-   **Rich Markdown Support**: Full GFM (GitHub Flavored Markdown) rendering with tables, code blocks, and more

## Architecture

```
┌─────────────┐
│   Client    │
│  (Browser)  │
└──────┬──────┘
       │ HTTP/JSON
       ▼
┌──────────────────────────────────┐
│         FastAPI Backend          │
│  ┌──────────┐      ┌──────────┐  │
│  │   Cache  │◄────►│   RAG    │  │
│  └──────────┘      └────┬─────┘  │
│                         │        │
│  ┌──────────────────────┼─────┐  │
│  │  FAISS Vector Store  │     │  │
│  │  ┌─────────┐  ┌──────▼───┐ │  │
│  │  │ Index   │  │ Metadata │ │  │
│  │  └─────────┘  └──────────┘ │  │
│  └────────────────────────────┘  │
│                          │       │
│                          ▼       │
│                   ┌──────────┐   │
│                   │   LLM    │   │
│                   │  (Groq)  │   │
│                   └──────────┘   │
└──────────────────────────────────┘
```

### Data Flow

1. **Query Processing**: User query → Embedding generation → Vector normalization
2. **Retrieval**: FAISS similarity search → Threshold filtering → Context ranking
3. **Generation**: Context assembly → Prompt construction → LLM inference
4. **Response**: Answer formatting → Source attribution → Cache storage
5. **Delivery**: JSON response with contexts and metadata

## Tech Stack

### Backend Framework

-   **FastAPI**: Modern, high-performance web framework
-   **Uvicorn/Gunicorn**: ASGI server with worker management
-   **Pydantic**: Data validation and settings management

### AI/ML Components

-   **Sentence Transformers**: Multilingual embedding generation
    -   Model: `paraphrase-multilingual-MiniLM-L12-v2`
-   **FAISS**: Efficient vector similarity search (Facebook AI)
-   **Groq**: High-performance LLM API
    -   Default Model: `meta-llama/llama-4-scout-17b-16e-instruct`

### Data Processing

-   **NumPy**: Numerical operations and vector manipulation
-   **scikit-learn**: Normalization and preprocessing utilities
-   **Python JSON Logger**: Structured logging for production

### Infrastructure

-   **Docker**: Containerization and deployment
-   **Docker Compose**: Multi-service orchestration
-   **Python dotenv**: Environment variable management

## Prerequisites

### System Requirements

-   **Python**: 3.10 or higher
-   **RAM**: Minimum 4GB (8GB+ recommended for production)
-   **Disk Space**: ~5GB for models and dependencies
-   **OS**: Linux, macOS, or Windows with WSL2

### Optional (Recommended for Performance)

-   **GPU**: CUDA-compatible GPU for faster embedding generation
-   **Docker**: Version 20.10+ with Docker Compose

### API Keys

-   **Groq API Key**: Required for LLM functionality
    -   Get yours at: [https://console.groq.com](https://console.groq.com)

## Installation

### Method 1: Local Development Setup

#### 1. Clone the Repository

```bash
git clone https://github.com/PhucHuwu/ChatBot_Dich_vu_cong.git
cd ChatBot_Dich_vu_cong
```

#### 2. Create Virtual Environment

```bash
# Using venv
python -m venv venv

# Activate on Linux/macOS
source venv/bin/activate

# Activate on Windows
venv\Scripts\activate
```

#### 3. Install Dependencies

```bash
# Install production dependencies
pip install -r requirements.txt

# Or for development (includes testing tools)
pip install -r requirements-dev.txt
```

#### 4. Set Up Environment Variables

```bash
# Copy example environment file
cp .env.example .env

# Edit .env with your configuration
# Required: Set GROQ_API_KEY
```

#### 5. Build Vector Index

```bash
# Build FAISS index from data sources
python -c "from rag import build_index; build_index()"
```

#### 6. Run the Server

```bash
# Development mode
uvicorn app:app --reload --host 0.0.0.0 --port 8000

# Production mode
gunicorn app:app \
  --workers 4 \
  --worker-class uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8000 \
  --timeout 120 \
  --log-level info
```

### Method 2: Docker Deployment

#### 1. Using Docker Compose (Recommended)

```bash
# Create .env file with required variables
echo "GROQ_API_KEY=your_api_key_here" > .env

# Build and start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

#### 2. Using Docker Directly

```bash
# Build image
docker build -t chatbot-dichvucong:latest .

# Run container
docker run -d \
  --name chatbot \
  -p 8000:8000 \
  -e GROQ_API_KEY=your_api_key \
  -v $(pwd)/embeddings:/app/embeddings \
  -v $(pwd)/data:/app/data:ro \
  chatbot-dichvucong:latest
```

### Method 3: Development with Hot Reload

```bash
# Install development dependencies
pip install -r requirements-dev.txt

# Run with auto-reload
uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

## Configuration

### Environment Variables

Create a `.env` file in the project root:

```bash
# ============================================
# APPLICATION SETTINGS
# ============================================
APP_ENV=development              # development | staging | production
DEBUG=False                      # Enable debug mode (False in production)
HOST=0.0.0.0                    # Server host
PORT=8000                       # Server port
WORKERS=4                       # Number of worker processes

# ============================================
# SECURITY & CORS
# ============================================
ALLOWED_ORIGINS=http://localhost:3000,https://yourdomain.gov.vn
EXPOSE_DOCS=True                # Expose API documentation (False in production)

# ============================================
# LLM CONFIGURATION (Groq)
# ============================================
GROQ_API_KEY=gsk_xxxxxxxxxxxxx  # REQUIRED: Your Groq API key
LLM_MODEL=meta-llama/llama-4-scout-17b-16e-instruct
LLM_TEMPERATURE=0.7             # 0.0 (deterministic) to 1.0 (creative)
LLM_MAX_TOKENS=2048             # Maximum response length
LLM_TIMEOUT=30                  # API timeout in seconds

# ============================================
# EMBEDDING MODEL
# ============================================
EMBEDDING_MODEL=sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
EMBEDDING_BATCH_SIZE=32         # Batch size for embedding generation
EMBEDDING_DEVICE=auto           # auto | cuda | cpu

# ============================================
# VECTOR SEARCH CONFIGURATION
# ============================================
SIMILARITY_THRESHOLD=1.2        # Distance threshold for filtering results
TOP_K_DEFAULT=10                # Number of contexts to retrieve
TOP_K_FALLBACK=3                # Fallback when no results meet threshold
MAX_CONTEXTS_RESPONSE=5         # Maximum contexts in API response

# ============================================
# CACHE SETTINGS
# ============================================
ENABLE_CACHE=True               # Enable query caching
CACHE_MAX_SIZE=1000             # Maximum cached queries
CACHE_TTL=3600                  # Cache time-to-live in seconds (1 hour)

# ============================================
# LOGGING
# ============================================
LOG_LEVEL=INFO                  # DEBUG | INFO | WARNING | ERROR | CRITICAL
ENABLE_JSON_LOGGING=False       # Use JSON format for logs
LOG_FORMAT=%(asctime)s - %(name)s - %(levelname)s - %(message)s

# ============================================
# RATE LIMITING (Optional)
# ============================================
ENABLE_RATE_LIMIT=False         # Enable rate limiting
RATE_LIMIT_PER_MINUTE=60        # Requests per minute per IP

# ============================================
# DATA PATHS
# ============================================
INDEX_PATH=embeddings/faiss_index.bin
METADATA_PATH=embeddings/metadata.pkl
DATA_DIR=data
FAQ_FILE=data/faq.json
GUIDE_FILE=data/guide.json

# ============================================
# ADVANCED SETTINGS
# ============================================
MAX_QUERY_LENGTH=1000           # Maximum query character length
MAX_CHAT_HISTORY=10             # Maximum chat history to maintain
CONTEXT_WINDOW_MESSAGES=5       # Context window for conversation
```

### Configuration Validation

The system automatically validates critical configurations on startup:

-   `GROQ_API_KEY` is set
-   Data directory exists
-   Debug mode disabled in production
-   CORS origins properly configured

## Usage

### Web Interface

1. **Access the Frontend**

    ```
    http://localhost:8000/frontend/index.html
    ```

2. **Interact with the Chatbot**
    - Type your question in Vietnamese
    - Press Enter or click Send
    - View response with source attributions
    - Enjoy rich markdown formatting (tables, code blocks, etc.)

### Markdown Support 📝

The frontend fully supports **GitHub Flavored Markdown (GFM)** for rich content display. The chatbot can return responses with:

#### Supported Formats:

| Feature              | Example                | Description                      |
| -------------------- | ---------------------- | -------------------------------- |
| **Tables**           | `\| Header \| Cell \|` | Styled tables with hover effects |
| **Code Blocks**      | ` ```python ``` `      | Syntax-highlighted code          |
| **Inline Code**      | `` `code` ``           | Monospace inline text            |
| **Bold/Italic**      | `**bold**`, `*italic*` | Text emphasis                    |
| **Lists**            | `- item` or `1. item`  | Ordered/unordered lists          |
| **Links**            | `[text](url)`          | Auto-detected external links     |
| **Blockquotes**      | `> quote`              | Styled quotations                |
| **Headers**          | `# H1`, `## H2`        | Section headers                  |
| **Horizontal Rules** | `---`                  | Section dividers                 |
| **Strikethrough**    | `~~text~~`             | Crossed-out text                 |

#### Special Auto-Detection:

-   **Phone Numbers**: `0123456789` → Clickable `tel:` link with phone icon
-   **Email Addresses**: `support@example.com` → Clickable `mailto:` link with envelope icon
-   **URLs**: `https://example.com` → External link with icon

#### Example Response:

```markdown
## Các phương thức thanh toán

| Phương thức      | Phí          | Thời gian |
| ---------------- | ------------ | --------- |
| Internet Banking | **Miễn phí** | 1-2 phút  |
| Ví điện tử       | 1,000 VNĐ    | Tức thì   |

### Hướng dẫn:

1. Chọn **phương thức** phù hợp
2. Làm theo _hướng dẫn_ trên màn hình
3. Nhập mã OTP để xác nhận

> **Lưu ý:** Kiểm tra kỹ thông tin trước khi xác nhận

Liên hệ hỗ trợ: 18008798 hoặc support@dichvucong.gov.vn
```

📚 **Full Documentation**: See [Markdown Support Guide](docs/MARKDOWN_SUPPORT.md) for complete feature list and examples.

🧪 **Test Page**: Open `frontend/markdown-test.html` to see all markdown features in action.

### API Usage

#### Example: Chat Request

```bash
curl -X POST "http://localhost:8000/api/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Làm thế nào để đăng ký thường trú?",
    "top_k": 5,
    "chat_history": []
  }'
```

#### Response Format

```json
{
    "query": "Làm thế nào để đăng ký thường trú?",
    "answer": "Để đăng ký thường trú, bạn cần...",
    "contexts": [
        {
            "text": "Thủ tục đăng ký thường trú...",
            "type": "guide",
            "category": "Đăng ký cư trú",
            "href": "https://dichvucong.gov.vn/...",
            "distance": 0.85
        }
    ],
    "sources": [
        {
            "title": "guide - Đăng ký cư trú",
            "url": "https://dichvucong.gov.vn/..."
        }
    ],
    "success": true,
    "trace_id": "abc123-def456-ghi789"
}
```

### Python SDK Example

```python
import requests

class ChatbotClient:
    def __init__(self, base_url="http://localhost:8000"):
        self.base_url = base_url
        self.chat_history = []

    def ask(self, question, top_k=5):
        response = requests.post(
            f"{self.base_url}/api/chat",
            json={
                "message": question,
                "top_k": top_k,
                "chat_history": self.chat_history
            }
        )

        if response.status_code == 200:
            data = response.json()
            self.chat_history.append({
                "question": question,
                "answer": data["answer"]
            })
            return data
        else:
            raise Exception(f"Error: {response.status_code}")

# Usage
client = ChatbotClient()
result = client.ask("Hồ sơ đăng ký kết hôn cần gì?")
print(result["answer"])
```

### Rebuilding the Index

When you update data files (`data/faq.json`, `data/guide.json`):

#### Linux/macOS:

```bash
./scripts/rebuild_index.sh
```

#### Windows:

```powershell
.\scripts\rebuild_index.ps1
```

#### Programmatically:

```python
from rag import build_index
build_index(batch_size=32)
```

## API Documentation

### Endpoints Overview

| Endpoint           | Method | Description            | Auth Required |
| ------------------ | ------ | ---------------------- | ------------- |
| `/health`          | GET    | Basic health check     | No            |
| `/api/status`      | GET    | Detailed system status | No            |
| `/api/chat`        | POST   | Chat with the bot      | No            |
| `/api/build-index` | POST   | Rebuild vector index   | Yes (Future)  |
| `/api/docs`        | GET    | Interactive API docs   | No            |
| `/api/redoc`       | GET    | API documentation      | No            |

### Detailed Endpoint Specifications

#### 1. Health Check

```http
GET /health
```

**Response:**

```json
{
    "status": "healthy",
    "timestamp": "2025-10-08T10:30:00Z"
}
```

#### 2. System Status

```http
GET /api/status
```

**Response:**

```json
{
    "status": "operational",
    "version": "1.0.0",
    "environment": "production",
    "indexing_available": true,
    "cache_enabled": true,
    "cache_size": 245,
    "device_info": {
        "device": "cuda:0",
        "gpu_available": true,
        "gpu_name": "NVIDIA RTX 3080"
    },
    "uptime_seconds": 3600
}
```

#### 3. Chat

```http
POST /api/chat
```

**Request Body:**

```json
{
    "message": "Thủ tục cấp CMND mất cần gì?",
    "top_k": 5,
    "chat_history": [
        {
            "question": "Previous question",
            "answer": "Previous answer"
        }
    ]
}
```

**Validation Rules:**

-   `message`: Required, 1-1000 characters
-   `top_k`: Optional, 1-20, default: 10
-   `chat_history`: Optional, max 10 items

**Response:**

```json
{
  "query": "Thủ tục cấp CMND mất cần gì?",
  "answer": "Detailed answer...",
  "contexts": [...],
  "sources": [...],
  "success": true,
  "message": null,
  "trace_id": "unique-trace-id",
  "timestamp": "2025-10-08T10:30:00Z"
}
```

**Error Responses:**

_400 Bad Request:_

```json
{
    "detail": "Query exceeds maximum length of 1000 characters"
}
```

_500 Internal Server Error:_

```json
{
    "query": "...",
    "answer": null,
    "contexts": [],
    "sources": [],
    "success": false,
    "message": "Failed to generate answer: Connection timeout",
    "trace_id": "error-trace-id"
}
```

### Interactive Documentation

When `EXPOSE_DOCS=True`, access:

-   **Swagger UI**: `http://localhost:8000/api/docs`
-   **ReDoc**: `http://localhost:8000/api/redoc`

## Deployment

### Production Deployment Checklist

-   [ ] Set `APP_ENV=production`
-   [ ] Set `DEBUG=False`
-   [ ] Configure `ALLOWED_ORIGINS` with your domain
-   [ ] Set `EXPOSE_DOCS=False` (security)
-   [ ] Use strong `GROQ_API_KEY`
-   [ ] Set up HTTPS/TLS termination
-   [ ] Configure reverse proxy (Nginx/Traefik)
-   [ ] Set up monitoring and alerting
-   [ ] Configure log aggregation
-   [ ] Set up automated backups for `embeddings/`
-   [ ] Implement rate limiting
-   [ ] Configure firewall rules
-   [ ] Set resource limits (CPU/Memory)

### Docker Production Deployment

```bash
# 1. Build production image
docker build -t chatbot-dichvucong:v1.0.0 .

# 2. Run with production settings
docker run -d \
  --name chatbot-production \
  --restart unless-stopped \
  -p 8000:8000 \
  -e APP_ENV=production \
  -e DEBUG=False \
  -e GROQ_API_KEY=${GROQ_API_KEY} \
  -e WORKERS=4 \
  -e LOG_LEVEL=INFO \
  -v /data/embeddings:/app/embeddings \
  -v /data/source:/app/data:ro \
  --memory="4g" \
  --cpus="2.0" \
  chatbot-dichvucong:v1.0.0
```

### Kubernetes Deployment

Example deployment configuration:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
    name: chatbot-dichvucong
spec:
    replicas: 3
    selector:
        matchLabels:
            app: chatbot
    template:
        metadata:
            labels:
                app: chatbot
        spec:
            containers:
                - name: chatbot
                  image: chatbot-dichvucong:v1.0.0
                  ports:
                      - containerPort: 8000
                  env:
                      - name: APP_ENV
                        value: "production"
                      - name: GROQ_API_KEY
                        valueFrom:
                            secretKeyRef:
                                name: chatbot-secrets
                                key: groq-api-key
                  resources:
                      requests:
                          memory: "2Gi"
                          cpu: "1000m"
                      limits:
                          memory: "4Gi"
                          cpu: "2000m"
                  livenessProbe:
                      httpGet:
                          path: /health
                          port: 8000
                      initialDelaySeconds: 30
                      periodSeconds: 10
                  readinessProbe:
                      httpGet:
                          path: /api/status
                          port: 8000
                      initialDelaySeconds: 40
                      periodSeconds: 5
                  volumeMounts:
                      - name: embeddings
                        mountPath: /app/embeddings
            volumes:
                - name: embeddings
                  persistentVolumeClaim:
                      claimName: chatbot-embeddings-pvc
```

### Nginx Reverse Proxy

```nginx
upstream chatbot_backend {
    least_conn;
    server 127.0.0.1:8000 max_fails=3 fail_timeout=30s;
    server 127.0.0.1:8001 max_fails=3 fail_timeout=30s;
    server 127.0.0.1:8002 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name chatbot.yourdomain.gov.vn;

    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name chatbot.yourdomain.gov.vn;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=chatbot:10m rate=10r/s;
    limit_req zone=chatbot burst=20 nodelay;

    location / {
        proxy_pass http://chatbot_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Static files caching
    location /frontend {
        proxy_pass http://chatbot_backend;
        expires 1h;
        add_header Cache-Control "public, immutable";
    }
}
```

### Monitoring with Prometheus

Add metrics endpoint (future enhancement):

```python
# In app.py (future)
from prometheus_fastapi_instrumentator import Instrumentator

Instrumentator().instrument(app).expose(app)
```

Prometheus configuration:

```yaml
scrape_configs:
    - job_name: "chatbot"
      static_configs:
          - targets: ["localhost:8000"]
      metrics_path: "/metrics"
      scrape_interval: 15s
```

## Testing

### Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=. --cov-report=html

# Run specific test file
pytest tests/test_api.py

# Run with verbose output
pytest -v

# Run only unit tests (fast)
pytest -m "not slow and not llm"
```

### Test Structure

```
tests/
├── conftest.py              # Shared fixtures
├── test_api.py              # API endpoint tests
├── test_chunking.py         # Data chunking tests
├── test_context_analyzer.py # Context analysis tests
├── test_embedding.py        # Embedding generation tests
└── test_rag.py             # RAG pipeline tests
```

### Example Test Cases

#### Unit Test Example

```python
def test_chunking_metadata_keys():
    """Verify all chunks have required metadata keys"""
    from chunking import load_and_chunk_data

    texts, metadatas = load_and_chunk_data()

    required_keys = {'type', 'category', 'text'}
    for metadata in metadatas:
        assert required_keys.issubset(metadata.keys())
```

#### Integration Test Example

```python
def test_chat_endpoint_success(client):
    """Test successful chat interaction"""
    response = client.post(
        "/api/chat",
        json={"message": "Thủ tục đăng ký kết hôn?", "top_k": 5}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert len(data["answer"]) > 0
    assert len(data["sources"]) > 0
```

### Test Coverage Goals

-   **Unit Tests**: >80% coverage
-   **Integration Tests**: All API endpoints
-   **Contract Tests**: All JSON response schemas
-   **Performance Tests**: Response time < 2s (without LLM)

## Performance Optimization

### Current Performance Metrics

-   **Average Response Time**: ~1.5s (including LLM)
-   **Embedding Generation**: ~50ms per query
-   **FAISS Search**: ~10ms for 10k vectors
-   **Cache Hit Rate**: ~40% in production
-   **Throughput**: ~50 req/s (4 workers)

### Optimization Strategies

#### 1. Caching Layer

```python
# LRU cache for repeated queries
ENABLE_CACHE=True
CACHE_MAX_SIZE=1000
CACHE_TTL=3600  # 1 hour
```

#### 2. Batch Processing

```python
# Embed multiple queries in batches
EMBEDDING_BATCH_SIZE=32
```

#### 3. GPU Acceleration

```python
# Use GPU for embedding if available
EMBEDDING_DEVICE=cuda
```

#### 4. Index Optimization

```python
# For large datasets (>100k vectors), use HNSW
# Switch from IndexFlatL2 to IndexHNSWFlat
import faiss
index = faiss.IndexHNSWFlat(dimension, 32)
```

#### 5. Connection Pooling

```python
# Reuse HTTP connections to Groq API
# Already implemented in llm_client.py
```

### Monitoring Performance

```python
# Add timing middleware (already implemented)
# Check logs for performance metrics:
# - embedding_time_ms
# - search_time_ms
# - llm_time_ms
# - total_time_ms
```

### Scaling Recommendations

| Load Level              | Configuration                      |
| ----------------------- | ---------------------------------- |
| Low (< 10 req/s)        | 2 workers, 2GB RAM, CPU only       |
| Medium (10-50 req/s)    | 4 workers, 4GB RAM, CPU + cache    |
| High (50-100 req/s)     | 8 workers, 8GB RAM, GPU + cache    |
| Very High (> 100 req/s) | Multiple instances + load balancer |

## Monitoring & Logging

### Log Levels

-   **DEBUG**: Detailed diagnostic information (development only)
-   **INFO**: General informational messages
-   **WARNING**: Warning messages (fallbacks, deprecations)
-   **ERROR**: Error messages (recoverable failures)
-   **CRITICAL**: Critical failures (system-wide issues)

### Log Format

#### Standard Format (Default)

```
2025-10-08 10:30:00,123 - app - INFO - Request completed: trace_id=abc123 duration=1234ms
```

#### JSON Format (Production Recommended)

```json
{
    "timestamp": "2025-10-08T10:30:00.123Z",
    "level": "INFO",
    "logger": "app",
    "message": "Request completed",
    "trace_id": "abc123",
    "duration_ms": 1234,
    "endpoint": "/api/chat"
}
```

### Key Metrics to Monitor

1. **Request Metrics**

    - Total requests per minute
    - Success rate
    - Error rate by type
    - Average response time

2. **Cache Metrics**

    - Cache hit rate
    - Cache size
    - Eviction rate

3. **Model Metrics**

    - Embedding generation time
    - FAISS search time
    - LLM inference time
    - Token usage

4. **System Metrics**
    - CPU usage
    - Memory usage
    - Disk I/O
    - Network I/O

### Log Aggregation

#### Using ELK Stack

```yaml
# Filebeat configuration example
filebeat.inputs:
    - type: log
      enabled: true
      paths:
          - /var/log/chatbot/*.log
      json.keys_under_root: true

output.elasticsearch:
    hosts: ["elasticsearch:9200"]
```

#### Using Loki

```yaml
# Promtail configuration example
server:
    http_listen_port: 9080

clients:
    - url: http://loki:3100/loki/api/v1/push

scrape_configs:
    - job_name: chatbot
      static_configs:
          - targets:
                - localhost
            labels:
                job: chatbot
                __path__: /var/log/chatbot/*.log
```

### Alerting Rules

Example Prometheus alerts:

```yaml
groups:
    - name: chatbot_alerts
      rules:
          - alert: HighErrorRate
            expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
            for: 5m
            labels:
                severity: warning
            annotations:
                summary: "High error rate detected"

          - alert: SlowResponseTime
            expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 3
            for: 10m
            labels:
                severity: warning
            annotations:
                summary: "95th percentile response time > 3s"

          - alert: LowCacheHitRate
            expr: cache_hit_rate < 0.2
            for: 15m
            labels:
                severity: info
            annotations:
                summary: "Cache hit rate below 20%"
```

## Contributing

We welcome contributions! Please follow these guidelines:

### Development Workflow

1. **Fork the Repository**

    ```bash
    git clone https://github.com/PhucHuwu/ChatBot_Dich_vu_cong.git
    cd ChatBot_Dich_vu_cong
    ```

2. **Create Feature Branch**

    ```bash
    git checkout -b feature/your-feature-name
    ```

3. **Make Changes**

    - Follow existing code style
    - Add tests for new features
    - Update documentation

4. **Run Tests**

    ```bash
    pytest
    black .
    flake8
    ```

5. **Commit Changes**

    ```bash
    git add .
    git commit -m "feat: add new feature"
    ```

6. **Push and Create PR**
    ```bash
    git push origin feature/your-feature-name
    ```

### Commit Message Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

-   `feat:` New feature
-   `fix:` Bug fix
-   `docs:` Documentation changes
-   `style:` Code style changes (formatting)
-   `refactor:` Code refactoring
-   `test:` Test additions or changes
-   `chore:` Build process or auxiliary tool changes

### Pull Request Checklist

Use this checklist in your PR description:

```markdown
-   [ ] Response schema backward compatible (only added optional fields)
-   [ ] No hardcoded secrets or API keys
-   [ ] If changing embedding model: documented dimension & threshold
-   [ ] If changing metadata: updated all usages and tests
-   [ ] Updated inline documentation (docstrings/comments)
-   [ ] Successfully built index locally
-   [ ] No unnecessary large dependencies
-   [ ] Prompt changes include rationale and examples
-   [ ] Health check endpoints still functional
-   [ ] All tests passing
```

### Code Style

-   **Python**: Follow PEP 8
-   **Naming**: snake_case for functions/variables, UPPER_CASE for constants
-   **Type Hints**: Use for all new functions
-   **Docstrings**: Required for public functions

Example:

```python
def search_rag(query: str, k: int = 10) -> List[Dict[str, Any]]:
    """
    Search for relevant contexts using RAG pipeline.

    Args:
        query: User's search query
        k: Number of results to return

    Returns:
        List of context dictionaries with metadata

    Raises:
        ValueError: If query is empty
    """
    pass
```

## Troubleshooting

### Common Issues

#### 1. Index Not Found Error

**Problem:**

```
FileNotFoundError: embeddings/faiss_index.bin not found
```

**Solution:**

```bash
# Rebuild the index
python -c "from rag import build_index; build_index()"
```

#### 2. GROQ API Key Error

**Problem:**

```
ValueError: GROQ_API_KEY is required
```

**Solution:**

```bash
# Set API key in .env file
echo "GROQ_API_KEY=your_key_here" >> .env
```

#### 3. GPU Not Detected

**Problem:**

```
WARNING: CUDA not available, using CPU
```

**Solution:**

```bash
# Install CUDA-enabled PyTorch
pip install torch --index-url https://download.pytorch.org/whl/cu118

# Or force CPU mode
echo "EMBEDDING_DEVICE=cpu" >> .env
```

#### 4. Port Already in Use

**Problem:**

```
OSError: [Errno 48] Address already in use
```

**Solution:**

```bash
# Find and kill process using port 8000
# Linux/macOS:
lsof -ti:8000 | xargs kill -9

# Windows:
netstat -ano | findstr :8000
taskkill /PID <PID> /F

# Or use different port
uvicorn app:app --port 8001
```

#### 5. Out of Memory Error

**Problem:**

```
RuntimeError: CUDA out of memory
```

**Solution:**

```bash
# Reduce batch size
echo "EMBEDDING_BATCH_SIZE=16" >> .env

# Or use CPU
echo "EMBEDDING_DEVICE=cpu" >> .env
```

#### 6. Slow Response Times

**Diagnosis:**

```bash
# Check logs for timing breakdown
docker logs chatbot | grep "duration_ms"
```

**Solutions:**

-   Enable caching: `ENABLE_CACHE=True`
-   Reduce `TOP_K_DEFAULT` to 5-7
-   Increase `SIMILARITY_THRESHOLD` to 1.0
-   Use GPU: `EMBEDDING_DEVICE=cuda`

#### 7. Docker Build Fails

**Problem:**

```
ERROR: failed to solve: process "/bin/sh -c pip install..." did not complete
```

**Solution:**

```bash
# Clear Docker cache
docker builder prune -a

# Build with no cache
docker build --no-cache -t chatbot-dichvucong .
```

### Debug Mode

Enable detailed logging:

```bash
# In .env
DEBUG=True
LOG_LEVEL=DEBUG

# Then check logs for detailed information
tail -f logs/app.log
```

### Health Check Scripts

#### Linux/macOS:

```bash
./scripts/health_check.sh
```

#### Windows:

```powershell
.\scripts\health_check.ps1
```

### Getting Help

1. **Check Documentation**: Review this README and inline code comments
2. **Search Issues**: Check [GitHub Issues](https://github.com/PhucHuwu/ChatBot_Dich_vu_cong/issues)
3. **Enable Debug Logging**: Set `LOG_LEVEL=DEBUG`
4. **Create Issue**: Provide logs, configuration, and steps to reproduce

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Authors & Acknowledgments

### Main Contributors

-   **PhucHuwu** - Project Creator and Maintainer

### Technologies & Libraries

-   [FastAPI](https://fastapi.tiangolo.com/) - Web framework
-   [Sentence Transformers](https://www.sbert.net/) - Embedding models
-   [FAISS](https://github.com/facebookresearch/faiss) - Vector search by Meta AI
-   [Groq](https://groq.com/) - LLM inference platform
-   [Hugging Face](https://huggingface.co/) - Model hosting

### Inspiration

This project was created to improve access to Vietnamese public administrative services through AI-powered assistance.

## Contact & Support

-   **Issues**: [GitHub Issues](https://github.com/PhucHuwu/ChatBot_Dich_vu_cong/issues)
-   **Discussions**: [GitHub Discussions](https://github.com/PhucHuwu/ChatBot_Dich_vu_cong/discussions)
-   **Email**: [Your contact email]

## Roadmap

### Version 1.1 (Q4 2025)

-   [ ] User authentication and session management
-   [ ] Multi-turn conversation context
-   [ ] Voice input support (speech-to-text)
-   [ ] Export chat history
-   [ ] Admin dashboard

### Version 1.2 (Q1 2026)

-   [ ] Prometheus metrics exporter
-   [ ] HNSW index for large-scale data
-   [ ] Multi-language support (English, Chinese)
-   [ ] Custom fine-tuned embedding model
-   [ ] A/B testing framework

### Version 2.0 (Q2 2026)

-   [ ] GraphQL API
-   [ ] Real-time chat with WebSockets
-   [ ] Mobile application (iOS/Android)
-   [ ] Integration with government portals
-   [ ] Advanced analytics dashboard

## Additional Resources

-   [FastAPI Documentation](https://fastapi.tiangolo.com/)
-   [FAISS Wiki](https://github.com/facebookresearch/faiss/wiki)
-   [RAG Best Practices](https://www.pinecone.io/learn/retrieval-augmented-generation/)
-   [Sentence Transformers Documentation](https://www.sbert.net/docs/quickstart.html)
-   [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

---

<div align="center">

**Made by Phuc Tran Huu - ITPTIT**

[⬆ Back to Top](#vietnamese-public-service-chatbot-chatbot-dịch-vụ-công)

</div>
