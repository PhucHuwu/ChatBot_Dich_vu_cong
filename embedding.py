import torch
from sentence_transformers import SentenceTransformer
from sklearn.preprocessing import normalize
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

device = "cuda" if torch.cuda.is_available() else "cpu"
logger.info(f"Sử dụng device: {device}")

try:
    model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")
    if device == "cuda":
        model = model.to(device)
        logger.info("Model đã được load lên GPU")
    else:
        logger.warning("GPU không khả dụng, sử dụng CPU")
except Exception as e:
    logger.error(f"Lỗi khi load model: {e}")
    raise


def embedding(texts, batch_size=32):
    try:
        if not texts:
            return None

        embeddings = model.encode(
            texts,
            batch_size=batch_size,
            show_progress_bar=True,
            convert_to_tensor=True,
            device=device
        )

        if isinstance(embeddings, torch.Tensor):
            embeddings = embeddings.cpu().numpy()

        return normalize(embeddings)

    except Exception as e:
        logger.error(f"Lỗi trong quá trình embedding: {e}")
        if device == "cuda":
            logger.info("Thử lại với CPU...")
            model_cpu = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")
            embeddings = model_cpu.encode(texts, show_progress_bar=True)
            return normalize(embeddings)
        else:
            raise


def get_device_info():
    if torch.cuda.is_available():
        return {
            "device": "cuda",
            "gpu_name": torch.cuda.get_device_name(0),
            "gpu_memory": f"{torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB"
        }
    else:
        return {"device": "cpu"}
