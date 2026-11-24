# Runs the app in a container. The model still lives on the host (Ollama),
# so pass --add-host or use host.docker.internal / the host IP.
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY .env.example ./.env.example
RUN mkdir -p /app/data

ENV DATA_DIR=/app/data
EXPOSE 8000
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
