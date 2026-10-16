FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && useradd --uid 10001 --create-home bootstrap
COPY app.py .
USER bootstrap
ENV PYTHONUNBUFFERED=1
EXPOSE 8080
CMD ["python", "app.py"]
