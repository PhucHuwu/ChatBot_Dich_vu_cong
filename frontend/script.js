document.addEventListener("DOMContentLoaded", function () {
    const chatForm = document.getElementById("chat-form");
    const userInput = document.getElementById("user-input");
    const chatBox = document.getElementById("chat-box");
    const sendButton = document.getElementById("send-button");
    const typingIndicator = document.getElementById("typing-indicator");
    const quickActions = document.getElementById("quick-actions");
    
    // Sidebar elements
    const sidebar = document.getElementById("sidebar");
    const sidebarToggle = document.getElementById("sidebar-toggle");
    const sidebarClose = document.getElementById("sidebar-close");
    const sidebarOverlay = document.getElementById("sidebar-overlay");
    const newChatBtn = document.getElementById("new-chat-btn");
    const conversationsList = document.getElementById("conversations-list");
    
    // Theme toggle
    const themeToggle = document.getElementById("theme-toggle");
    
    // Sidebar action buttons
    const sidebarThemeToggle = document.getElementById("sidebar-theme-toggle");
    const sidebarSupportBtn = document.getElementById("sidebar-support-btn");
    
    // Scroll to bottom button
    const scrollToBottomBtn = document.getElementById("scroll-to-bottom");

    let chatHistory = [];
    const MAX_HISTORY_LENGTH = CONFIG.MAX_HISTORY_LENGTH || 10;
    
    // Conversation management
    let conversations = {};
    let currentConversationId = null;
    
    // ========== Theme Management ==========
    
    function loadTheme() {
        const savedTheme = localStorage.getItem('chatbot_theme');
        if (savedTheme === 'dark') {
            document.body.classList.add('dark-mode');
            updateThemeIcon(true);
        } else {
            document.body.classList.remove('dark-mode');
            updateThemeIcon(false);
        }
    }
    
    function toggleTheme() {
        const isDark = document.body.classList.toggle('dark-mode');
        localStorage.setItem('chatbot_theme', isDark ? 'dark' : 'light');
        updateThemeIcon(isDark);
    }
    
    function updateThemeIcon(isDark) {
        // Update header theme toggle
        const icon = themeToggle.querySelector('i');
        if (isDark) {
            icon.classList.remove('fa-moon');
            icon.classList.add('fa-sun');
            themeToggle.title = 'Chuyển sang chế độ sáng';
        } else {
            icon.classList.remove('fa-sun');
            icon.classList.add('fa-moon');
            themeToggle.title = 'Chuyển sang chế độ tối';
        }
        
        // Update sidebar theme toggle
        if (sidebarThemeToggle) {
            const sidebarIcon = sidebarThemeToggle.querySelector('i');
            if (isDark) {
                sidebarIcon.classList.remove('fa-moon');
                sidebarIcon.classList.add('fa-sun');
                sidebarThemeToggle.title = 'Chuyển sang chế độ sáng';
            } else {
                sidebarIcon.classList.remove('fa-sun');
                sidebarIcon.classList.add('fa-moon');
                sidebarThemeToggle.title = 'Chuyển sang chế độ tối';
            }
        }
    }
    
    // Load theme on page load
    loadTheme();
    
    // Theme toggle event listener
    themeToggle.addEventListener('click', toggleTheme);

    if (typeof marked !== "undefined") {
        marked.setOptions({
            breaks: true,
            gfm: true,
            headerIds: true,
            mangle: false,
            sanitize: false,
        });

        const renderer = new marked.Renderer();

        renderer.link = function (href, title, text) {
            const isExternal =
                href.startsWith("http") || href.startsWith("www");
            const actualHref = href.startsWith("www")
                ? "https://" + href
                : href;
            const titleAttr = title ? ` title="${title}"` : "";

            if (isExternal) {
                return `<a href="${actualHref}" target="_blank" rel="noopener noreferrer" class="chat-link"${titleAttr}>${text} <i class="fas fa-external-link-alt"></i></a>`;
            }
            return `<a href="${actualHref}" class="chat-link"${titleAttr}>${text}</a>`;
        };

        renderer.code = function (code, language) {
            const langClass = language ? ` class="language-${language}"` : "";
            return `<pre><code${langClass}>${escapeHtml(code)}</code></pre>`;
        };

        renderer.codespan = function (code) {
            return `<code>${escapeHtml(code)}</code>`;
        };

        renderer.table = function (header, body) {
            return `<div class="markdown-table-wrapper">
                <table class="markdown-table">
                    <thead>${header}</thead>
                    <tbody>${body}</tbody>
                </table>
            </div>`;
        };

        renderer.blockquote = function (quote) {
            return `<blockquote class="markdown-blockquote">${quote}</blockquote>`;
        };

        renderer.image = function (href, title, text) {
            const titleAttr = title ? ` title="${title}"` : "";
            const altAttr = text ? ` alt="${text}"` : "";
            return `<img src="${href}"${altAttr}${titleAttr} class="markdown-image" loading="lazy">`;
        };

        renderer.hr = function () {
            return '<hr class="markdown-hr">';
        };

        marked.setOptions({ renderer: renderer });
    }

    function escapeHtml(text) {
        const map = {
            "&": "&amp;",
            "<": "&lt;",
            ">": "&gt;",
            '"': "&quot;",
            "'": "&#039;",
        };
        return text.replace(/[&<>"']/g, (m) => map[m]);
    }

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
        if (!text) return "";

        try {
            if (typeof marked !== "undefined") {
                let html = marked.parse(text);

                if (typeof DOMPurify !== "undefined") {
                    html = DOMPurify.sanitize(html, {
                        ALLOWED_TAGS: [
                            "h1",
                            "h2",
                            "h3",
                            "h4",
                            "h5",
                            "h6",
                            "p",
                            "br",
                            "hr",
                            "strong",
                            "em",
                            "u",
                            "s",
                            "del",
                            "mark",
                            "a",
                            "code",
                            "pre",
                            "ul",
                            "ol",
                            "li",
                            "table",
                            "thead",
                            "tbody",
                            "tr",
                            "th",
                            "td",
                            "blockquote",
                            "div",
                            "span",
                            "img",
                            "i",
                        ],
                        ALLOWED_ATTR: [
                            "href",
                            "title",
                            "target",
                            "rel",
                            "class",
                            "src",
                            "alt",
                            "loading",
                        ],
                    });
                }

                html = enhanceLinks(html);

                return html;
            }

            return fallbackMarkdown(text);
        } catch (error) {
            console.error("Error parsing markdown:", error);
            return fallbackMarkdown(text);
        }
    }

    function enhanceLinks(html) {
        const temp = document.createElement("div");
        temp.innerHTML = html;

        const links = temp.querySelectorAll("a:not(.chat-link)");
        links.forEach((link) => {
            const href = link.getAttribute("href");

            if (href && href.startsWith("tel:")) {
                link.classList.add("chat-link", "phone-link");
                const icon = document.createElement("i");
                icon.className = "fas fa-phone";
                link.insertBefore(icon, link.firstChild);
                link.insertBefore(
                    document.createTextNode(" "),
                    icon.nextSibling
                );
            } else if (href && href.startsWith("mailto:")) {
                link.classList.add("chat-link", "email-link");
                const icon = document.createElement("i");
                icon.className = "fas fa-envelope";
                link.insertBefore(icon, link.firstChild);
                link.insertBefore(
                    document.createTextNode(" "),
                    icon.nextSibling
                );
            }
        });

        const walker = document.createTreeWalker(
            temp,
            NodeFilter.SHOW_TEXT,
            null,
            false
        );

        const textNodes = [];
        let node;
        while ((node = walker.nextNode())) {
            textNodes.push(node);
        }

        textNodes.forEach((textNode) => {
            if (
                textNode.parentElement.tagName === "A" ||
                textNode.parentElement.tagName === "CODE" ||
                textNode.parentElement.tagName === "PRE"
            ) {
                return;
            }

            let text = textNode.textContent;

            const phoneRegex = /(\+84|0)([0-9]{9,10})\b/g;
            if (phoneRegex.test(text)) {
                const span = document.createElement("span");
                span.innerHTML = text.replace(
                    phoneRegex,
                    '<a href="tel:$1$2" class="chat-link phone-link"><i class="fas fa-phone"></i> $1$2</a>'
                );
                textNode.parentNode.replaceChild(span, textNode);

                if (
                    span.childNodes.length === 1 &&
                    span.firstChild.nodeType === 1
                ) {
                    span.parentNode.replaceChild(span.firstChild, span);
                } else {
                    while (span.firstChild) {
                        span.parentNode.insertBefore(span.firstChild, span);
                    }
                    span.parentNode.removeChild(span);
                }
            }

            const emailRegex =
                /\b([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})\b/g;
            text = textNode.textContent;
            if (emailRegex.test(text)) {
                const span = document.createElement("span");
                span.innerHTML = text.replace(
                    emailRegex,
                    '<a href="mailto:$1" class="chat-link email-link"><i class="fas fa-envelope"></i> $1</a>'
                );
                textNode.parentNode.replaceChild(span, textNode);

                while (span.firstChild) {
                    span.parentNode.insertBefore(span.firstChild, span);
                }
                span.parentNode.removeChild(span);
            }
        });

        return temp.innerHTML;
    }

    function fallbackMarkdown(text) {
        let html = text
            .replace(/^### (.*$)/gim, "<h3>$1</h3>")
            .replace(/^## (.*$)/gim, "<h2>$1</h2>")
            .replace(/^# (.*$)/gim, "<h1>$1</h1>")

            .replace(/\*\*(.*?)\*\*/g, "<strong>$1</strong>")
            .replace(/__(.*?)__/g, "<strong>$1</strong>")

            .replace(/\*(.*?)\*/g, "<em>$1</em>")
            .replace(/_(.*?)_/g, "<em>$1</em>")

            .replace(/```([\s\S]*?)```/g, "<pre><code>$1</code></pre>")
            .replace(/`(.*?)`/g, "<code>$1</code>")

            .replace(
                /\[([^\]]+)\]\(([^)]+)\)/g,
                '<a href="$2" target="_blank" rel="noopener noreferrer" class="chat-link">$1 <i class="fas fa-external-link-alt"></i></a>'
            )

            .replace(/\n\n/g, "</p><p>")
            .replace(/\n/g, "<br>")

            .replace(/^(?!<[h|p])/gm, "<p>")
            .replace(/(?<!>)$/gm, "</p>")
            .replace(/<p><\/p>/g, "");

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

    function appendMessageToConversation(targetConvId, sender, text) {
        // Thêm message vào conversation target
        if (!targetConvId || !conversations[targetConvId]) {
            console.error('Target conversation not found:', targetConvId);
            return;
        }

        const messageData = {
            sender: sender,
            message: text,
            timestamp: new Date().toISOString()
        };

        // Thêm vào conversation data
        conversations[targetConvId].messages.push(messageData);
        conversations[targetConvId].updatedAt = new Date().toISOString();

        // Cập nhật title nếu là tin nhắn user đầu tiên
        if (sender === 'user' && conversations[targetConvId].messages.filter(m => m.sender === 'user').length === 1) {
            const title = text.substring(0, 30) + (text.length > 30 ? '...' : '');
            conversations[targetConvId].title = title;
        }

        // Nếu đang xem conversation này, hiển thị message
        if (currentConversationId === targetConvId) {
            chatHistory.push(messageData);
            
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

            updateHistoryIndicator();
        }

        // Lưu vào localStorage và update danh sách
        saveConversations();
        renderConversationsList();
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

        // Lưu lại conversation ID và history tại thời điểm gửi message
        const targetConversationId = currentConversationId;
        const contextHistory = getChatHistoryForAPI();

        appendMessageToConversation(targetConversationId, "user", message);
        userInput.value = "";

        setLoadingState(true);
        showTypingIndicator();

        setTimeout(() => {
            fetch(CONFIG.getApiUrl("CHAT"), {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    query: message,
                    chat_history: contextHistory,
                }),
            })
                .then((res) => res.json())
                .then((data) => {
                    hideTypingIndicator();
                    setLoadingState(false);

                    if (data.answer) {
                        // Thêm response vào đúng conversation đã gửi
                        appendMessageToConversation(targetConversationId, "bot", data.answer);
                    } else {
                        appendMessageToConversation(
                            targetConversationId,
                            "bot",
                            "Xin lỗi, tôi không thể trả lời câu hỏi này lúc này. Vui lòng thử lại sau hoặc liên hệ với bộ phận hỗ trợ kỹ thuật."
                        );
                    }
                })
                .catch(() => {
                    hideTypingIndicator();
                    setLoadingState(false);
                    appendMessageToConversation(
                        targetConversationId,
                        "bot",
                        "Không thể kết nối tới máy chủ. Vui lòng kiểm tra kết nối internet và thử lại."
                    );
                });
        }, CONFIG.TYPING_DELAY || 800);
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
                if (icon.classList.contains("fa-headset")) {
                    appendMessage(
                        "bot",
                        `Bạn có thể liên hệ hỗ trợ qua số hotline: ${CONFIG.SUPPORT.HOTLINE} hoặc email: ${CONFIG.SUPPORT.EMAIL}`
                    );
                }
            }
        });

    // Sidebar action buttons event listeners
    if (sidebarThemeToggle) {
        sidebarThemeToggle.addEventListener("click", toggleTheme);
    }
    
    if (sidebarSupportBtn) {
        sidebarSupportBtn.addEventListener("click", function () {
            appendMessage(
                "bot",
                `Bạn có thể liên hệ hỗ trợ qua số hotline: ${CONFIG.SUPPORT.HOTLINE} hoặc email: ${CONFIG.SUPPORT.EMAIL}`
            );
            closeSidebar();
        });
    }

    // ========== Conversation Management Functions ==========
    
    function loadConversations() {
        try {
            const saved = localStorage.getItem('chatbot_conversations');
            if (saved) {
                conversations = JSON.parse(saved);
            }
            const currentId = localStorage.getItem('chatbot_current_conversation');
            if (currentId && conversations[currentId]) {
                currentConversationId = currentId;
                loadConversation(currentId, false); // false = don't save previous conversation
            } else {
                createNewConversation();
            }
        } catch (error) {
            console.error('Error loading conversations:', error);
            createNewConversation();
        }
        renderConversationsList();
    }
    
    function saveConversations() {
        try {
            localStorage.setItem('chatbot_conversations', JSON.stringify(conversations));
            if (currentConversationId) {
                localStorage.setItem('chatbot_current_conversation', currentConversationId);
            }
        } catch (error) {
            console.error('Error saving conversations:', error);
        }
    }
    
    function createNewConversation() {
        saveCurrentConversation();
        
        const id = 'conv_' + Date.now();
        const now = new Date();
        conversations[id] = {
            id: id,
            title: 'Đoạn chat mới',
            messages: [],
            createdAt: now.toISOString(),
            updatedAt: now.toISOString()
        };
        
        currentConversationId = id;
        chatHistory = [];
        
        chatBox.innerHTML = `
            <div class="welcome-message">
                <div class="bot-message">
                    <div class="message-avatar">
                        <i class="fas fa-landmark"></i>
                    </div>
                    <div class="message-content">
                        <div class="message-bubble bot-bubble">
                            <div class="welcome-text">
                                <h4>🇻🇳 Xin chào! Chào mừng đến với Chatbot Dịch vụ công</h4>
                                <p>Tôi là chatbot hỗ trợ, có thể giúp bạn:</p>
                                <ul>
                                    <li>Hướng dẫn thủ tục hành chính</li>
                                    <li>Hướng dẫn đăng ký tài khoản công dân/doanh nghiệp</li>
                                    <li>Hướng dẫn thanh toán điện nước, giáo dục</li>
                                    <li>Giải đáp thắc mắc về dịch vụ công</li>
                                </ul>
                                <p>Bạn cần hỗ trợ gì về dịch vụ công?</p>
                            </div>
                        </div>
                        <span class="message-time">Vừa xong</span>
                    </div>
                </div>
            </div>
        `;
        
        quickActions.style.display = 'flex';
        updateHistoryIndicator();
        saveConversations();
        renderConversationsList();
        closeSidebar();
    }
    
    function saveCurrentConversation(updateTime = false) {
        if (currentConversationId && conversations[currentConversationId]) {
            conversations[currentConversationId].messages = chatHistory.slice();
            
            if (updateTime) {
                conversations[currentConversationId].updatedAt = new Date().toISOString();
            }
            
            if (chatHistory.length > 0) {
                const firstUserMessage = chatHistory.find(msg => msg.sender === 'user');
                if (firstUserMessage) {
                    const title = firstUserMessage.message.substring(0, 30) + 
                                 (firstUserMessage.message.length > 30 ? '...' : '');
                    conversations[currentConversationId].title = title;
                }
            }
        }
    }
    
    function loadConversation(id, savePrevious = true) {
        // Only save previous conversation if switching between conversations, not on initial load
        if (savePrevious) {
            saveCurrentConversation();
        }
        
        if (!conversations[id]) return;
        
        currentConversationId = id;
        const conversation = conversations[id];
        chatHistory = conversation.messages.slice();
        
        chatBox.innerHTML = '';
        
        if (chatHistory.length === 0) {
            chatBox.innerHTML = `
                <div class="welcome-message">
                    <div class="bot-message">
                        <div class="message-avatar">
                            <i class="fas fa-landmark"></i>
                        </div>
                        <div class="message-content">
                            <div class="message-bubble bot-bubble">
                                <div class="welcome-text">
                                    <h4>🇻🇳 Xin chào! Chào mừng đến với Chatbot Dịch vụ công</h4>
                                    <p>Tôi là chatbot hỗ trợ, có thể giúp bạn:</p>
                                    <ul>
                                        <li>Hướng dẫn thủ tục hành chính</li>
                                        <li>Hướng dẫn đăng ký tài khoản công dân/doanh nghiệp</li>
                                        <li>Hướng dẫn thanh toán điện nước, giáo dục</li>
                                        <li>Giải đáp thắc mắc về dịch vụ công</li>
                                    </ul>
                                    <p>Bạn cần hỗ trợ gì về dịch vụ công?</p>
                                </div>
                            </div>
                            <span class="message-time">Vừa xong</span>
                        </div>
                    </div>
                </div>
            `;
            quickActions.style.display = 'flex';
        } else {
            chatHistory.forEach(msg => {
                const msgDiv = document.createElement("div");
                msgDiv.classList.add("message");
                
                const isUser = msg.sender === "user";
                const messageClass = isUser ? "user-message" : "bot-message";
                const bubbleClass = isUser ? "user-bubble" : "bot-bubble";
                const avatarIcon = isUser ? "fas fa-user" : "fas fa-landmark";
                
                const formattedText = isUser ? msg.message : formatMarkdown(msg.message);
                const msgTime = msg.timestamp ? new Date(msg.timestamp).toLocaleTimeString("vi-VN", {
                    hour: "2-digit",
                    minute: "2-digit",
                }) : getCurrentTime();
                
                msgDiv.innerHTML = `
                    <div class="${messageClass}">
                        <div class="message-avatar">
                            <i class="${avatarIcon}"></i>
                        </div>
                        <div class="message-content">
                            <div class="message-bubble ${bubbleClass}">
                                ${formattedText}
                            </div>
                            <div class="message-time">${msgTime}</div>
                        </div>
                    </div>
                `;
                
                chatBox.appendChild(msgDiv);
                
                if (!isUser) {
                    handleLinkClicks(msgDiv);
                }
            });
            quickActions.style.display = 'none';
        }
        
        updateHistoryIndicator();
        saveConversations();
        renderConversationsList();
        chatBox.scrollTop = chatBox.scrollHeight;
        closeSidebar();
    }
    
    function deleteConversation(id, event) {
        if (event) {
            event.stopPropagation();
        }
        
        if (!confirm('Bạn có chắc muốn xóa đoạn chat này?')) {
            return;
        }
        
        delete conversations[id];
        
        if (currentConversationId === id) {
            const conversationIds = Object.keys(conversations);
            if (conversationIds.length > 0) {
                loadConversation(conversationIds[0]);
            } else {
                createNewConversation();
            }
        }
        
        saveConversations();
        renderConversationsList();
    }
    
    function renderConversationsList() {
        const conversationIds = Object.keys(conversations).sort((a, b) => {
            return new Date(conversations[b].updatedAt) - new Date(conversations[a].updatedAt);
        });
        
        if (conversationIds.length === 0) {
            conversationsList.innerHTML = `
                <div class="empty-conversations">
                    <i class="fas fa-comments"></i>
                    <p>Chưa có đoạn chat nào.<br>Nhấn "Đoạn chat mới" để bắt đầu!</p>
                </div>
            `;
            return;
        }
        
        conversationsList.innerHTML = '';
        
        conversationIds.forEach(id => {
            const conv = conversations[id];
            const isActive = id === currentConversationId;
            
            const lastMessage = conv.messages.length > 0 
                ? conv.messages[conv.messages.length - 1].message.substring(0, 40) + '...'
                : 'Chưa có tin nhắn';
            
            const timeAgo = getTimeAgo(new Date(conv.updatedAt));
            
            const item = document.createElement('div');
            item.className = 'conversation-item' + (isActive ? ' active' : '');
            item.innerHTML = `
                <div class="conversation-content">
                    <div class="conversation-title">${conv.title}</div>
                    <div class="conversation-preview">${lastMessage}</div>
                </div>
                <div class="conversation-time">${timeAgo}</div>
                <button class="conversation-delete" title="Xóa đoạn chat">
                    <i class="fas fa-trash"></i>
                </button>
            `;
            
            item.addEventListener('click', () => loadConversation(id));
            
            const deleteBtn = item.querySelector('.conversation-delete');
            deleteBtn.addEventListener('click', (e) => deleteConversation(id, e));
            
            conversationsList.appendChild(item);
        });
    }
    
    function getTimeAgo(date) {
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);
        
        if (diffMins < 1) return 'Vừa xong';
        if (diffMins < 60) return `${diffMins} phút`;
        if (diffHours < 24) return `${diffHours} giờ`;
        if (diffDays < 7) return `${diffDays} ngày`;
        return date.toLocaleDateString('vi-VN');
    }
    
    function toggleSidebar() {
        sidebar.classList.toggle('active');
        sidebarOverlay.classList.toggle('active');
    }
    
    function closeSidebar() {
        sidebar.classList.remove('active');
        sidebarOverlay.classList.remove('active');
    }
    
    // Sidebar event listeners
    sidebarToggle.addEventListener('click', toggleSidebar);
    sidebarClose.addEventListener('click', closeSidebar);
    sidebarOverlay.addEventListener('click', closeSidebar);
    newChatBtn.addEventListener('click', createNewConversation);
    
    // Auto-save conversation on message send
    const originalAppendMessage = appendMessage;
    appendMessage = function(sender, text) {
        originalAppendMessage(sender, text);
        setTimeout(smoothScrollToBottom, 100);
        if (currentConversationId) {
            saveCurrentConversation(true); // Update time when new message is added
            saveConversations();
            renderConversationsList();
        }
    };
    
    function smoothScrollToBottom() {
        chatBox.scrollTo({
            top: chatBox.scrollHeight,
            behavior: "smooth",
        });
        // Hide scroll to bottom button after scrolling
        setTimeout(() => {
            updateScrollButton();
        }, 500);
    }
    
    // Initialize conversations
    loadConversations();

    // ========== Scroll to Bottom Button ==========
    
    // Check if user is at bottom of chat
    function isAtBottom() {
        const threshold = 100; // pixels from bottom
        return chatBox.scrollHeight - chatBox.scrollTop - chatBox.clientHeight < threshold;
    }
    
    // Show/hide scroll to bottom button
    function updateScrollButton() {
        if (isAtBottom()) {
            scrollToBottomBtn.style.display = 'none';
        } else {
            scrollToBottomBtn.style.display = 'flex';
        }
    }
    
    // Scroll to bottom smoothly
    function scrollToBottom() {
        chatBox.scrollTo({
            top: chatBox.scrollHeight,
            behavior: 'smooth'
        });
    }
    
    // Listen to scroll events on chat box
    chatBox.addEventListener('scroll', updateScrollButton);
    
    // Click event for scroll to bottom button
    scrollToBottomBtn.addEventListener('click', scrollToBottom);
    
    // Initial check
    updateScrollButton();

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
                "Tính năng đính kèm file sẽ được hỗ trợ trong phiên bản tiếp theo."
            );
        });
});
