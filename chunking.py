def chunk_faq(faq_list):
    return [
        {"text": f"Câu hỏi: {item['question']}\nTrả lời: {item['answer']}\nĐường dẫn: {item['href']}", "metadata": {"type": "faq"}}
        for item in faq_list
    ]


def chunk_guide(guide_list):
    return [
        {
            "text": f"Tiêu đề: {item['title']}\nNội dung: {item['content']}\nĐường dẫn: {item['href']}",
            "metadata": {"type": "guide"}
        }
        for item in guide_list
    ]


def chunk_policy(policy_list):
    pass
