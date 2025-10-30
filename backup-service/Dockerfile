FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies, Python packages, and setup in a single layer
COPY requirements.txt .
RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-client \
    cron \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir -r requirements.txt \
    && touch /var/log/cron.log

# Copy backup script and entrypoint
COPY backup.py entrypoint.sh ./
RUN chmod +x entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
