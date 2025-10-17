import os
from typing import Optional
from dotenv import load_dotenv

load_dotenv()


class Settings:
    APP_ENV: str = os.getenv("APP_ENV", "development")
    DEBUG: bool = os.getenv("DEBUG", "False").lower() == "true"

    API_TITLE: str = "Cổng Dịch vụ công Quốc gia - Chatbot API"
    API_VERSION: str = "1.0.0"
    API_PREFIX: str = "/api"

    BASE_PATH: str = os.getenv("BASE_PATH", "").rstrip("/")

    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))
    WORKERS: int = int(os.getenv("WORKERS", "4"))

    @staticmethod
    def get_allowed_origins():
        env = os.getenv("APP_ENV", "development")

        if env == "production":
            custom_origins = os.getenv("ALLOWED_ORIGINS", "")
            if custom_origins:
                return [origin.strip() for origin in custom_origins.split(",")]
            return [
                "https://yourdomain.gov.vn",
                "https://chatbot-dichvucong.vercel.app"
            ]
        elif env == "staging":
            return [
                "https://staging.yourdomain.gov.vn",
                "https://chatbot-dichvucong.vercel.app",
                "http://localhost:3000"
            ]
        else:
            return [
                "http://localhost:3000",
                "http://127.0.0.1:5500",
                "http://localhost:5500",
                "http://localhost:8000",
                "https://chatbot-dichvucong.vercel.app"
            ]

    GROQ_API_KEY: Optional[str] = os.getenv("GROQ_API_KEY")
    LLM_MODEL: str = os.getenv("LLM_MODEL", "openai/gpt-oss-120b")
    LLM_TEMPERATURE: float = float(os.getenv("LLM_TEMPERATURE", "1"))
    LLM_MAX_TOKENS: int = int(os.getenv("LLM_MAX_TOKENS", "8192"))
    LLM_TIMEOUT: int = int(os.getenv("LLM_TIMEOUT", "60"))
    LLM_REASONING_EFFORT: str = os.getenv("LLM_REASONING_EFFORT", "medium")
    LLM_STREAM: bool = os.getenv("LLM_STREAM", "True").lower() == "true"

    EMBEDDING_MODEL: str = os.getenv(
        "EMBEDDING_MODEL",
        "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
    )
    EMBEDDING_BATCH_SIZE: int = int(os.getenv("EMBEDDING_BATCH_SIZE", "32"))
    EMBEDDING_DEVICE: str = os.getenv("EMBEDDING_DEVICE", "auto")

    ENABLE_RERANKING: bool = os.getenv("ENABLE_RERANKING", "True").lower() == "true"
    RERANKING_MODEL: str = os.getenv(
        "RERANKING_MODEL",
        "cross-encoder/ms-marco-MiniLM-L-6-v2"
    )
    RERANKING_TOP_K: int = int(os.getenv("RERANKING_TOP_K", "5"))
    INITIAL_RETRIEVAL_MULTIPLIER: int = int(os.getenv("INITIAL_RETRIEVAL_MULTIPLIER", "3"))

    ENABLE_HYBRID_SEARCH: bool = os.getenv("ENABLE_HYBRID_SEARCH", "True").lower() == "true"
    HYBRID_FUSION_METHOD: str = os.getenv("HYBRID_FUSION_METHOD", "rrf")
    BM25_WEIGHT: float = float(os.getenv("BM25_WEIGHT", "0.5"))
    VECTOR_WEIGHT: float = float(os.getenv("VECTOR_WEIGHT", "0.5"))
    BM25_RETRIEVAL_MULTIPLIER: int = int(os.getenv("BM25_RETRIEVAL_MULTIPLIER", "2"))
    BM25_INDEX_PATH: str = os.getenv("BM25_INDEX_PATH", "embeddings/bm25_index.pkl")

    INDEX_PATH: str = os.getenv("INDEX_PATH", "embeddings/faiss_index.bin")
    METADATA_PATH: str = os.getenv("METADATA_PATH", "embeddings/metadata.pkl")
    EMBEDDINGS_DIR: str = "embeddings"

    SIMILARITY_THRESHOLD: float = float(os.getenv("SIMILARITY_THRESHOLD", "1.2"))

    TOP_K_DEFAULT: int = int(os.getenv("TOP_K_DEFAULT", "10"))
    TOP_K_FALLBACK: int = int(os.getenv("TOP_K_FALLBACK", "3"))

    MAX_CONTEXTS_RESPONSE: int = int(os.getenv("MAX_CONTEXTS_RESPONSE", "5"))

    DATA_DIR: str = "data"
    FAQ_FILE: str = os.path.join(DATA_DIR, "faq.json")
    GUIDE_FILE: str = os.path.join(DATA_DIR, "guide.json")

    ENABLE_CACHE: bool = os.getenv("ENABLE_CACHE", "True").lower() == "true"
    CACHE_MAX_SIZE: int = int(os.getenv("CACHE_MAX_SIZE", "1000"))
    CACHE_TTL: int = int(os.getenv("CACHE_TTL", "3600"))

    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO").upper()
    LOG_FORMAT: str = os.getenv(
        "LOG_FORMAT",
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    )
    ENABLE_JSON_LOGGING: bool = os.getenv("ENABLE_JSON_LOGGING", "False").lower() == "true"

    ENABLE_RATE_LIMIT: bool = os.getenv("ENABLE_RATE_LIMIT", "False").lower() == "true"
    RATE_LIMIT_PER_MINUTE: int = int(os.getenv("RATE_LIMIT_PER_MINUTE", "60"))

    MAX_CHAT_HISTORY: int = int(os.getenv("MAX_CHAT_HISTORY", "10"))
    CONTEXT_WINDOW_MESSAGES: int = int(os.getenv("CONTEXT_WINDOW_MESSAGES", "5"))

    EXPOSE_DOCS: bool = os.getenv("EXPOSE_DOCS", "True").lower() == "true"
    MAX_QUERY_LENGTH: int = int(os.getenv("MAX_QUERY_LENGTH", "1000"))

    @classmethod
    def validate(cls):
        errors = []

        if not cls.GROQ_API_KEY:
            errors.append("GROQ_API_KEY is required. Please set it in .env file")

        if not os.path.exists(cls.DATA_DIR):
            errors.append(f"Data directory not found: {cls.DATA_DIR}")

        if cls.APP_ENV == "production" and cls.DEBUG:
            errors.append("DEBUG should be False in production environment")

        if errors:
            error_msg = "\n".join(f"  - {error}" for error in errors)
            raise ValueError(f"Configuration validation failed:\n{error_msg}")

        return True

    @classmethod
    def get_cors_config(cls):
        return {
            "allow_origins": cls.get_allowed_origins(),
            "allow_credentials": True,
            "allow_methods": ["*"],
            "allow_headers": ["*"],
        }

    @classmethod
    def is_production(cls) -> bool:
        return cls.APP_ENV == "production"

    @classmethod
    def is_development(cls) -> bool:
        return cls.APP_ENV == "development"


settings = Settings()


def get_settings() -> Settings:
    return settings
