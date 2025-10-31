FROM python:3.9-alpine

WORKDIR /app

# Copy requirements with known vulnerabilities
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

EXPOSE 5000

CMD ["python", "app.py"]
