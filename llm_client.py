import logging
from typing import List, Dict, Optional
from groq import Groq
from config import settings

logger = logging.getLogger(__name__)


class LLMClient:
    def __init__(self, api_key: Optional[str] = None, model: Optional[str] = None):
        self.api_key = api_key or settings.GROQ_API_KEY
        self.model = model or settings.LLM_MODEL

        if not self.api_key:
            raise ValueError("GROQ_API_KEY is required")

        self.client = Groq(api_key=self.api_key)
        logger.info(f"LLM Client initialized with model: {self.model}")

    def generate_completion(
        self,
        messages: List[Dict[str, str]],
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
        timeout: Optional[int] = None,
        stream: Optional[bool] = None,
        reasoning_effort: Optional[str] = None
    ) -> str:
        temperature = temperature if temperature is not None else settings.LLM_TEMPERATURE
        max_tokens = max_tokens if max_tokens is not None else settings.LLM_MAX_TOKENS
        timeout = timeout if timeout is not None else settings.LLM_TIMEOUT
        stream = stream if stream is not None else settings.LLM_STREAM
        reasoning_effort = reasoning_effort if reasoning_effort is not None else settings.LLM_REASONING_EFFORT

        try:
            logger.debug(f"Calling LLM with {len(messages)} messages, temp={temperature}, stream={stream}")

            response = self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                temperature=temperature,
                max_completion_tokens=max_tokens,
                timeout=timeout,
                stream=stream,
                reasoning_effort=reasoning_effort,
                top_p=1,
                stop=None
            )

            if stream:
                full_content = ""
                for chunk in response:
                    if chunk.choices[0].delta.content:
                        full_content += chunk.choices[0].delta.content

                logger.debug(f"LLM streaming response received, length: {len(full_content)} chars")
                return full_content
            else:
                content = response.choices[0].message.content
                logger.debug(f"LLM response received, length: {len(content)} chars")
                return content

        except Exception as e:
            logger.error(f"LLM API call failed: {str(e)}")
            raise

    def generate_answer(
        self,
        query: str,
        contexts: List[Dict],
        chat_history: Optional[List[Dict]] = None,
        use_history: bool = True,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None
    ) -> str:
        prompt = self._build_prompt(query, contexts)

        system_message = {
            "role": "system",
            "content": self._get_system_prompt()
        }

        messages = [system_message]

        if use_history and chat_history:
            recent_history = chat_history[-settings.CONTEXT_WINDOW_MESSAGES:]
            logger.info(f"Using chat history: {len(recent_history)} messages")
            for msg in recent_history:
                messages.append({
                    "role": msg.get("role", "user"),
                    "content": msg.get("content", "")
                })
        else:
            if not use_history:
                logger.info("Chat history skipped: standalone question detected")
            elif not chat_history:
                logger.debug("Chat history skipped: no history available")

        messages.append({
            "role": "user",
            "content": prompt
        })

        return self.generate_completion(
            messages=messages,
            temperature=temperature,
            max_tokens=max_tokens
        )

    def _build_prompt(self, query: str, contexts: List[Dict]) -> str:
        if not contexts or len(contexts) == 0:
            return f"Câu hỏi của người dùng: {query}"

        prompt_parts = ["Dưới đây là các thông tin liên quan đến câu hỏi của người dùng:\n"]

        for i, context in enumerate(contexts[:settings.MAX_CONTEXTS_RESPONSE], 1):
            info_type = context.get("type", "")
            text = context.get("text", "")

            if info_type == "faq":
                prompt_parts.append(f"[FAQ] Nguồn {i}:\n{text}\n")
            else:
                category = context.get("category", "")
                if category:
                    prompt_parts.append(f"[{category}] Nguồn {i}:\n{text}\n")
                else:
                    prompt_parts.append(f"Nguồn {i}:\n{text}\n")

            href = context.get("href", "")
            if href:
                prompt_parts.append(f"Đường dẫn: {href}\n")

            prompt_parts.append("---\n")

        prompt_parts.append(f"\nCâu hỏi của người dùng: {query}\n\n")
        prompt_parts.append(
            "Hãy trả lời câu hỏi dựa trên các thông tin được cung cấp ở trên. "
            "Trả lời đầy đủ, rõ ràng, dễ hiểu bằng tiếng Việt. "
            "Nếu có đường dẫn liên quan, hãy đề xuất người dùng truy cập để biết thêm chi tiết."
        )

        return "".join(prompt_parts)

    def _get_system_prompt(self) -> str:
        return """Bạn là trợ lý AI chuyên về Dịch vụ công Quốc gia của Việt Nam.

Nhiệm vụ của bạn:
- Hỗ trợ người dân về các thủ tục hành chính và dịch vụ công
- Hướng dẫn sử dụng dịch vụ công trực tuyến
- Trả lời các câu hỏi về quy trình, giấy tờ cần thiết
- Cung cấp thông tin chính xác dựa trên dữ liệu được cung cấp

Nguyên tắc trả lời:

1. PHÙ HỢP VỚI NGÔN NGỮ VÀ NGÔN NGỮ CỦA NGƯỜI DÙNG:
   - Lời chào/small talk: Trả lời ngắn gọn, thân thiện, giới thiệu vai trò, mời đặt câu hỏi cụ thể
   - Câu hỏi mơ hồ/chung chung: Đặt câu hỏi làm rõ để hiểu đúng nhu cầu
   - Câu hỏi đa nội dung: Tách từng phần, trả lời có cấu trúc rõ ràng
   - Câu hỏi theo ngữ cảnh (dựa vào lịch sử chat): Sử dụng ngữ cảnh để trả lời chính xác

2. XỬ LÝ THÔNG TIN VÀ DỮ LIỆU:
   - Có đủ thông tin: Trả lời ngắn gọn, rõ ràng, dễ hiểu bằng tiếng Việt
   - Thiếu thông tin: Nói rõ phần nào thiếu, hướng dẫn liên hệ cơ quan có thẩm quyền (Cổng DVC Quốc gia, UBND, Bộ ngành)
   - Thông tin mâu thuẫn trong nguồn: Ưu tiên nguồn chính thức, ghi chú sự khác biệt nếu cần
   - CHỈ dựa trên dữ liệu được cung cấp, KHÔNG tự suy đoán hoặc tự tạo thông tin

3. GIỚI HẠN PHẠM VI VÀ AN TOÀN:
   - Câu hỏi NGOÀI phạm vi (không liên quan dịch vụ công): Lịch sự từ chối, giải thích chỉ hỗ trợ về dịch vụ công
   - Câu hỏi pháp lý chuyên sâu (không có trong dữ liệu): Từ chối tư vấn, khuyên tham khảo luật sư/chuyên gia
   - Câu hỏi nhạy cảm (chính trị, cá nhân): Chỉ trả lời khía cạnh thủ tục hành chính (nếu có), tránh bình luận
   - KHÔNG đưa ra quan điểm cá nhân, chỉ cung cấp thông tin khách quan

4. TRẢI NGHIỆM NGƯỜI DÙNG:
   - Luôn thân thiện, chuyên nghiệp, tôn trọng
   - Cấu trúc rõ ràng: dùng danh sách, phân đoạn khi câu trả lời dài
   - Đề xuất đường dẫn/liên kết khi có để người dùng tìm hiểu thêm
   - Chủ động gợi ý câu hỏi liên quan hoặc bước tiếp theo (nếu phù hợp)
   - Kiểm tra lịch sử cuộc trò chuyện để tránh lặp lại và duy trì ngữ cảnh

5. ĐẢM BẢO CHẤT LƯỢNG:
   - Độ chính xác: ưu tiên chính xác hơn đầy đủ
   - Cập nhật: nếu nghi ngờ thông tin cũ, khuyên người dùng kiểm tra nguồn chính thức mới nhất"""


_llm_client_instance: Optional[LLMClient] = None


def get_llm_client() -> LLMClient:
    global _llm_client_instance

    if _llm_client_instance is None:
        _llm_client_instance = LLMClient()

    return _llm_client_instance
