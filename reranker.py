import torch
from sentence_transformers import CrossEncoder
import logging
from typing import List, Dict, Tuple
from config import settings

logger = logging.getLogger(__name__)

reranker_model = None


def get_reranker_model() -> CrossEncoder:
    global reranker_model

    if reranker_model is None:
        try:
            logger.info(f"Loading re-ranking model: {settings.RERANKING_MODEL}")

            device = "cuda" if torch.cuda.is_available() and settings.EMBEDDING_DEVICE != "cpu" else "cpu"

            reranker_model = CrossEncoder(settings.RERANKING_MODEL, device=device)

            logger.info(f"Re-ranking model loaded successfully on device: {device}")
        except Exception as e:
            logger.error(f"Failed to load re-ranking model: {e}")
            raise

    return reranker_model


def rerank_documents(
    query: str,
    documents: List[Dict],
    top_k: int = None
) -> List[Dict]:
    if not settings.ENABLE_RERANKING:
        logger.debug("Re-ranking is disabled, returning original documents")
        return documents[:top_k] if top_k else documents

    if not documents:
        logger.warning("No documents to rerank")
        return []

    if top_k is None:
        top_k = settings.RERANKING_TOP_K

    try:
        model = get_reranker_model()

        query_doc_pairs = [(query, doc["text"]) for doc in documents]

        logger.debug(f"Re-ranking {len(documents)} documents for query: '{query[:50]}...'")

        scores = model.predict(query_doc_pairs)

        doc_score_pairs = list(zip(documents, scores))
        doc_score_pairs.sort(key=lambda x: x[1], reverse=True)

        reranked_docs = []
        for doc, score in doc_score_pairs[:top_k]:
            doc_with_score = doc.copy()
            doc_with_score["rerank_score"] = float(score)
            reranked_docs.append(doc_with_score)

        logger.info(f"Re-ranked {len(documents)} documents, returning top {len(reranked_docs)}")
        logger.debug(f"Top score: {reranked_docs[0]['rerank_score']:.4f}, " +
                     f"Lowest score: {reranked_docs[-1]['rerank_score']:.4f}")

        return reranked_docs

    except Exception as e:
        logger.error(f"Re-ranking failed: {e}, returning original documents")
        return documents[:top_k]


def get_reranker_info() -> Dict:
    if not settings.ENABLE_RERANKING:
        return {
            "enabled": False,
            "model": None
        }

    device = "cuda" if torch.cuda.is_available() and settings.EMBEDDING_DEVICE != "cpu" else "cpu"

    return {
        "enabled": True,
        "model": settings.RERANKING_MODEL,
        "device": device,
        "top_k": settings.RERANKING_TOP_K,
        "initial_retrieval_multiplier": settings.INITIAL_RETRIEVAL_MULTIPLIER
    }
