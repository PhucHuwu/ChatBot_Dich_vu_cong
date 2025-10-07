import logging
import sys
import json
import time
import uuid
from datetime import datetime
from typing import Callable
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from config import settings


class JSONFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        log_data = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        if hasattr(record, "trace_id"):
            log_data["trace_id"] = record.trace_id

        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)

        if hasattr(record, "extra_data"):
            log_data.update(record.extra_data)

        return json.dumps(log_data, ensure_ascii=False)


def setup_logging():
    if settings.ENABLE_JSON_LOGGING:
        formatter = JSONFormatter()
    else:
        formatter = logging.Formatter(settings.LOG_FORMAT)

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)

    root_logger = logging.getLogger()
    root_logger.setLevel(settings.LOG_LEVEL)
    root_logger.handlers.clear()
    root_logger.addHandler(handler)

    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)

    return root_logger


class LoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        trace_id = str(uuid.uuid4())
        request.state.trace_id = trace_id

        logger = logging.getLogger(__name__)

        start_time = time.time()

        logger.info(
            f"Request started: {request.method} {request.url.path}",
            extra={"trace_id": trace_id}
        )

        try:
            response = await call_next(request)

            process_time = time.time() - start_time

            response.headers["X-Trace-ID"] = trace_id
            response.headers["X-Process-Time"] = f"{process_time:.3f}"

            logger.info(
                f"Request completed: {request.method} {request.url.path} "
                f"status={response.status_code} time={process_time:.3f}s",
                extra={"trace_id": trace_id, "extra_data": {
                    "method": request.method,
                    "path": request.url.path,
                    "status_code": response.status_code,
                    "process_time": process_time
                }}
            )

            return response

        except Exception as e:
            process_time = time.time() - start_time

            logger.error(
                f"Request failed: {request.method} {request.url.path} "
                f"error={str(e)} time={process_time:.3f}s",
                exc_info=True,
                extra={"trace_id": trace_id}
            )

            raise


class LogContext:
    def __init__(self, trace_id: str):
        self.trace_id = trace_id
        self.old_factory = None

    def __enter__(self):
        old_factory = logging.getLogRecordFactory()

        def record_factory(*args, **kwargs):
            record = old_factory(*args, **kwargs)
            record.trace_id = self.trace_id
            return record

        self.old_factory = old_factory
        logging.setLogRecordFactory(record_factory)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.old_factory:
            logging.setLogRecordFactory(self.old_factory)


def get_trace_id(request: Request) -> str:
    return getattr(request.state, "trace_id", "no-trace-id")


def log_with_trace(logger: logging.Logger, level: str, message: str, request: Request = None, **kwargs):
    extra = kwargs.get("extra", {})

    if request and hasattr(request.state, "trace_id"):
        extra["trace_id"] = request.state.trace_id

    kwargs["extra"] = extra

    log_method = getattr(logger, level.lower())
    log_method(message, **kwargs)


def sanitize_log_message(message: str, max_length: int = 200) -> str:
    if len(message) > max_length:
        return message[:max_length] + "... (truncated)"
    return message
