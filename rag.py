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
from config import settings
from context_analyzer import should_use_chat_history, is_greeting_or_smalltalk

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

    logger.info(f"Saving index to {settings.INDEX_PATH}")
    faiss.write_index(index, settings.INDEX_PATH)

    with open(settings.METADATA_PATH, "wb") as f:
        pickle.dump(metadatas, f)

    logger.info(f"Successfully created index with {embeddings.shape[0]} embeddings")
    logger.info(f"Index dimension: {embeddings.shape[1]}")
    logger.info(f"Similarity threshold: {settings.SIMILARITY_THRESHOLD}")


def search_rag(query: str, k: Optional[int] = None) -> List[Dict]:
    import time

    if k is None:
        k = settings.TOP_K_DEFAULT

    start_time = time.time()

    query = query.strip().lower()
    logger.debug(f"Searching for: '{query[:100]}...' with k={k}")

    index = faiss.read_index(settings.INDEX_PATH)
    with open(settings.METADATA_PATH, "rb") as f:
        metadata = pickle.load(f)

    q_emb = embedding([query])
    if q_emb is None:
        logger.error("Failed to create query embedding")
        return []

    D, I = index.search(q_emb, k)

    search_time = time.time() - start_time
    logger.debug(f"FAISS search completed in {search_time:.3f}s")

    threshold = settings.SIMILARITY_THRESHOLD
    contexts = []

    for dist, idx in zip(D[0], I[0]):
        if dist < threshold:
            contexts.append(metadata[idx])
            logger.debug(f"Context found with distance: {dist:.4f}")

    if not contexts:
        logger.warning(f"No contexts found below threshold {threshold}, using fallback")
        fallback_k = min(settings.TOP_K_FALLBACK, k)
        contexts = [metadata[i] for i in I[0][:fallback_k]]
        logger.info(f"Fallback: returning top {len(contexts)} contexts")
    else:
        logger.info(f"Found {len(contexts)} contexts below threshold {threshold}")

    return contexts


def get_answer(
    query: str,
    chat_history: Optional[List[Dict]] = None,
    k: Optional[int] = None,
    temperature: Optional[float] = None,
    max_tokens: Optional[int] = None
) -> Dict:
    import time

    start_time = time.time()

    logger.info(f"Processing query: '{query[:100]}...'")

    if is_greeting_or_smalltalk(query):
        logger.info("Greeting/small talk detected → skipping RAG search")
        contexts = []
    else:
        contexts = search_rag(query, k)

    use_history = should_use_chat_history(query, chat_history)

    llm_client = get_llm_client()

    try:
        answer = llm_client.generate_answer(
            query=query,
            contexts=contexts,
            chat_history=chat_history,
            use_history=use_history,
            temperature=temperature,
            max_tokens=max_tokens
        )
    except Exception as e:
        logger.error(f"LLM generation failed: {str(e)}")
        answer = (
            "Xin lỗi, hệ thống tạm thời không thể tạo câu trả lời. "
            "Vui lòng thử lại sau hoặc liên hệ hỗ trợ kỹ thuật."
        )

    total_time = time.time() - start_time
    logger.info(f"Query processed in {total_time:.3f}s")

    return {
        "query": query,
        "contexts": contexts,
        "answer": answer
    }
