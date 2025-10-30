FROM python:3.11-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    mariadb-client \
    cron \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backup script
COPY backup.py .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

# Create cron log file
RUN touch /var/log/cron.log

ENTRYPOINT ["/app/entrypoint.sh"]
