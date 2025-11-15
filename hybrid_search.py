import pickle
import logging
from typing import List, Dict, Tuple, Optional
from rank_bm25 import BM25Okapi
import numpy as np
from config import settings

logger = logging.getLogger(__name__)

bm25_index = None
bm25_corpus_tokens = None
bm25_metadata = None


def tokenize_vietnamese(text: str) -> List[str]:
    import re
    text = text.lower()
    text = re.sub(r'[^\w\s]', ' ', text)
    tokens = text.split()
    return [t for t in tokens if len(t) > 1]


def build_bm25_index(documents: List[Dict]) -> Tuple[BM25Okapi, List[List[str]], List[Dict]]:
    logger.info(f"Building BM25 index for {len(documents)} documents...")

    corpus_tokens = []
    metadata = []

    for doc in documents:
        tokens = tokenize_vietnamese(doc["text"])
        corpus_tokens.append(tokens)
        metadata.append(doc)

    bm25 = BM25Okapi(corpus_tokens)

    logger.info(f"BM25 index built successfully with {len(corpus_tokens)} documents")
    return bm25, corpus_tokens, metadata


def save_bm25_index(bm25: BM25Okapi, corpus_tokens: List[List[str]], metadata: List[Dict], path: str) -> None:
    try:
        data = {
            'bm25': bm25,
            'corpus_tokens': corpus_tokens,
            'metadata': metadata
        }
        with open(path, 'wb') as f:
            pickle.dump(data, f)
        logger.info(f"BM25 index saved to {path}")
    except Exception as e:
        logger.error(f"Failed to save BM25 index: {e}")
        raise


def load_bm25_index(path: str) -> Tuple[BM25Okapi, List[List[str]], List[Dict]]:
    global bm25_index, bm25_corpus_tokens, bm25_metadata

    if bm25_index is not None:
        logger.debug("Using cached BM25 index")
        return bm25_index, bm25_corpus_tokens, bm25_metadata

    try:
        with open(path, 'rb') as f:
            data = pickle.load(f)

        bm25_index = data['bm25']
        bm25_corpus_tokens = data['corpus_tokens']
        bm25_metadata = data['metadata']

        logger.info(f"BM25 index loaded from {path} with {len(bm25_metadata)} documents")
        return bm25_index, bm25_corpus_tokens, bm25_metadata
    except Exception as e:
        logger.error(f"Failed to load BM25 index: {e}")
        raise


def search_bm25(query: str, k: int = 10, bm25_path: Optional[str] = None) -> List[Tuple[Dict, float]]:
    if bm25_path is None:
        bm25_path = settings.BM25_INDEX_PATH

    bm25, corpus_tokens, metadata = load_bm25_index(bm25_path)

    query_tokens = tokenize_vietnamese(query)
    logger.debug(f"BM25 search query tokens: {query_tokens}")

    scores = bm25.get_scores(query_tokens)

    top_indices = np.argsort(scores)[::-1][:k]

    results = []
    for idx in top_indices:
        doc = metadata[idx].copy()
        score = float(scores[idx])
        results.append((doc, score))
        logger.debug(f"BM25 result: score={score:.4f}, text={doc['text'][:50]}...")

    logger.info(f"BM25 search returned {len(results)} results")
    return results


def reciprocal_rank_fusion(rankings: List[List[Tuple[str, Dict, float]]], k: int = 60) -> List[Dict]:
    rrf_scores = {}
    doc_map = {}

    for ranking in rankings:
        for rank, (doc_id, doc, original_score) in enumerate(ranking, start=1):
            if doc_id not in rrf_scores:
                rrf_scores[doc_id] = 0
                doc_map[doc_id] = doc

            rrf_scores[doc_id] += 1 / (k + rank)

    sorted_docs = sorted(rrf_scores.items(), key=lambda x: x[1], reverse=True)

    results = []
    for doc_id, rrf_score in sorted_docs:
        doc = doc_map[doc_id].copy()
        doc['rrf_score'] = float(rrf_score)
        results.append(doc)

    return results


def weighted_score_fusion(
    bm25_results: List[Tuple[Dict, float]],
    vector_results: List[Tuple[Dict, float]],
    bm25_weight: float = 0.5,
    vector_weight: float = 0.5
) -> List[Dict]:
    def normalize_scores(scores: List[float]) -> List[float]:
        if not scores or max(scores) == min(scores):
            return [1.0] * len(scores)
        min_score = min(scores)
        max_score = max(scores)
        return [(s - min_score) / (max_score - min_score) for s in scores]

    bm25_scores = [score for _, score in bm25_results]
    normalized_bm25 = normalize_scores(bm25_scores)

    vector_scores = [score for _, score in vector_results]
    normalized_vector = normalize_scores(vector_scores)

    doc_scores = {}
    doc_map = {}

    for (doc, _), norm_score in zip(bm25_results, normalized_bm25):
        doc_id = doc['text']
        doc_scores[doc_id] = bm25_weight * norm_score
        doc_map[doc_id] = doc

    for (doc, _), norm_score in zip(vector_results, normalized_vector):
        doc_id = doc['text']
        vector_contrib = vector_weight * (1.0 - norm_score)

        if doc_id in doc_scores:
            doc_scores[doc_id] += vector_contrib
        else:
            doc_scores[doc_id] = vector_contrib
            doc_map[doc_id] = doc

    sorted_docs = sorted(doc_scores.items(), key=lambda x: x[1], reverse=True)

    results = []
    for doc_id, fused_score in sorted_docs:
        doc = doc_map[doc_id].copy()
        doc['hybrid_score'] = float(fused_score)
        results.append(doc)

    return results


def hybrid_search(
    query: str,
    vector_results: List[Tuple[Dict, float]],
    k: int = 10,
    fusion_method: str = "rrf",
    bm25_weight: float = 0.5,
    vector_weight: float = 0.5
) -> List[Dict]:
    if not settings.ENABLE_HYBRID_SEARCH:
        logger.debug("Hybrid search disabled, returning vector results only")
        return [doc for doc, _ in vector_results[:k]]

    logger.info(f"Performing hybrid search with fusion method: {fusion_method}")

    bm25_k = k * settings.BM25_RETRIEVAL_MULTIPLIER
    bm25_results = search_bm25(query, k=bm25_k)

    logger.info(f"BM25: {len(bm25_results)} results, Vector: {len(vector_results)} results")

    if fusion_method == "rrf":
        bm25_ranking = [(doc['text'], doc, score) for doc, score in bm25_results]
        vector_ranking = [(doc['text'], doc, score) for doc, score in vector_results]

        results = reciprocal_rank_fusion([bm25_ranking, vector_ranking], k=60)
    elif fusion_method == "weighted":
        results = weighted_score_fusion(bm25_results, vector_results, bm25_weight, vector_weight)
    else:
        logger.warning(f"Unknown fusion method: {fusion_method}, using RRF")
        bm25_ranking = [(doc['text'], doc, score) for doc, score in bm25_results]
        vector_ranking = [(doc['text'], doc, score) for doc, score in vector_results]
        results = reciprocal_rank_fusion([bm25_ranking, vector_ranking], k=60)

    return results[:k]


def get_hybrid_search_info() -> Dict:
    return {
        "enabled": settings.ENABLE_HYBRID_SEARCH,
        "fusion_method": settings.HYBRID_FUSION_METHOD,
        "bm25_weight": settings.BM25_WEIGHT,
        "vector_weight": settings.VECTOR_WEIGHT,
        "bm25_retrieval_multiplier": settings.BM25_RETRIEVAL_MULTIPLIER
    }
