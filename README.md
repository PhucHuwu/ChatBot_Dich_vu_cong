# National Public Service Portal - AI Chatbot

A comprehensive AI-powered chatbot system designed to assist citizens with public services and administrative procedures in Vietnam. This system uses Retrieval-Augmented Generation (RAG) technology to provide accurate, contextual answers based on official FAQ data and government guidelines.

## Features

-   **Intelligent Q&A System**: Powered by advanced RAG technology using FAISS vector search
-   **Multilingual Support**: Optimized for Vietnamese language processing
-   **Real-time Chat Interface**: Modern, responsive web interface with chat history
-   **Contextual Understanding**: Maintains conversation context for better responses
-   **Source Attribution**: Provides sources and references for all answers
-   **GPU Acceleration**: Supports CUDA for faster processing when available
-   **RESTful API**: Complete FastAPI backend with comprehensive documentation
-   **Auto-indexing**: Automatic embedding generation and vector index building

## Architecture

### Backend Components

-   **FastAPI Server** (`app.py`): Main API server with endpoints for chat, status, and indexing
-   **RAG Engine** (`rag.py`): Core retrieval and generation logic using Groq LLM
-   **Embedding Service** (`embedding.py`): Sentence transformer for multilingual embeddings
-   **Data Processing** (`chunking.py`): Text chunking and preprocessing utilities

### Frontend Components

-   **Modern Web Interface**: Responsive HTML/CSS/JavaScript frontend
-   **Real-time Chat**: Interactive chat interface with message history
-   **Status Monitoring**: System health and indexing status display
-   **Suggestion System**: Pre-defined question suggestions for users

### Data Sources

-   **FAQ Database** (`data/faq.json`): Comprehensive FAQ data from government portal
-   **Guide Documentation** (`data/guide.json`): Official procedural guides and instructions

## Prerequisites

-   Python 3.8 or higher
-   CUDA-compatible GPU (optional, for faster processing)
-   Groq API key for LLM access

## Installation

1. **Clone the repository**

    ```bash
    git clone <repository-url>
    cd ChatBot_Dich_vu_cong
    ```

2. **Create virtual environment**

    ```bash
    python -m venv venv
    source venv/bin/activate  # On Windows: venv\Scripts\activate
    ```

3. **Install dependencies**

    ```bash
    pip install -r requirements.txt
    ```

4. **Set up environment variables**
   Create a `.env` file in the root directory:

    ```env
    api_key=your_groq_api_key_here
    ```

5. **Prepare data**
   Ensure the following data files are present:
    - `data/faq.json` - FAQ data
    - `data/guide.json` - Guide documentation

## Usage

### Starting the Server

```bash
python app.py
```

The server will start on `http://localhost:8000`

### Accessing the Application

-   **Web Interface**: Navigate to `http://localhost:8000`
-   **API Documentation**: Visit `http://localhost:8000/api/docs`
-   **Health Check**: `http://localhost:8000/health`

### Building the Vector Index

The system automatically builds the vector index on first use. You can also manually trigger index rebuilding:

```bash
curl -X POST http://localhost:8000/api/build
```

## API Endpoints

### Core Endpoints

-   `POST /api/chat` - Main chat endpoint for user queries
-   `GET /api/status` - System status and health information
-   `POST /api/build` - Manual index rebuilding
-   `GET /api/suggestions` - Get suggested questions

### Request/Response Examples

**Chat Request:**

```json
{
    "query": "How do I register for citizen services?",
    "chat_history": [
        {
            "role": "user",
            "content": "Previous question"
        },
        {
            "role": "assistant",
            "content": "Previous answer"
        }
    ]
}
```

**Chat Response:**

```json
{
  "query": "How do I register for citizen services?",
  "answer": "Detailed answer based on official sources...",
  "contexts": [...],
  "sources": [...],
  "success": true,
  "message": "Trả lời thành công"
}
```

## Configuration

### Model Configuration

-   **LLM Model**: `meta-llama/llama-4-scout-17b-16e-instruct` (Groq)
-   **Embedding Model**: `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2`
-   **Vector Search**: FAISS IndexFlatL2 with similarity threshold of 1.2

### Performance Tuning

-   **Batch Size**: Configurable embedding batch size (default: 32)
-   **Top-k Results**: Number of relevant documents retrieved (default: 10)
-   **Temperature**: LLM response creativity (default: 0.7)
-   **Max Tokens**: Maximum response length (default: 2048)

## Technical Details

### RAG Implementation

1. **Document Processing**: FAQ and guide data are chunked and processed
2. **Embedding Generation**: Multilingual sentence transformers create vector representations
3. **Vector Storage**: FAISS index enables fast similarity search
4. **Retrieval**: Query embedding searches for relevant documents
5. **Generation**: Groq LLM generates contextual responses based on retrieved information

### Performance Optimizations

-   **GPU Acceleration**: Automatic CUDA detection and utilization
-   **Batch Processing**: Efficient embedding generation in batches
-   **Caching**: Vector index persistence for faster startup
-   **Memory Management**: Optimized tensor operations and cleanup

## Security & Privacy

-   **API Key Protection**: Environment variable storage for sensitive credentials
-   **Input Validation**: Comprehensive request validation and sanitization
-   **Error Handling**: Graceful error handling with informative messages
-   **CORS Configuration**: Proper cross-origin resource sharing setup

## Testing

### Manual Testing

-   Use the web interface at `http://localhost:8000`
-   Test various question types and conversation flows
-   Verify source attribution and response quality

### API Testing

-   Use the interactive docs at `http://localhost:8000/api/docs`
-   Test endpoints with different parameters and edge cases
-   Monitor system status and performance metrics

## Deployment

### Local Development

```bash
python app.py
```

### Production Deployment

1. Set up proper environment variables
2. Configure reverse proxy (nginx/Apache)
3. Use production WSGI server (gunicorn)
4. Set up monitoring and logging
5. Configure SSL certificates

### Docker Deployment (Optional)

```dockerfile
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["python", "app.py"]
```

## Monitoring & Maintenance

### Health Monitoring

-   **System Status**: `/api/status` endpoint for health checks
-   **Index Status**: Monitor embedding index availability
-   **Performance Metrics**: Track response times and accuracy

### Data Updates

-   **FAQ Updates**: Replace `data/faq.json` with new data
-   **Guide Updates**: Update `data/guide.json` with new procedures
-   **Index Rebuilding**: Trigger `/api/build` after data updates

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Support

For technical support or questions:

-   Check the API documentation at `/api/docs`
-   Review system status at `/api/status`
-   Contact the development team for assistance

## Future Enhancements

-   **Multi-language Support**: Expand beyond Vietnamese
-   **Voice Interface**: Add speech-to-text and text-to-speech
-   **Advanced Analytics**: User interaction analytics and insights
-   **Integration**: Connect with official government APIs
-   **Mobile App**: Native mobile application development

---

**Note**: This chatbot is designed specifically for Vietnamese public services and administrative procedures. Ensure compliance with local regulations and data protection requirements when deploying in production environments.
