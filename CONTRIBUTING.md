# Contributing to Vietnamese Public Service Chatbot

Thank you for your interest in contributing! We welcome all contributions and are grateful for your support.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Getting Help](#getting-help)

## Code of Conduct

This project adheres to the [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to maintain a respectful and inclusive environment.

## How to Contribute

### Reporting Bugs

Before creating a bug report, please check existing issues to avoid duplicates. Include:

- Clear title and description
- Steps to reproduce the issue
- Expected vs actual behavior
- Environment details (OS, Python version)
- Logs and error messages (set `LOG_LEVEL=DEBUG`)
- Screenshots if applicable

### Suggesting Features

We welcome feature suggestions! Please include:

- Clear description of the proposed feature
- Use case explaining why it would be useful
- Implementation ideas if you have any
- Potential impact on existing functionality

### Code Contributions

We accept:

- Bug fixes
- New features
- Performance improvements
- Documentation updates
- Test coverage improvements

## Development Setup

### Prerequisites

- Python 3.10+ (3.12.3+ recommended)
- Git
- Docker (optional)
- GROQ API key from [console.groq.com](https://console.groq.com)

### Setup Instructions

1. **Fork and clone the repository**

```bash
git clone https://github.com/<your-username>/ChatBot_Dich_vu_cong.git
cd ChatBot_Dich_vu_cong
```

2. **Create and activate virtual environment**

```bash
python -m venv venv

# Linux/macOS
source venv/bin/activate

# Windows
venv\Scripts\activate
```

3. **Install dependencies**

```bash
pip install -r requirements-dev.txt
```

4. **Configure environment variables**

```bash
cp .env.example .env
# Edit .env and set your GROQ_API_KEY
```

5. **Build vector index**

```bash
python -c "from rag import build_index; build_index()"
```

6. **Run the development server**

```bash
uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

7. **Verify installation**

Visit http://localhost:8000/health to ensure the server is running.

## Coding Standards

### Python Style Guide

Follow [PEP 8](https://pep8.org/) guidelines:

- **Line length**: Maximum 88 characters
- **Indentation**: 4 spaces
- **Naming**:
  - `snake_case` for functions and variables
  - `PascalCase` for classes
  - `UPPER_CASE` for constants
- **Type hints**: Required for new functions

### Code Quality Tools

Format code with **Black**:

```bash
black .
```

Run **Flake8** linter:

```bash
flake8 --max-line-length=88 --extend-ignore=E203,W503
```

Type check with **mypy**:

```bash
mypy --ignore-missing-imports .
```

### Documentation

Use Google-style docstrings:

```python
def search_contexts(query: str, k: int = 10) -> List[Dict[str, Any]]:
    """
    Search for relevant contexts using vector similarity.

    Args:
        query: User's search query
        k: Number of results to return

    Returns:
        List of context dictionaries

    Raises:
        ValueError: If query is empty or k is non-positive
    """
    pass
```

Comment guidelines:

- Prefer self-documenting code
- Comment complex logic only
- Keep comments up-to-date

### Best Practices

#### Configuration

- Never hardcode API keys or secrets
- Use environment variables via `config.py`
- Add new configs to `.env.example`
- Validate critical configurations

#### Error Handling

```python
# Good
try:
    result = call_api()
except APITimeoutError as e:
    logger.error(f"API timeout: {e}", extra={"trace_id": trace_id})
    return fallback_response()

# Bad
try:
    result = call_api()
except:
    pass
```

#### Logging

```python
from logger_utils import get_logger

logger = get_logger(__name__)

logger.info(
    "Query processed",
    extra={"trace_id": trace_id, "duration_ms": duration}
)
```

#### Security

- No secrets in logs or error messages
- Validate all inputs
- Sanitize user data
- Review `git diff` before commits

## Testing

### Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=. --cov-report=html

# Run specific test
pytest tests/test_api.py -v
```

### Writing Tests

Place tests in `tests/` directory with `test_` prefix:

```python
import pytest
from fastapi.testclient import TestClient
from app import app

@pytest.fixture
def client():
    return TestClient(app)

def test_chat_endpoint(client):
    response = client.post(
        "/api/chat",
        json={"query": "Thủ tục đăng ký kết hôn?", "chat_history": []}
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert len(data["answer"]) > 0
```

### Coverage Requirements

- Minimum: 70% overall
- New code: 80%+
- Critical paths: 90%+

## Pull Request Process

### Workflow

1. **Create a feature branch**

```bash
git checkout -b feature/your-feature-name
```

2. **Make your changes** following coding standards

3. **Write/update tests**

4. **Run tests and linters**

```bash
pytest
black .
flake8
```

5. **Commit with clear messages** (see [Conventional Commits](https://www.conventionalcommits.org/))

```bash
git commit -m "feat: add Vietnamese accent normalization"
git commit -m "fix: correct FAISS index dimension mismatch"
```

### Commit Message Guidelines

Use conventional commits format:

```
<type>: <subject>
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`

**Example:**

```
feat: add semantic chunking for long documents

Implement recursive chunking with overlap to improve
context retrieval for long documents.

Closes #123
```

### Pull Request Checklist

Include in your PR description:

- **Description**: Brief summary of changes
- **Type**: Bug fix / Feature / Documentation / Other
- **Testing**: All tests pass, new tests added
- **Code Quality**: Follows style guide, self-reviewed
- **Security**: No secrets committed, inputs validated
- **Related Issues**: Closes #123, Fixes #456

### Review Process

1. Automated checks must pass
2. Code review by maintainer
3. Approval required before merge
4. Squash and merge preferred

## Getting Help

- **Documentation**: See [README.md](README.md)
- **Issues**: Search [existing issues](https://github.com/PhucHuwu/ChatBot_Dich_vu_cong/issues)
- **Discussions**: Use [GitHub Discussions](https://github.com/PhucHuwu/ChatBot_Dich_vu_cong/discussions)

### Bug Report Template

When reporting bugs, include:

- Clear description
- Steps to reproduce
- Expected vs actual behavior
- Environment (OS, Python version)
- Logs (set `LOG_LEVEL=DEBUG`)
- Screenshots if applicable

### Feature Request Template

When requesting features, include:

- Clear description
- Use case
- Proposed solution
- Alternatives considered

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).

---

**Thank you for contributing to the Vietnamese Public Service Chatbot!**
