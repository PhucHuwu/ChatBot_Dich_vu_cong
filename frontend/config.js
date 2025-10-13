const CONFIG = {
    BASE_PATH: "",

    API_BASE_URL: "http://123.30.48.155:8000/",

    ENDPOINTS: {
        CHAT: "/api/chat",
        STATUS: "/api/status",
        HEALTH: "/health",
    },

    MAX_HISTORY_LENGTH: 10,

    TYPING_DELAY: 800,

    REQUEST_TIMEOUT: 30000,

    MAX_INPUT_HEIGHT: 120,

    ERROR_DISPLAY_DURATION: 5000,

    FEATURES: {
        MARKDOWN_SUPPORT: true,
        LINK_ENHANCEMENT: true,
        PHONE_AUTO_DETECT: true,
        EMAIL_AUTO_DETECT: true,
        CHAT_HISTORY: true,
    },

    SUPPORT: {
        HOTLINE: "18001096",
        EMAIL: "dichvucong@chinhphu.vn",
        WEBSITE: "https://dichvucong.gov.vn",
    },
};

CONFIG.getApiUrl = function (endpoint) {
    const path = this.ENDPOINTS[endpoint] || endpoint;
    const basePath = (this.BASE_PATH || "").replace(/\/+$/, "");
    return this.API_BASE_URL + basePath + path;
};

CONFIG.getEnvironment = function () {
    const hostname = window.location.hostname;
    return hostname === "localhost" || hostname === "127.0.0.1"
        ? "development"
        : "production";
};

CONFIG.isLocal = function () {
    return this.getEnvironment() === "development";
};

Object.freeze(CONFIG.ENDPOINTS);
Object.freeze(CONFIG.FEATURES);
Object.freeze(CONFIG.SUPPORT);
