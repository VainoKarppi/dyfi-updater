# Use official Python slim image
FROM python:3.12-slim

# Set working directory in container
WORKDIR /app

# Copy Python updater into container
COPY ../python/dyfi_updater.py ./dyfi_updater.py
COPY ../python/settings.json ./settings.json  # optional example

# Install required Python packages
RUN pip install --no-cache-dir requests

# Expose volumes for persistence
VOLUME ["/app/settings.json"]

# Default command to run updater
CMD ["python", "dyfi_updater.py"]