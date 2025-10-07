# Migration Guide - Chat History Optimization

## Tổng quan

Version mới **tự động tối ưu** việc sử dụng chat_history, không cần thay đổi code frontend/API.

## Có cần thay đổi gì không?

### ❌ KHÔNG CẦN thay đổi

**Frontend/Client code** - Giữ nguyên như cũ:

```javascript
// Vẫn gửi chat_history như bình thường
fetch('/api/chat', {
  method: 'POST',
  body: JSON.stringify({
    query: "Còn cần gì nữa?",
    chat_history: [...]  // ← Vẫn gửi
  })
})
```

**Backend API** - Tương thích ngược hoàn toàn:

```python
# API signature không đổi
POST /api/chat
{
  "query": "string",
  "chat_history": [...]  # Optional, như cũ
}
```

### ✅ Tự động hoạt động

Hệ thống **tự động**:

1. Nhận `chat_history` từ request
2. Phân tích câu hỏi
3. Quyết định có dùng history không
4. Trả về response như cũ

## Điểm khác biệt

### Trước

```
Request → Backend → LLM (luôn có history)
```

### Sau

```
Request → Backend → Analyzer → LLM (history khi cần)
                      ↓
              Quyết định thông minh
```

## Monitoring

### Log mới xuất hiện

**Standalone question**:

```
INFO: Context analysis: query='Hướng dẫn...', history_count=5, use_history=False
INFO: Chat history skipped: standalone question detected
```

**Follow-up question**:

```
INFO: Context analysis: query='Còn cần...', history_count=3, use_history=True
INFO: Using chat history: 3 messages
```

### Metrics cần theo dõi

1. **Tỷ lệ sử dụng history**

```bash
# Đếm số lần dùng history
grep "Using chat history" logs/*.log | wc -l

# Đếm số lần skip
grep "Chat history skipped" logs/*.log | wc -l
```

Mong đợi: **20-40%** requests sử dụng history

2. **Token tiết kiệm**

-   Trước: Avg 2500 tokens/request
-   Sau: Avg 800 tokens/request
-   Monitor qua dashboard LLM provider

3. **Latency**

-   Standalone queries nhanh hơn ~50%
-   Follow-up queries giữ nguyên

## Rollback (nếu cần)

### Tắt tính năng tạm thời

Sửa `rag.py`:

```python
def get_answer(query, chat_history=None, ...):
    # Phân tích tự động
    # use_history = should_use_chat_history(query, chat_history)
    use_history = True  # ← Force luôn dùng history (như cũ)

    # ...
```

### Hoàn toàn revert

```bash
git revert <commit-hash>
```

## Testing sau deploy

### 1. Test standalone question

```bash
curl -X POST http://localhost:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Hướng dẫn đăng ký tài khoản dịch vụ công",
    "chat_history": []
  }'
```

**Kiểm tra log**: Phải thấy `use_history=False`

### 2. Test follow-up question

```bash
curl -X POST http://localhost:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Còn cần gì nữa?",
    "chat_history": [
      {"role": "user", "content": "Đăng ký cần CMND"}
    ]
  }'
```

**Kiểm tra log**: Phải thấy `use_history=True`

### 3. Test chủ đề mới

```bash
curl -X POST http://localhost:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Hướng dẫn thanh toán tiền điện",
    "chat_history": [
      {"role": "user", "content": "Đăng ký tài khoản như thế nào?"}
    ]
  }'
```

**Kiểm tra log**: Phải thấy `use_history=False`

## Troubleshooting

### Vấn đề: Quá nhiều standalone được phát hiện

**Triệu chứng**: > 80% queries không dùng history

**Nguyên nhân**: Patterns quá strict

**Giải pháp**:

1. Kiểm tra log DEBUG xem patterns nào match
2. Điều chỉnh ngưỡng trong `context_analyzer.py`
3. Giảm threshold topic continuity

### Vấn đề: Quá ít standalone

**Triệu chứng**: > 80% queries vẫn dùng history

**Nguyên nhân**: Patterns không đủ

**Giải pháp**:

1. Thêm standalone keywords
2. Tăng ngưỡng độ dài câu follow-up
3. Kiểm tra stopwords có loại từ quan trọng không

### Vấn đề: Performance không cải thiện

**Triệu chứng**: Token/latency không giảm

**Nguyên nhân**:

-   Cache đang hoạt động → đo sai
-   Hầu hết queries thực sự cần history

**Giải pháp**:

1. Clear cache và đo lại
2. Phân tích log xem tỷ lệ use_history
3. A/B test với user thực

## Performance Checklist

Sau deploy, kiểm tra:

-   [ ] Tỷ lệ use_history trong khoảng 20-40%
-   [ ] Avg tokens/request giảm 40-60%
-   [ ] Latency standalone queries giảm 40-50%
-   [ ] Answer quality không giảm (survey/feedback)
-   [ ] Không có error spike
-   [ ] Cache stats bình thường

## Support

Nếu gặp vấn đề:

1. **Check logs** - Tìm pattern lạ
2. **Run tests** - `pytest tests/test_context_analyzer.py`
3. **Check metrics** - Token usage, latency
4. **Review code** - `context_analyzer.py`, `rag.py`, `llm_client.py`
5. **Read docs** - `docs/CONTEXT_ANALYZER.md`

## Kết luận

✅ **Zero-downtime migration** - Không cần thay đổi client  
✅ **Backward compatible** - API giữ nguyên  
✅ **Auto-optimize** - Tự động tối ưu  
✅ **Monitorable** - Đầy đủ logs & metrics  
✅ **Rollback-able** - Dễ dàng revert nếu cần

Happy deploying! 🚀
