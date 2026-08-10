# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (multi-stage, non-root, healthcheck)
# ═══════════════════════════════════════════════════════════════════

# ---- Stage 1: builder — cài dependency, có thể cần compiler ----
FROM python:3.11-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# ---- Stage 2: runtime — chỉ mang theo kết quả cài đặt, không mang builder ----
FROM python:3.11-slim

WORKDIR /app

RUN addgroup --system app && adduser --system --ingroup app app

COPY --from=builder /root/.local /home/app/.local
COPY . .

ENV PATH=/home/app/.local/bin:$PATH \
    PYTHONUNBUFFERED=1

RUN chown -R app:app /app
USER app

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import os,urllib.request as u; u.urlopen('http://localhost:' + os.environ.get('PORT','8000') + '/health', timeout=3)"]

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
