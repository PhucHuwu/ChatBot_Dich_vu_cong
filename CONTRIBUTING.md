# Contributing to Vietnamese Public Service Chatbot

Thank you for your interest in contributing to the Vietnamese Public Service Chatbot! We welcome contributions from the community and are grateful for your support.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)
- [Community](#community)

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment:

- Be respectful of differing viewpoints and experiences
- Accept constructive criticism gracefully
- Focus on what is best for the community
- Show empathy towards other community members

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the issue
- **Expected vs actual behavior**
- **Environment details** (OS, Python version, dependencies)
- **Logs and error messages** (with `LOG_LEVEL=DEBUG`)
- **Screenshots** if applicable

### Suggesting Enhancements

Enhancement suggestions are welcome! Please include:

- **Clear description** of the proposed feature
- **Use case** explaining why this would be useful
- **Implementation ideas** if you have any
- **Impact assessment** on existing functionality

### Contributing Code

We accept the following types of contributions:

- **Bug fixes**
- **New features**
- **Performance improvements**
- **Documentation updates**
- **Test coverage improvements**
- **Code refactoring**

## Development Setup

### Prerequisites

- Python 3.10 or higher (3.12.3+ recommended)
- Git
- Docker (optional, for containerized development)
- GROQ API key from [console.groq.com](https://console.groq.com)

### Setting Up Development Environment

1. **Fork and Clone**

   ```bash
   git clone https://github.com/<your-username>/ChatBot_Dich_vu_cong.git
   cd ChatBot_Dich_vu_cong
   ```

2. **Create Virtual Environment**

   ```bash
   python -m venv venv
   
   # Linux/macOS
   source venv/bin/activate
   
   # Windows
   venv\Scripts\activate
   ```

3. **Install Dependencies**

   ```bash
   # Install all dependencies including dev tools
   pip install -r requirements-dev.txt
   ```

4. **Configure Environment**

   ```bash
   cp .env.example .env
   # Edit .env and set your GROQ_API_KEY and other configs
   ```

5. **Build Vector Index**

   ```bash
   python -c "from rag import build_index; build_index()"
   ```

6. **Run Development Server**

   ```bash
   uvicorn app:app --reload --host 0.0.0.0 --port 8000
   ```

7. **Verify Installation**

   Visit http://localhost:8000/health to ensure the server is running.

### Development Tools

Install recommended development tools:

```bash
pip install black flake8 pytest pytest-cov mypy
```

## Coding Standards

### Python Style Guide

Follow [PEP 8](https://pep8.org/) style guidelines:

- **Line length**: Maximum 88 characters (Black default)
- **Indentation**: 4 spaces (no tabs)
- **Naming conventions**:
  - `snake_case` for functions and variables
  - `PascalCase` for classes
  - `UPPER_CASE` for constants
- **Type hints**: Required for all new functions

### Code Formatting

Use **Black** for automatic formatting:

```bash
# Format all Python files
black .

# Check formatting without making changes
black --check .
```

### Linting

Use **Flake8** for code quality checks:

```bash
# Run linter
flake8 --max-line-length=88 --extend-ignore=E203,W503

# Configuration in .flake8 or setup.cfg
```

### Type Checking

Use **mypy** for static type checking:

```bash
mypy --ignore-missing-imports .
```

### Documentation Standards

#### Docstrings

Use Google-style docstrings for all public functions:

```python
def search_contexts(query: str, k: int = 10) -> List[Dict[str, Any]]:
    """
    Search for relevant contexts using vector similarity.

    Args:
        query: User's search query in natural language
        k: Number of top results to return

    Returns:
        List of context dictionaries containing text and metadata

    Raises:
        ValueError: If query is empty or k is non-positive
        RuntimeError: If FAISS index is not initialized

    Example:
        >>> results = search_contexts("Thủ tục đăng ký kết hôn?", k=5)
        >>> print(results[0]['text'])
    """
    pass
```

#### Comments

- Use comments sparingly; prefer self-documenting code
- Write comments for complex logic or non-obvious decisions
- Keep comments up-to-date with code changes

### Project-Specific Guidelines

#### Configuration Management

- **Never hardcode** API keys or secrets
- Use environment variables via `config.py`
- Add new configs to `.env.example` with documentation
- Validate critical configs in `config.py`

#### Error Handling

```python
# Good: Specific exception handling
try:
    result = call_api()
except APITimeoutError as e:
    logger.error(f"API timeout: {e}", extra={"trace_id": trace_id})
    return fallback_response()
except APIError as e:
    logger.error(f"API error: {e}", extra={"trace_id": trace_id})
    raise

# Bad: Bare except
try:
    result = call_api()
except:
    pass
```

#### Logging

```python
from logger_utils import get_logger

logger = get_logger(__name__)

# Include trace_id for request correlation
logger.info(
    "Query processed successfully",
    extra={
        "trace_id": trace_id,
        "query_length": len(query),
        "duration_ms": duration
    }
)
```

#### Security

- **No secrets in logs** or error messages
- **Validate all inputs** before processing
- **Sanitize user data** in responses
- **Review git diff** before commits to catch secrets

## Testing Guidelines

### Running Tests

```bash
# Run all tests
pytest

# Run with coverage report
pytest --cov=. --cov-report=html --cov-report=term

# Run specific test file
pytest tests/test_api.py

# Run tests matching pattern
pytest -k "test_chat"

# Run with verbose output
pytest -v
```

### Writing Tests

#### Test Structure

Place tests in the `tests/` directory with `test_` prefix:

```
tests/
├── conftest.py              # Shared fixtures
├── test_api.py              # API endpoint tests
├── test_rag.py              # RAG pipeline tests
├── test_embedding.py        # Embedding tests
└── test_chunking.py         # Data processing tests
```

#### Test Example

```python
import pytest
from fastapi.testclient import TestClient
from app import app

@pytest.fixture
def client():
    """Create test client fixture"""
    return TestClient(app)

def test_chat_endpoint_success(client):
    """Test successful chat interaction with valid query"""
    response = client.post(
        "/api/chat",
        json={
            "query": "Thủ tục đăng ký kết hôn?",
            "chat_history": []
        }
    )
    
    assert response.status_code == 200
    
    data = response.json()
    assert data["success"] is True
    assert len(data["answer"]) > 0
    assert len(data["contexts"]) > 0
    assert "trace_id" in data

def test_chat_endpoint_validation(client):
    """Test input validation on chat endpoint"""
    # Empty query
    response = client.post("/api/chat", json={"query": ""})
    assert response.status_code == 422
    
    # Query too long
    long_query = "x" * 1001
    response = client.post("/api/chat", json={"query": long_query})
    assert response.status_code == 422
```

### Test Coverage Requirements

- **Minimum coverage**: 70% overall
- **New code**: 80%+ coverage required
- **Critical paths**: 90%+ coverage (API endpoints, RAG pipeline)

### Integration Tests

Test interactions between components:

```python
def test_rag_pipeline_integration():
    """Test complete RAG pipeline from query to response"""
    from rag import search_rag
    
    results = search_rag("Thủ tục cấp CMND", k=5)
    
    assert len(results) > 0
    assert all('text' in r for r in results)
    assert all('metadata' in r for r in results)
```

## Pull Request Process

### Before Submitting

1. **Create feature branch** from `main`

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following coding standards

3. **Write/update tests** for your changes

4. **Run test suite** and ensure all pass

   ```bash
   pytest
   black .
   flake8
   ```

5. **Update documentation** if needed

6. **Commit with clear messages** following [Conventional Commits](https://www.conventionalcommits.org/)

   ```bash
   git commit -m "feat: add Vietnamese accent normalization"
   git commit -m "fix: correct FAISS index dimension mismatch"
   git commit -m "docs: update API endpoint documentation"
   ```

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style (formatting, missing semicolons, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks (dependencies, build, etc.)
- `perf`: Performance improvements

**Examples:**

```
feat(rag): add semantic chunking for long documents

Implement recursive character-based chunking with overlap
to improve context retrieval for documents > 1000 tokens.

Closes #123
```

```
fix(api): validate query length before processing

Prevent 500 errors by validating query length at endpoint
level instead of deep in the processing pipeline.

Fixes #456
```

### Pull Request Template

Use this checklist in your PR description:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Documentation update

## Testing
- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Manual testing performed
- [ ] Test coverage maintained/improved

## Code Quality
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated

## Security
- [ ] No secrets or API keys committed
- [ ] Input validation implemented
- [ ] Dependencies reviewed for vulnerabilities

## Backwards Compatibility
- [ ] API response schemas backward compatible
- [ ] Configuration changes documented in .env.example
- [ ] Database/index migrations included if needed

## Additional Context
- Related issues: #123, #456
- Breaking changes: None
- Migration notes: N/A
```

### Review Process

1. **Automated checks** must pass (if CI/CD is set up)
2. **Code review** by at least one maintainer
3. **Testing** on development environment
4. **Approval** required before merging
5. **Squash and merge** to keep history clean

### After Merge

- Delete your feature branch
- Update your local `main` branch
- Close related issues if resolved

## Issue Reporting

### Bug Reports

Create issues using this template:

```markdown
## Bug Description
Clear description of the bug

## Steps to Reproduce
1. Go to '...'
2. Click on '...'
3. See error

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- OS: [e.g., Ubuntu 22.04]
- Python version: [e.g., 3.12.3]
- Installation method: [docker/local]
- Relevant config: [e.g., EMBEDDING_DEVICE=cpu]

## Logs
```
Paste relevant logs here with LOG_LEVEL=DEBUG
```

## Screenshots
If applicable
```

### Feature Requests

```markdown
## Feature Description
Clear description of the proposed feature

## Use Case
Why is this feature needed?

## Proposed Solution
How should this work?

## Alternatives Considered
Other approaches you've thought about

## Additional Context
Any other relevant information
```

## Community

### Getting Help

- **Documentation**: Start with [README.md](README.md)
- **Issues**: Search [existing issues](https://github.com/PhucHuwu/ChatBot_Dich_vu_cong/issues)
- **Discussions**: Use [GitHub Discussions](https://github.com/PhucHuwu/ChatBot_Dich_vu_cong/discussions)

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and community discussion
- **Pull Requests**: Code contributions and reviews

### Recognition

Contributors will be recognized in:
- Project README acknowledgments
- Release notes for significant contributions
- GitHub contributors page

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).

## Questions?

If you have questions about contributing, please:

1. Check existing documentation and issues
2. Ask in GitHub Discussions
3. Create a new issue with the `question` label

---

Thank you for contributing to the Vietnamese Public Service Chatbot!
