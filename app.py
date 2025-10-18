from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse, StreamingResponse
from pydantic import BaseModel, Field, validator
import uvicorn
from typing import Optional, List
import logging
import os
import time
import json

from rag import get_answer_stream, build_index
from embedding import get_device_info
from reranker import get_reranker_info
from hybrid_search import get_hybrid_search_info
from config import settings
from logger_utils import setup_logging, LoggingMiddleware, get_trace_id
from cache import get_cache

setup_logging()
logger = logging.getLogger(__name__)

try:
    settings.validate()
    logger.info(f"Application starting in {settings.APP_ENV} mode")
except ValueError as e:
    logger.error(f"Configuration validation failed: {e}")
    raise

cache = get_cache()

app = FastAPI(
    title=settings.API_TITLE,
    description="API hỗ trợ Chatbot Dịch vụ công",
    version=settings.API_VERSION,
    docs_url="/api/docs" if settings.EXPOSE_DOCS else None,
    redoc_url="/api/redoc" if settings.EXPOSE_DOCS else None,
    debug=settings.DEBUG,
    root_path=settings.BASE_PATH
)

app.add_middleware(LoggingMiddleware)
app.add_middleware(
    CORSMiddleware,
    **settings.get_cors_config()
)

try:
    app.mount("/frontend", StaticFiles(directory="frontend"), name="frontend")
except RuntimeError as e:
    logger.warning(f"Could not mount frontend directory: {e}")


class ChatMessage(BaseModel):
    role: str = Field(..., description="Role: user hoặc assistant")
    content: str = Field(..., description="Nội dung tin nhắn")

    @validator('role')
    def validate_role(cls, v):
        if v not in ['user', 'assistant', 'system']:
            raise ValueError('Role phải là user, assistant hoặc system')
        return v


class ChatRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=settings.MAX_QUERY_LENGTH,
                       description="Câu hỏi của người dùng")
    chat_history: Optional[List[ChatMessage]] = Field(default=[], description="Lịch sử chat")
    conversation_id: Optional[str] = Field(default=None, description="ID của cuộc hội thoại (conversation)")

    @validator('query')
    def validate_query(cls, v):
        if not v or not v.strip():
            raise ValueError('Câu hỏi không được để trống')
        return v.strip()


class SystemStatusResponse(BaseModel):
    status: str
    device_info: dict
    reranker_info: Optional[dict] = None
    hybrid_search_info: Optional[dict] = None
    indexing_available: bool
    cache_stats: Optional[dict] = None
    message: str
    environment: str


class BuildIndexRequest(BaseModel):
    batch_size: Optional[int] = Field(default=None, gt=0, le=128,
                                      description="Batch size cho embedding")


def check_indexes_exist() -> bool:
    faiss_exists = os.path.exists(settings.INDEX_PATH) and os.path.exists(settings.METADATA_PATH)
    
    if not faiss_exists:
        return False
    
    if settings.ENABLE_HYBRID_SEARCH:
        bm25_exists = os.path.exists(settings.BM25_INDEX_PATH)
        if not bm25_exists:
            return False
    
    return True


@app.on_event("startup")
async def startup_event():
    logger.info("=" * 60)
    logger.info(f"Starting ChatBot Dịch vụ công - Environment: {settings.APP_ENV}")
    logger.info(f"LLM Model: {settings.LLM_MODEL}")
    logger.info(f"Embedding Model: {settings.EMBEDDING_MODEL}")
    logger.info(f"Cache enabled: {settings.ENABLE_CACHE}")
    logger.info(f"CORS origins: {settings.get_allowed_origins()}")
    logger.info("=" * 60)

    if check_indexes_exist():
        logger.info("Indexes found, ready to serve")
    else:
        logger.warning("Indexes not found, will build automatically on first request")


@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Shutting down ChatBot Dịch vụ công")

    if settings.ENABLE_CACHE:
        stats = cache.get_stats()
        logger.info(f"Final cache stats: {stats}")


@app.get("/")
async def root():
    try:
        return FileResponse("frontend/index.html")
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Frontend files not found")


@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "message": "Chatbot Dịch vụ công API đang hoạt động",
        "environment": settings.APP_ENV,
        "timestamp": time.time()
    }


@app.get("/api/status", response_model=SystemStatusResponse)
async def get_system_status(request: Request):
    trace_id = get_trace_id(request)

    try:
        device_info = get_device_info()

        index_files_exist = check_indexes_exist()

        cache_stats = None
        if settings.ENABLE_CACHE:
            cache_stats = cache.get_stats()

        reranker_info = get_reranker_info()
        hybrid_search_info = get_hybrid_search_info()

        return SystemStatusResponse(
            status="active",
            device_info=device_info,
            reranker_info=reranker_info,
            hybrid_search_info=hybrid_search_info,
            indexing_available=index_files_exist,
            cache_stats=cache_stats,
            message="Hệ thống chatbot hoạt động bình thường",
            environment=settings.APP_ENV
        )
    except Exception as e:
        logger.error(f"Error getting system status: {str(e)}", extra={"trace_id": trace_id})
        return SystemStatusResponse(
            status="error",
            device_info={"device": "unknown"},
            indexing_available=False,
            message=f"Lỗi hệ thống: {str(e) if settings.DEBUG else 'Internal error'}",
            environment=settings.APP_ENV
        )


@app.post("/api/chat/stream")
async def chat_stream(request: ChatRequest, req: Request):

    trace_id = get_trace_id(req)
    
    try:
        query = request.query.strip()
        conversation_id = request.conversation_id or "unknown"
        logger.info(
            f"Streaming chat request: '{query[:100]}...' "
            f"(conversation: {conversation_id}, history: {len(request.chat_history)} msgs)",
            extra={"trace_id": trace_id, "conversation_id": conversation_id}
        )

        if not check_indexes_exist():
            logger.info("Index not found, building index for the first time...", extra={"trace_id": trace_id})
            build_index()
            logger.info("Index built successfully", extra={"trace_id": trace_id})

        async def event_generator():
            try:
                for chunk in get_answer_stream(
                    query=query,
                    chat_history=[msg.dict() for msg in request.chat_history],
                    k=settings.TOP_K_DEFAULT,
                    temperature=settings.LLM_TEMPERATURE,
                    max_tokens=settings.LLM_MAX_TOKENS
                ):
                    chunk["trace_id"] = trace_id
                    chunk["success"] = True
                    
                    yield f"data: {json.dumps(chunk, ensure_ascii=False)}\n\n"
                
            except Exception as e:
                logger.error(f"Error in streaming generation: {str(e)}",
                           exc_info=True, extra={"trace_id": trace_id})
                error_chunk = {
                    "type": "error",
                    "error": str(e) if settings.DEBUG else "Lỗi xử lý yêu cầu",
                    "trace_id": trace_id,
                    "success": False
                }
                yield f"data: {json.dumps(error_chunk, ensure_ascii=False)}\n\n"

        return StreamingResponse(
            event_generator(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no"
            }
        )

    except Exception as e:
        logger.error(f"Error processing streaming chat request: {str(e)}",
                     exc_info=True, extra={"trace_id": trace_id})
        raise HTTPException(
            status_code=500,
            detail=str(e) if settings.DEBUG else "Lỗi xử lý yêu cầu"
        )





@app.post("/api/build")
async def build_index_endpoint(request: Request, build_request: BuildIndexRequest = BuildIndexRequest()):
    trace_id = get_trace_id(request)

    try:
        logger.info("Manual index rebuild triggered", extra={"trace_id": trace_id})
        device_info = get_device_info()
        logger.info(f"Building index on device: {device_info}", extra={"trace_id": trace_id})

        batch_size = build_request.batch_size or settings.EMBEDDING_BATCH_SIZE
        build_index(batch_size=batch_size)

        if settings.ENABLE_CACHE:
            cache.clear()
            logger.info("Cache cleared after index rebuild", extra={"trace_id": trace_id})

        return {
            "success": True,
            "message": "Tái tạo index thành công",
            "device": device_info,
            "batch_size": batch_size,
            "trace_id": trace_id
        }

    except Exception as e:
        logger.error(f"Error building index: {str(e)}", exc_info=True,
                     extra={"trace_id": trace_id})
        raise HTTPException(
            status_code=500,
            detail=f"Lỗi tái tạo index: {str(e) if settings.DEBUG else 'Internal error'}"
        )


@app.get("/api/cache/stats")
async def get_cache_stats(request: Request):
    if not settings.ENABLE_CACHE:
        return {"enabled": False, "message": "Cache is disabled"}

    return cache.get_stats()


@app.post("/api/cache/clear")
async def clear_cache(request: Request):
    trace_id = get_trace_id(request)

    if not settings.ENABLE_CACHE:
        return {"enabled": False, "message": "Cache is disabled"}

    cache.clear()
    logger.info("Cache cleared manually", extra={"trace_id": trace_id})

    return {
        "success": True,
        "message": "Cache đã được xóa",
        "trace_id": trace_id
    }


@app.get("/api/suggestions")
async def get_suggestions():
    suggestions = [
        "Hướng dẫn đăng ký tài khoản công dân",
        "Cách thanh toán tiền điện trực tuyến",
        "Tôi muốn tra cứu thủ tục hành chính",
        "Hướng dẫn sử dụng tiện ích giáo dục",
        "Cách đăng ký dịch vụ công trực tuyến",
        "Tôi cần hỗ trợ đăng nhập vào hệ thống",
        "Quy trình nộp hồ sơ trực tuyến",
        "Cách tra cứu tình trạng hồ sơ",
        "Hướng dẫn sử dụng chữ ký số",
        "Thông tin về các dịch vụ công"
    ]

    return {
        "suggestions": suggestions,
        "message": "Danh sách gợi ý câu hỏi"
    }


@app.exception_handler(404)
async def not_found_handler(request: Request, exc):
    return JSONResponse(
        status_code=404,
        content={
            "error": "Không tìm thấy endpoint",
            "detail": str(exc) if settings.DEBUG else "Not found",
            "path": str(request.url.path)
        }
    )


@app.exception_handler(500)
async def internal_error_handler(request: Request, exc):
    trace_id = get_trace_id(request)
    logger.error(f"Internal server error: {exc}", exc_info=True,
                 extra={"trace_id": trace_id})

    return JSONResponse(
        status_code=500,
        content={
            "error": "Lỗi máy chủ nội bộ",
            "detail": str(exc) if settings.DEBUG else "Liên hệ bộ phận hỗ trợ kỹ thuật",
            "trace_id": trace_id
        }
    )


@app.exception_handler(422)
async def validation_error_handler(request: Request, exc):
    return JSONResponse(
        status_code=422,
        content={
            "error": "Dữ liệu đầu vào không hợp lệ",
            "detail": str(exc) if settings.DEBUG else "Vui lòng kiểm tra lại thông tin"
        }
    )


if __name__ == "__main__":
    uvicorn.run(
        "app:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level=settings.LOG_LEVEL.lower()
    )
