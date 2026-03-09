FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY attack_ingestor.py .

CMD ["python", "/app/attack_ingestor.py"]
