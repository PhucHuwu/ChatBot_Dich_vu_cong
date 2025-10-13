import torch
from sentence_transformers import SentenceTransformer
from sklearn.preprocessing import normalize
import logging
from config import settings

logger = logging.getLogger(__name__)

if settings.EMBEDDING_DEVICE == "auto":
    device = "cuda" if torch.cuda.is_available() else "cpu"
elif settings.EMBEDDING_DEVICE == "cuda" and torch.cuda.is_available():
    device = "cuda"
else:
    device = "cpu"

logger.info(f"Sử dụng device: {device} (config: {settings.EMBEDDING_DEVICE})")

try:
    model = SentenceTransformer(settings.EMBEDDING_MODEL)
    if device == "cuda":
        model = model.to(device)
        logger.info(f"Model {settings.EMBEDDING_MODEL} đã được load lên GPU")
    else:
        logger.info(f"Model {settings.EMBEDDING_MODEL} đang chạy trên CPU")
except Exception as e:
    logger.error(f"Lỗi khi load model: {e}")
    raise


def embedding(texts, batch_size=None):
    if batch_size is None:
        batch_size = settings.EMBEDDING_BATCH_SIZE

    try:
        if not texts:
            logger.warning("Empty texts list provided to embedding function")
            return None

        logger.debug(f"Creating embeddings for {len(texts)} texts with batch_size={batch_size}")

        embeddings = model.encode(
            texts,
            batch_size=batch_size,
            show_progress_bar=True,
            convert_to_tensor=True,
            device=device
        )

        if isinstance(embeddings, torch.Tensor):
            embeddings = embeddings.cpu().numpy()

        normalized = normalize(embeddings)
        logger.debug(f"Embeddings created successfully, shape: {normalized.shape}")

        return normalized

    except Exception as e:
        logger.error(f"Lỗi trong quá trình embedding: {e}")
        if device == "cuda":
            logger.warning("GPU embedding failed, fallback to CPU...")
            try:
                model_cpu = SentenceTransformer(settings.EMBEDDING_MODEL)
                embeddings = model_cpu.encode(texts, batch_size=batch_size, show_progress_bar=True)
                return normalize(embeddings)
            except Exception as cpu_error:
                logger.error(f"CPU fallback also failed: {cpu_error}")
                raise
        else:
            raise


def get_embedding_model():
    return model


def get_device_info():
    if torch.cuda.is_available():
        return {
            "device": "cuda",
            "gpu_name": torch.cuda.get_device_name(0),
            "gpu_memory": f"{torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB",
            "current_device": device,
            "model": settings.EMBEDDING_MODEL
        }
    else:
        return {
            "device": "cpu",
            "current_device": device,
            "model": settings.EMBEDDING_MODEL
        }
