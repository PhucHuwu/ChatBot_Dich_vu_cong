import hashlib
import logging
import time
from typing import Optional, Dict, Any
from functools import lru_cache
from config import settings

logger = logging.getLogger(__name__)


class QueryCache:
    def __init__(self, max_size: int = None, ttl: int = None):
        self.max_size = max_size or settings.CACHE_MAX_SIZE
        self.ttl = ttl or settings.CACHE_TTL
        self.cache: Dict[str, Dict[str, Any]] = {}
        self.enabled = settings.ENABLE_CACHE

        logger.info(
            f"QueryCache initialized: enabled={self.enabled}, "
            f"max_size={self.max_size}, ttl={self.ttl}s"
        )

    def _generate_key(self, query: str, k: int = None, **kwargs) -> str:
        normalized_query = query.strip().lower()

        cache_str = f"{normalized_query}|k={k}|{sorted(kwargs.items())}"

        return hashlib.md5(cache_str.encode()).hexdigest()

    def get(self, query: str, k: int = None, **kwargs) -> Optional[Dict[str, Any]]:
        if not self.enabled:
            return None

        cache_key = self._generate_key(query, k, **kwargs)

        if cache_key in self.cache:
            entry = self.cache[cache_key]

            age = time.time() - entry["timestamp"]
            if age < self.ttl:
                logger.debug(f"Cache HIT: key={cache_key[:8]}... age={age:.1f}s")
                entry["hits"] += 1
                return entry["data"]
            else:
                logger.debug(f"Cache EXPIRED: key={cache_key[:8]}... age={age:.1f}s")
                del self.cache[cache_key]

        logger.debug(f"Cache MISS: key={cache_key[:8]}...")
        return None

    def set(self, query: str, data: Dict[str, Any], k: int = None, **kwargs) -> None:
        if not self.enabled:
            return

        cache_key = self._generate_key(query, k, **kwargs)

        if len(self.cache) >= self.max_size:
            oldest_key = min(self.cache.keys(), key=lambda k: self.cache[k]["timestamp"])
            logger.debug(f"Cache EVICT: key={oldest_key[:8]}... (cache full)")
            del self.cache[oldest_key]

        self.cache[cache_key] = {
            "data": data,
            "timestamp": time.time(),
            "hits": 0
        }

        logger.debug(f"Cache SET: key={cache_key[:8]}... size={len(self.cache)}")

    def clear(self) -> None:
        self.cache.clear()
        logger.info("Cache cleared")

    def get_stats(self) -> Dict[str, Any]:
        total_hits = sum(entry["hits"] for entry in self.cache.values())

        return {
            "enabled": self.enabled,
            "size": len(self.cache),
            "max_size": self.max_size,
            "ttl": self.ttl,
            "total_hits": total_hits,
            "entries": [
                {
                    "key": key[:8] + "...",
                    "age": time.time() - entry["timestamp"],
                    "hits": entry["hits"]
                }
                for key, entry in list(self.cache.items())[:10]
            ]
        }


_cache_instance: Optional[QueryCache] = None


def get_cache() -> QueryCache:
    global _cache_instance

    if _cache_instance is None:
        _cache_instance = QueryCache()

    return _cache_instance


def cache_key_normalizer(query: str) -> str:
    normalized = " ".join(query.lower().strip().split())
    return normalized
