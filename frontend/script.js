document.addEventListener("DOMContentLoaded", function () {
    const chatForm = document.getElementById("chat-form");
    const userInput = document.getElementById("user-input");
    const chatBox = document.getElementById("chat-box");
    const sendButton = document.getElementById("send-button");
    const typingIndicator = document.getElementById("typing-indicator");
    const quickActions = document.getElementById("quick-actions");

    let chatHistory = [];
    const MAX_HISTORY_LENGTH = 10;

    function getCurrentTime() {
        const now = new Date();
        return now.toLocaleTimeString("vi-VN", {
            hour: "2-digit",
            minute: "2-digit",
        });
    }

    function addToHistory(sender, message) {
        chatHistory.push({
            sender: sender,
            message: message,
            timestamp: new Date().toISOString(),
        });

        if (chatHistory.length > MAX_HISTORY_LENGTH) {
            chatHistory = chatHistory.slice(-MAX_HISTORY_LENGTH);
        }

        updateHistoryIndicator();
    }

    function getChatHistoryForAPI() {
        return chatHistory.map((item) => ({
            role: item.sender === "user" ? "user" : "assistant",
            content: item.message,
        }));
    }

    function clearChatHistory() {
        chatHistory = [];
        updateHistoryIndicator();
    }

    function updateHistoryIndicator() {
        const historyCount = chatHistory.length;
        const statusElement = document.querySelector(".status");

        if (historyCount > 0) {
            statusElement.innerHTML = `
                <span class="status-dot"></span>
                Chatbot hỗ trợ 24/7 (${historyCount} tin nhắn)
            `;
        } else {
            statusElement.innerHTML = `
                <span class="status-dot"></span>
                Chatbot hỗ trợ 24/7
            `;
        }
    }

    function formatMarkdown(text) {
        let html = text
            .replace(/^### (.*$)/gim, "<h3>$1</h3>")
            .replace(/^## (.*$)/gim, "<h2>$1</h2>")
            .replace(/^# (.*$)/gim, "<h1>$1</h1>")

            .replace(/\*\*(.*?)\*\*/g, "<strong>$1</strong>")
            .replace(/__(.*?)__/g, "<strong>$1</strong>")

            .replace(/\*(.*?)\*/g, "<em>$1</em>")
            .replace(/_(.*?)_/g, "<em>1</em>")

            .replace(/\`\`\`([\s\S]*?)\`\`\`/g, "<pre><code>$1</code></pre>")
            .replace(/`(.*?)`/g, "<code>$1</code>")

            .replace(
                /\[([^\]]+)\]$$([^)]+)$$/g,
                '<a href="$2" target="_blank" rel="noopener noreferrer" class="chat-link">$1 <i class="fas fa-external-link-alt"></i></a>'
            )

            .replace(
                /(https?:\/\/[^\s<>"{}|\\^`[\]]+)/g,
                '<a href="$1" target="_blank" rel="noopener noreferrer" class="chat-link auto-link">$1 <i class="fas fa-external-link-alt"></i></a>'
            )
            .replace(
                /(?<!https?:\/\/)(www\.[^\s<>"{}|\\^`[\]]+)/g,
                '<a href="https://$1" target="_blank" rel="noopener noreferrer" class="chat-link auto-link">$1 <i class="fas fa-external-link-alt"></i></a>'
            )

            .replace(
                /(\+84|0)([0-9]{9,10})/g,
                '<a href="tel:$1$2" class="chat-link phone-link"><i class="fas fa-phone"></i> $1$2</a>'
            )

            .replace(
                /([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/g,
                '<a href="mailto:$1" class="chat-link email-link"><i class="fas fa-envelope"></i> $1</a>'
            )

            .replace(/\n\n/g, "</p><p>")
            .replace(/\n/g, "<br>")

            .replace(/^\d+\.\s+(.*$)/gim, "<li>$1</li>")
            .replace(/^[\-\*\+]\s+(.*$)/gim, "<li>$1</li>")

            .replace(/^(?!<[h|l|p|d])/gm, "<p>")
            .replace(/(?<!>)$/gm, "</p>")

            .replace(/<p><\/p>/g, "")
            .replace(/<p>(<[h|l])/g, "$1")
            .replace(/(<\/[h|l][^>]*>)<\/p>/g, "$1")

            .replace(/(<li>.*<\/li>)/gs, function (match) {
                const isNumbered = /^\d+\./.test(
                    text.match(/^\d+\.\s+.*$/m)?.[0] || ""
                );
                const tag = isNumbered ? "ol" : "ul";
                return `<${tag}>${match}</${tag}>`;
            });

        html = html
            .replace(/<p><br>/g, "<p>")
            .replace(/<br><\/p>/g, "</p>")
            .replace(/(<\/[uo]l>)<\/p>/g, "$1")
            .replace(/<p>(<[uo]l>)/g, "$1");

        return html;
    }

    function handleLinkClicks(messageElement) {
        const links = messageElement.querySelectorAll(".chat-link");
        links.forEach((link) => {
            link.addEventListener("click", function (e) {
                this.style.transform = "scale(0.95)";
                setTimeout(() => {
                    this.style.transform = "scale(1)";
                }, 150);

                console.log("Link clicked:", this.href);

                if (
                    this.classList.contains("phone-link") &&
                    /Mobi|Android/i.test(navigator.userAgent)
                ) {
                    if (
                        !confirm("Bạn có muốn gọi điện thoại đến số này không?")
                    ) {
                        e.preventDefault();
                    }
                }
            });
        });
    }

    function appendMessage(sender, text) {
        const msgDiv = document.createElement("div");
        msgDiv.classList.add("message");

        const isUser = sender === "user";
        const messageClass = isUser ? "user-message" : "bot-message";
        const bubbleClass = isUser ? "user-bubble" : "bot-bubble";
        const avatarIcon = isUser ? "fas fa-user" : "fas fa-landmark";

        const formattedText = isUser ? text : formatMarkdown(text);

        msgDiv.innerHTML = `
            <div class="${messageClass}">
                <div class="message-avatar">
                    <i class="${avatarIcon}"></i>
                </div>
                <div class="message-content">
                    <div class="message-bubble ${bubbleClass}">
                        ${formattedText}
                    </div>
                    <div class="message-time">${getCurrentTime()}</div>
                </div>
            </div>
        `;

        chatBox.appendChild(msgDiv);

        if (!isUser) {
            handleLinkClicks(msgDiv);
        }

        chatBox.scrollTop = chatBox.scrollHeight;

        if (sender === "user") {
            quickActions.style.display = "none";
        }

        addToHistory(sender, text);
    }

    function showTypingIndicator() {
        typingIndicator.style.display = "flex";
        chatBox.scrollTop = chatBox.scrollHeight;
    }

    function hideTypingIndicator() {
        typingIndicator.style.display = "none";
    }

    function setLoadingState(isLoading) {
        if (isLoading) {
            sendButton.disabled = true;
            sendButton.innerHTML = '<i class="fas fa-spinner fa-spin"></i>';
            chatForm.classList.add("loading");
        } else {
            sendButton.disabled = false;
            sendButton.innerHTML = '<i class="fas fa-paper-plane"></i>';
            chatForm.classList.remove("loading");
        }
    }

    function sendMessage(message) {
        if (!message.trim()) return;

        // Add user message
        appendMessage("user", message);
        userInput.value = "";

        // Show loading state
        setLoadingState(true);
        showTypingIndicator();

        setTimeout(() => {
            fetch("http://localhost:8000/api/chat", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    query: message,
                    chat_history: getChatHistoryForAPI(),
                }),
            })
                .then((res) => res.json())
                .then((data) => {
                    hideTypingIndicator();
                    setLoadingState(false);

                    if (data.answer) {
                        appendMessage("bot", data.answer);
                    } else {
                        appendMessage(
                            "bot",
                            "Xin lỗi, tôi không thể trả lời câu hỏi này lúc này. Vui lòng thử lại sau hoặc liên hệ với bộ phận hỗ trợ kỹ thuật."
                        );
                    }
                })
                .catch(() => {
                    hideTypingIndicator();
                    setLoadingState(false);
                    appendMessage(
                        "bot",
                        "Không thể kết nối tới máy chủ. Vui lòng kiểm tra kết nối internet và thử lại."
                    );
                });
        }, 800);
    }

    chatForm.addEventListener("submit", function (e) {
        e.preventDefault();
        const query = userInput.value.trim();
        sendMessage(query);
    });

    quickActions.addEventListener("click", function (e) {
        const quickActionItem = e.target.closest(".quick-action-item");
        if (quickActionItem) {
            const message = quickActionItem.getAttribute("data-message");
            sendMessage(message);
        }
    });

    document
        .querySelector(".header-actions")
        .addEventListener("click", function (e) {
            const btn = e.target.closest(".action-btn");
            if (btn) {
                const icon = btn.querySelector("i");
                if (icon.classList.contains("fa-refresh")) {
                    clearChatHistory();
                    location.reload();
                } else if (icon.classList.contains("fa-headset")) {
                    appendMessage(
                        "bot",
                        "Bạn có thể liên hệ hỗ trợ qua số hotline: 18008798 hoặc email: dichvaccong@thongtin.gov.vn"
                    );
                }
            }
        });

    userInput.focus();

    userInput.addEventListener("keypress", function (e) {
        if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault();
            chatForm.dispatchEvent(new Event("submit"));
        }
    });

    userInput.addEventListener("input", function () {
        this.style.height = "auto";
        this.style.height = Math.min(this.scrollHeight, 120) + "px";
    });

    document
        .querySelector(".attachment-btn")
        .addEventListener("click", function () {
            appendMessage(
                "bot",
                "Tính năng đính kèm file sẽ được hỗ trợ trong phiên bản tiếp theo. Hiện tại bạn có thể upload file trực tiếp tại Cổng Dịch vụ công Quốc gia."
            );
        });

    document.querySelector(".emoji-btn").addEventListener("click", function () {
        appendMessage(
            "bot",
            "Tính năng emoji sẽ được cập nhật trong đợt nâng cấp sắp tới. Cảm ơn bạn đã quan tâm đến dịch vụ công."
        );
    });

    function smoothScrollToBottom() {
        chatBox.scrollTo({
            top: chatBox.scrollHeight,
            behavior: "smooth",
        });
    }

    const originalAppendMessage = appendMessage;
    appendMessage = function (sender, text) {
        originalAppendMessage(sender, text);
        setTimeout(smoothScrollToBottom, 100);
    };
});
