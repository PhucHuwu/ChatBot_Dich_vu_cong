# PowerShell script để rebuild FAISS index
# Sử dụng: .\scripts\rebuild_index.ps1 [batch_size]

param(
    [int]$BatchSize = 32
)

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Rebuilding FAISS Index" -ForegroundColor Green
Write-Host "Batch size: $BatchSize" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

# Activate virtual environment nếu có
if (Test-Path "venv\Scripts\Activate.ps1") {
    & "venv\Scripts\Activate.ps1"
}

# Run rebuild
$pythonCode = @"
from rag import build_index
from config import settings

print(f'Environment: {settings.APP_ENV}')
print(f'Embedding model: {settings.EMBEDDING_MODEL}')
print('Starting index rebuild...')

build_index(batch_size=$BatchSize)

print('Index rebuild completed successfully!')
"@

python -c $pythonCode

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Index rebuild finished!" -ForegroundColor Green
Write-Host "Files created:" -ForegroundColor Yellow
Get-ChildItem embeddings\ | Format-Table Name, Length, LastWriteTime
Write-Host "==========================================" -ForegroundColor Green
