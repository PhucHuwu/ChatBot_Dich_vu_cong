from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
import uvicorn
from typing import Optional
import logging
import os

from rag import get_answer, build_index
from embedding import get_device_info

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Cổng Dịch vụ công Quốc gia - Chatbot API",
    description="API hỗ trợ chatbot cho dịch vụ công quốc gia",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:5500", "http://localhost:5500"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/frontend", StaticFiles(directory="frontend"), name="frontend")


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    query: str
    chat_history: Optional[list[ChatMessage]] = []


class ChatResponse(BaseModel):
    query: str
    answer: str
    contexts: Optional[list] = None
    sources: Optional[list] = None
    success: bool = True
    message: Optional[str] = None


class SystemStatusResponse(BaseModel):
    status: str
    device_info: str
    indexing_available: bool
    message: str


index_built = False


@app.get("/")
async def root():
    try:
        return FileResponse("frontend/index.html")
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Frontend files not found")


@app.get("/health")
async def health_check():
    return {"status": "healthy", "message": "Cổng Dịch vụ công Quốc gia API đang hoạt động"}


@app.get("/api/status", response_model=SystemStatusResponse)
async def get_system_status():
    try:
        device_info = get_device_info()

        index_files_exist = (
            os.path.exists("embeddings/faiss_index.bin") and
            os.path.exists("embeddings/metadata.pkl")
        )

        return SystemStatusResponse(
            status="active",
            device_info=device_info,
            indexing_available=index_files_exist,
            message="Hệ thống chatbot hoạt động bình thường"
        )
    except Exception as e:
        logger.error(f"Error getting system status: {str(e)}")
        return SystemStatusResponse(
            status="error",
            device_info="Unknown",
            indexing_available=False,
            message=f"Lỗi hệ thống: {str(e)}"
        )


@app.post("/api/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    global index_built

    try:
        if not request.query or request.query.strip() == "":
            raise HTTPException(status_code=400, detail="Câu hỏi không được để trống")

        logger.info(f"Received query: {request.query}")
        logger.info(f"Chat history length: {len(request.chat_history)}")

        if not index_built:
            if not (os.path.exists("embeddings/faiss_index.bin") and os.path.exists("embeddings/metadata.pkl")):
                logger.info("Building index for first time...")
                build_index(batch_size=32)
            index_built = True

        result = get_answer(
            query=request.query.strip(),
            chat_history=request.chat_history,
            k=10,
            temperature=0.7,
            max_tokens=2048
        )

        if not result or not result.get("answer"):
            return ChatResponse(
                query=request.query,
                answer="Xin lỗi, tôi không thể tìm thấy thông tin phù hợp để trả lời câu hỏi của bạn. Vui lòng thử lại với câu hỏi khác hoặc liên hệ với bộ phận hỗ trợ.",
                success=False,
                message="Không tìm thấy câu trả lời"
            )

        sources = []
        contexts = result.get("contexts", [])

        for i, ctx in enumerate(contexts[:3]):
            sources.append({
                "source": f"Nguồn {i+1}",
                "type": ctx.get("type", "unknown"),
                "title": ctx.get("title", "Không có tiêu đề")
            })

        logger.info(f"Successfully answered query: {request.query}")

        return ChatResponse(
            query=request.query,
            answer=result["answer"],
            contexts=contexts,
            sources=sources,
            success=True,
            message="Trả lời thành công"
        )

    except Exception as e:
        logger.error(f"Error processing chat request: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Lỗi xử lý yêu cầu: {str(e)}"
        )


@app.post("/api/build")
async def build_index_endpoint():
    try:
        logger.info("Manual index rebuilding triggered...")
        device_info = get_device_info()
        logger.info(f"Building index on device: {device_info}")

        build_index(batch_size=32)

        return {
            "success": True,
            "message": "Tái tạo index thành công",
            "device": device_info
        }

    except Exception as e:
        logger.error(f"Error building index: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Lỗi tái tạo index: {str(e)}"
        )


@app.get("/api/suggestions")
async def get_suggestions():
    suggestions = [
        "Hướng dẫn đăng ký tài khoản công dân",
        "Cách thành toán tiền điện trực tuyến",
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


@app.post("/api/debug/chat-history")
async def debug_chat_history(request: ChatRequest):
    return {
        "query": request.query,
        "chat_history": request.chat_history,
        "history_length": len(request.chat_history),
        "message": "Debug chat history"
    }


@app.exception_handler(404)
async def not_found_handler(request, exc):
    return {"error": "Không tìm thấy endpoint", "detail": str(exc)}


@app.exception_handler(500)
async def internal_error_handler(request, exc):
    return {"error": "Lỗi máy chủ nội bộ", "detail": "Liên hệ bộ phận hỗ trợ kỹ thuật"}


@app.exception_handler(422)
async def validation_error_handler(request, exc):
    return {"error": "Dữ liệu đầu vào không hợp lệ", "detail": "Vui lòng kiểm tra lại thông tin"}

if __name__ == "__main__":
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
