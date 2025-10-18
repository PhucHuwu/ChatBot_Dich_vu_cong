import os
import json
import logging
from typing import List, Dict, Optional
from dotenv import load_dotenv
import faiss
import pickle

from chunking import chunk_faq, chunk_guide
from embedding import embedding, get_device_info
from llm_client import get_llm_client
from reranker import rerank_documents
from hybrid_search import build_bm25_index, save_bm25_index, hybrid_search
from config import settings

load_dotenv()

logger = logging.getLogger(__name__)


def build_index(batch_size: Optional[int] = None) -> None:
    if batch_size is None:
        batch_size = settings.EMBEDDING_BATCH_SIZE

    device_info = get_device_info()
    logger.info(f"Building index on device: {device_info}")

    os.makedirs(settings.EMBEDDINGS_DIR, exist_ok=True)

    logger.info("Loading data files...")
    with open(settings.FAQ_FILE, encoding="utf-8") as f:
        faq = json.load(f)
    with open(settings.GUIDE_FILE, encoding="utf-8") as f:
        guide = json.load(f)

    logger.info("Chunking documents...")
    docs = chunk_faq(faq) + chunk_guide(guide)
    texts = [d["text"] for d in docs]
    metadatas = [{"text": d["text"], **d["metadata"]} for d in docs]

    logger.info(f"Creating embeddings for {len(texts)} documents with batch_size={batch_size}...")
    embeddings = embedding(texts, batch_size=batch_size)

    if embeddings is None:
        raise ValueError("Failed to create embeddings")

    logger.info(f"Creating FAISS index with dimension {embeddings.shape[1]}")
    index = faiss.IndexFlatL2(embeddings.shape[1])
    index.add(embeddings)

    logger.info(f"Saving FAISS index to {settings.INDEX_PATH}")
    faiss.write_index(index, settings.INDEX_PATH)

    with open(settings.METADATA_PATH, "wb") as f:
        pickle.dump(metadatas, f)

    logger.info(f"Successfully created FAISS index with {embeddings.shape[0]} embeddings")
    logger.info(f"Index dimension: {embeddings.shape[1]}")
    logger.info(f"Similarity threshold: {settings.SIMILARITY_THRESHOLD}")

    if settings.ENABLE_HYBRID_SEARCH:
        logger.info("Building BM25 index for hybrid search...")
        bm25, corpus_tokens, bm25_metadata = build_bm25_index(docs)
        save_bm25_index(bm25, corpus_tokens, bm25_metadata, settings.BM25_INDEX_PATH)
        logger.info(f"BM25 index saved to {settings.BM25_INDEX_PATH}")


def search_rag(query: str, k: Optional[int] = None) -> List[Dict]:
    import time

    if k is None:
        k = settings.TOP_K_DEFAULT

    start_time = time.time()

    query = query.strip().lower()

    if settings.ENABLE_RERANKING:
        initial_k = k * settings.INITIAL_RETRIEVAL_MULTIPLIER
        logger.debug(f"Searching for: '{query[:100]}...' with initial_k={initial_k} (will rerank to top {k})")
    else:
        initial_k = k
        logger.debug(f"Searching for: '{query[:100]}...' with k={k}")

    index = faiss.read_index(settings.INDEX_PATH)
    with open(settings.METADATA_PATH, "rb") as f:
        metadata = pickle.load(f)

    q_emb = embedding([query])
    if q_emb is None:
        logger.error("Failed to create query embedding")
        return []

    D, I = index.search(q_emb, initial_k)

    search_time = time.time() - start_time
    logger.debug(f"FAISS search completed in {search_time:.3f}s")

    threshold = settings.SIMILARITY_THRESHOLD
    contexts = []
    vector_results = []

    for dist, idx in zip(D[0], I[0]):
        doc = metadata[idx].copy()
        doc["faiss_distance"] = float(dist)
        vector_results.append((doc, dist))

        if dist < threshold:
            contexts.append(doc)
            logger.debug(f"Context found with distance: {dist:.4f}")

    if not contexts:
        logger.warning(f"No contexts found below threshold {threshold}, using fallback")
        fallback_k = min(settings.TOP_K_FALLBACK, initial_k)
        contexts = [doc for doc, _ in vector_results[:fallback_k]]
        logger.info(f"Fallback: returning top {len(contexts)} contexts")
    else:
        logger.info(f"Found {len(contexts)} contexts below threshold {threshold}")

    if settings.ENABLE_HYBRID_SEARCH:
        hybrid_start = time.time()
        contexts_with_scores = [(ctx, ctx.get("faiss_distance", 0)) for ctx in contexts]
        contexts = hybrid_search(
            query=query,
            vector_results=contexts_with_scores,
            k=k,
            fusion_method=settings.HYBRID_FUSION_METHOD,
            bm25_weight=settings.BM25_WEIGHT,
            vector_weight=settings.VECTOR_WEIGHT
        )
        hybrid_time = time.time() - hybrid_start
        logger.info(f"Hybrid search completed in {hybrid_time:.3f}s")

    if settings.ENABLE_RERANKING and contexts:
        rerank_start = time.time()
        contexts = rerank_documents(query, contexts, top_k=k)
        rerank_time = time.time() - rerank_start
        logger.info(f"Re-ranking completed in {rerank_time:.3f}s")
    else:
        contexts = contexts[:k]

    return contexts


def get_answer_stream(
    query: str,
    chat_history: Optional[List[Dict]] = None,
    k: Optional[int] = None,
    temperature: Optional[float] = None,
    max_tokens: Optional[int] = None
):

    import time

    start_time = time.time()

    logger.info(f"Processing streaming query: '{query[:100]}...'")

    contexts = search_rag(query, k)

    sources = []
    for i, ctx in enumerate(contexts[:settings.MAX_CONTEXTS_RESPONSE]):
        source_info = {
            "source": f"Nguồn {i+1}",
            "type": ctx.get("type", "unknown"),
            "title": ctx.get("title", "Không có tiêu đề")
        }

        if ctx.get("href"):
            source_info["href"] = ctx.get("href")

        sources.append(source_info)

    yield {
        "type": "metadata",
        "query": query,
        "contexts": contexts[:settings.MAX_CONTEXTS_RESPONSE],
        "sources": sources
    }

    use_history = True if chat_history else False

    llm_client = get_llm_client()

    try:
        for chunk in llm_client.generate_answer_stream(
            query=query,
            contexts=contexts,
            chat_history=chat_history,
            use_history=use_history,
            temperature=temperature,
            max_tokens=max_tokens
        ):
            yield {
                "type": "content",
                "content": chunk
            }

        total_time = time.time() - start_time
        logger.info(f"Streaming query processed in {total_time:.3f}s")

        yield {
            "type": "done",
            "process_time": total_time
        }

    except Exception as e:
        logger.error(f"LLM streaming generation failed: {str(e)}")
        yield {
            "type": "error",
            "error": "Xin lỗi, hệ thống tạm thời không thể tạo câu trả lời. Vui lòng thử lại sau."
        }
