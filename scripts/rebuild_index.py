import os
import sys
import argparse
import logging

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv()

from config import settings
from rag import build_index
from embedding import get_device_info

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def should_rebuild(force: bool = False) -> bool:
    if force:
        logger.info("Force rebuild requested")
        return True
    
    faiss_exists = os.path.exists(settings.INDEX_PATH)
    metadata_exists = os.path.exists(settings.METADATA_PATH)
    bm25_exists = os.path.exists(settings.BM25_INDEX_PATH)
    
    logger.info(f"Index status:")
    logger.info(f"  - FAISS index: {'✓' if faiss_exists else '✗'} ({settings.INDEX_PATH})")
    logger.info(f"  - Metadata: {'✓' if metadata_exists else '✗'} ({settings.METADATA_PATH})")
    logger.info(f"  - BM25 index: {'✓' if bm25_exists else '✗'} ({settings.BM25_INDEX_PATH})")
    
    if not faiss_exists or not metadata_exists:
        logger.warning("FAISS index or metadata missing - rebuild required")
        return True
    
    if settings.ENABLE_HYBRID_SEARCH and not bm25_exists:
        logger.warning("Hybrid search enabled but BM25 index missing - rebuild required")
        return True
    
    logger.info("All indices present, no rebuild needed")
    return False


def main():
    parser = argparse.ArgumentParser(
        description='Rebuild search indices (FAISS + BM25)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Check and rebuild if needed
  python3 scripts/rebuild_index.py

  # Force rebuild
  python3 scripts/rebuild_index.py --force

  # Rebuild with custom batch size
  python3 scripts/rebuild_index.py --batch-size 64

  # Check only (no rebuild)
  python3 scripts/rebuild_index.py --check-only
        """
    )
    
    parser.add_argument(
        '--force',
        action='store_true',
        help='Force rebuild even if indices exist'
    )
    
    parser.add_argument(
        '--batch-size',
        type=int,
        default=None,
        help=f'Embedding batch size (default: {settings.EMBEDDING_BATCH_SIZE})'
    )
    
    parser.add_argument(
        '--check-only',
        action='store_true',
        help='Only check index status, do not rebuild'
    )
    
    args = parser.parse_args()
    
    logger.info("=" * 60)
    logger.info("Index Rebuild Script")
    logger.info("=" * 60)
    
    logger.info(f"\nConfiguration:")
    logger.info(f"  - Environment: {settings.APP_ENV}")
    logger.info(f"  - Hybrid Search: {settings.ENABLE_HYBRID_SEARCH}")
    logger.info(f"  - Re-ranking: {settings.ENABLE_RERANKING}")
    logger.info(f"  - Batch Size: {args.batch_size or settings.EMBEDDING_BATCH_SIZE}")
    
    device_info = get_device_info()
    logger.info(f"\nDevice Info:")
    logger.info(f"  - Device: {device_info.get('device', 'unknown')}")
    if 'gpu_name' in device_info:
        logger.info(f"  - GPU: {device_info['gpu_name']}")
    logger.info(f"  - Embedding Model: {settings.EMBEDDING_MODEL}")
    
    logger.info("\n" + "=" * 60)
    
    if args.check_only:
        logger.info("Check-only mode: verifying index status...")
        should_rebuild(force=False)
        logger.info("Check complete. Use --force to rebuild.")
        return 0
    
    if should_rebuild(force=args.force):
        logger.info("\nStarting index rebuild...")
        
        try:
            batch_size = args.batch_size or settings.EMBEDDING_BATCH_SIZE
            build_index(batch_size=batch_size)
            
            logger.info("\n" + "=" * 60)
            logger.info("✓ Index rebuild completed successfully!")
            logger.info("=" * 60)
            
            if os.path.exists(settings.INDEX_PATH):
                logger.info(f"✓ FAISS index created: {settings.INDEX_PATH}")
            if os.path.exists(settings.METADATA_PATH):
                logger.info(f"✓ Metadata created: {settings.METADATA_PATH}")
            if settings.ENABLE_HYBRID_SEARCH and os.path.exists(settings.BM25_INDEX_PATH):
                logger.info(f"✓ BM25 index created: {settings.BM25_INDEX_PATH}")
            
            return 0
            
        except Exception as e:
            logger.error(f"\n✗ Index rebuild failed: {str(e)}")
            logger.exception(e)
            return 1
    else:
        logger.info("\nNo rebuild needed. Use --force to rebuild anyway.")
        return 0


if __name__ == "__main__":
    sys.exit(main())
