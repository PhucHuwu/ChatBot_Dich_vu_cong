import logging
import re
from typing import List, Dict, Optional

logger = logging.getLogger(__name__)


GREETING_PATTERNS = [
    r'^(xin )?chào( bạn| anh| chị| em)?[!.?]*$',
    r'^(hi|hello|hey)( bạn| anh| chị| em)?[!.?]*$',
    r'^(chào|hi|hello|hey)$',
    r'^good (morning|afternoon|evening)$',
    r'^(tạm biệt|bye|goodbye)( bạn| anh| chị)?[!.?]*$',
    r'^(cảm ơn|thanks|thank you)( bạn| nhiều)?[!.?]*$',
    r'^ok+[!.?]*$',
    r'^(oke|okay|oki)$',
    r'^(ừ|uh|uhm|à)$',
]


FOLLOWUP_KEYWORDS = [
    r'\b(cái|việc|điều|thủ tục|hồ sơ|dịch vụ|tài khoản|giấy tờ)\s+(đó|này|ấy|kia)\b',
    r'\b(nó|họ|anh|chị|bạn|mình)\b',

    r'\b(còn|thêm|nữa|sau đó|kế tiếp)\b',
    r'\b(tiếp)\s+(theo)?\b',
    r'\b(vậy|thế|như vậy|như thế)\b',

    r'^(có|được|phải|cần|bao lâu|mất bao lâu|như thế nào|ra sao|thế nào)',
    r'^(và|hoặc|hay)',

    r'\b(như trên|như đã|như vừa|ở trên|phía trên|bên trên)\b',
    r'\b(câu hỏi trước|vừa rồi|lúc nãy|ban nãy)\b',

    r'\b(so với|khác với|giống|tương tự)\b',

    r'\b(chi tiết|cụ thể|rõ hơn|thêm về)\b',
    r'\b(vấn đề (này|đó|ấy))\b',
]

STANDALONE_KEYWORDS = [
    r'\b(làm thế nào|làm sao|cách thức|quy trình|hướng dẫn)\s+(để|cho|khi)',
    r'\b(đăng ký|tra cứu|thanh toán|nộp|đăng nhập|sử dụng|tạo|xoá|cập nhật)\b',

    r'\b(là gì|nghĩa là|có nghĩa|được hiểu)\b',
    r'\b(giới thiệu|thông tin về|cho biết về|cho tôi biết)\b',

    r'\b(ở đâu|tại đâu|đâu là|nơi nào)\b',
    r'\b(khi nào|lúc nào|thời gian|thời hạn)\b',
    r'\b(ai|tổ chức nào|cơ quan nào|bộ phận nào)\b',
]


def is_greeting_or_smalltalk(query: str) -> bool:
    query_lower = query.lower().strip()

    query_normalized = re.sub(r'[!?.]+$', '', query_lower).strip()

    for pattern in GREETING_PATTERNS:
        if re.match(pattern, query_normalized, re.IGNORECASE):
            logger.info(f"Detected greeting/small talk: '{query[:30]}...'")
            return True

    if len(query_normalized) < 5:
        domain_keywords = ['thủ tục', 'hồ sơ', 'đăng ký', 'tra cứu', 'dịch vụ']
        has_domain = any(kw in query_normalized for kw in domain_keywords)
        if not has_domain:
            logger.info(f"Very short query without domain keywords: '{query}'")
            return True

    return False


def is_followup_question(query: str, chat_history: Optional[List[Dict]] = None) -> bool:
    if not chat_history or len(chat_history) == 0:
        logger.debug("No chat history → standalone question")
        return False

    if is_greeting_or_smalltalk(query):
        logger.debug("Greeting/small talk → not a follow-up question")
        return False

    query_lower = query.lower().strip()

    if len(query_lower) < 10:
        logger.debug(f"Short query ({len(query_lower)} chars) → likely follow-up")
        return True

    for pattern in FOLLOWUP_KEYWORDS:
        if re.search(pattern, query_lower, re.IGNORECASE):
            logger.debug(f"Matched follow-up pattern: {pattern}")
            return True

    for pattern in STANDALONE_KEYWORDS:
        if re.search(pattern, query_lower, re.IGNORECASE):
            logger.debug(f"Matched standalone pattern: {pattern}")
            if re.search(r'\b(cụ thể|chi tiết|rõ hơn)\b', query_lower):
                logger.debug("Exception: has clarification keywords → follow-up")
                return True
            return False

    if _has_topic_continuity(query_lower, chat_history):
        logger.debug("Topic continuity detected → follow-up")
        return True

    logger.debug("Default: standalone question")
    return False


def _has_topic_continuity(query: str, chat_history: List[Dict], window: int = 2) -> bool:
    if not chat_history:
        return False

    recent_user_messages = [
        msg.get("content", "").lower()
        for msg in chat_history[-window:]
        if msg.get("role") == "user"
    ]

    if not recent_user_messages:
        return False

    query_keywords = _extract_keywords(query)

    for prev_message in recent_user_messages:
        prev_keywords = _extract_keywords(prev_message)

        common_keywords = query_keywords & prev_keywords
        if len(common_keywords) >= 2:
            logger.debug(f"Common keywords: {common_keywords}")
            return True

    return False


def _extract_keywords(text: str) -> set:
    stopwords = {
        'tôi', 'bạn', 'anh', 'chị', 'em', 'mình', 'là', 'của', 'và', 'có', 'được',
        'để', 'cho', 'khi', 'nào', 'đó', 'này', 'thế', 'vậy', 'như', 'với', 'từ',
        'về', 'trong', 'ngoài', 'trên', 'dưới', 'một', 'hai', 'ba', 'các', 'những',
        'thì', 'hay', 'hoặc', 'nhưng', 'mà', 'không', 'bị', 'đang', 'sẽ', 'đã',
        'cần', 'phải', 'muốn', 'nên', 'làm', 'gì', 'sao', 'đâu', 'ai', 'ở'
    }

    words = re.findall(r'\b\w+\b', text.lower())

    keywords = {
        word for word in words
        if word not in stopwords and len(word) >= 3
    }

    return keywords


def should_use_chat_history(query: str, chat_history: Optional[List[Dict]] = None) -> bool:
    use_history = is_followup_question(query, chat_history)

    logger.info(
        f"Context analysis: query='{query[:50]}...', "
        f"history_count={len(chat_history) if chat_history else 0}, "
        f"use_history={use_history}"
    )

    return use_history
