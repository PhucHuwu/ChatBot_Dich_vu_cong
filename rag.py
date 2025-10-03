import os
from dotenv import load_dotenv
from groq import Groq
import faiss
import pickle
from chunking import chunk_faq, chunk_guide
from embedding import embedding, get_device_info

load_dotenv()
api = os.getenv("api_key")

client = Groq(api_key=api)

MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"


def build_index(batch_size=32):
    import json
    import os

    device_info = get_device_info()
    print(f"Dang su dung: {device_info}")

    os.makedirs("embeddings", exist_ok=True)

    faq = json.load(open("data/faq.json", encoding="utf-8"))
    guide = json.load(open("data/guide.json", encoding="utf-8"))

    docs = chunk_faq(faq) + chunk_guide(guide)
    texts = [d["text"] for d in docs]
    metadatas = [{"text": d["text"], **d["metadata"]} for d in docs]

    print(f"Dang tao embedding cho {len(texts)} documents...")
    embeddings = embedding(texts, batch_size=batch_size)

    index = faiss.IndexFlatL2(embeddings.shape[1])
    index.add(embeddings)

    faiss.write_index(index, "embeddings/faiss_index.bin")
    with open("embeddings/metadata.pkl", "wb") as f:
        pickle.dump(metadatas, f)

    print(f"Da tao index voi {embeddings.shape[0]} embeddings")


def search_rag(query, k=10):
    import pickle
    import faiss
    from embedding import embedding

    query = query.strip().lower()

    index = faiss.read_index("embeddings/faiss_index.bin")
    metadata = pickle.load(open("embeddings/metadata.pkl", "rb"))

    q_emb = embedding([query])
    D, I = index.search(q_emb, k)

    threshold = 1.2
    contexts = []
    for dist, idx in zip(D[0], I[0]):
        if dist < threshold:
            contexts.append(metadata[idx])
    if not contexts:
        contexts = [metadata[i] for i in I[0]]
    return contexts


def generate_answer(query, contexts, chat_history=None, temperature=0.7, max_tokens=2048):
    prompt = f"Dưới đây là các thông tin liên quan đến câu hỏi của người dùng:\n"
    for i, context in enumerate(contexts, 1):
        info_type = context.get("type", "")
        if info_type == "faq":
            prompt += f"[FAQ] Thông tin {i}:\n{context.get('text', '')}\n\n"
        else:
            prompt += f"Thông tin {i}:\n{context.get('text', '')}\n\n"

    prompt += f"Câu hỏi của khách hàng: {query}\n\n"
    prompt += "Vui lòng trả lời dựa trên các thông tin trên."
    prompt += "Nếu không đủ thông tin, hãy nói rõ bạn không thể trả lời chính xác."
    prompt += "Trả lời đầy đủ, rõ ý, dễ hiểu bằng tiếng Việt."
    prompt += "Nếu người dùng hỏi câu hỏi không liên quan đến thủ tục hành chính trong Dịch vụ công Quốc gia, hãy nói rõ bạn không thể trả lời và không đưa thông tin gì thêm."
    prompt += "Hãy đưa các đường dẫn liên quan đến câu hỏi của người dùng nếu có thể."

    messages = [
        {"role": "system",
         "content": """Bạn là một trợ lý hỗ trợ người dân về Dịch vụ công Quốc gia, 
                    chuyên trả lời các câu hỏi về Dịch vụ công Quốc gia, 
                    hướng dẫn người dân thực hiện các thủ tục hành chính.
                    Hãy tham khảo lịch sử cuộc trò chuyện để hiểu ngữ cảnh và trả lời phù hợp."""}
    ]

    if chat_history:
        for msg in chat_history[-5:]:
            messages.append({
                "role": msg.role,
                "content": msg.content
            })

    messages.append({"role": "user", "content": prompt})

    try:
        response = client.chat.completions.create(
            model=MODEL,
            messages=messages,
            temperature=temperature,
            max_tokens=max_tokens
        )
        return response.choices[0].message.content
    except Exception as e:
        return f"Đã xảy ra lỗi khi tạo câu trả lời: {str(e)}"


def get_answer(query, chat_history=None, k=10, temperature=0.7, max_tokens=2048):
    contexts = search_rag(query, k)

    answer = generate_answer(query, contexts, chat_history, temperature, max_tokens)

    return {
        "query": query,
        "contexts": contexts,
        "answer": answer
    }
