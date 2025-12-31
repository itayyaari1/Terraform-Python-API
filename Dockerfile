# Multi-stage Dockerfile for optimized image size

# Stage 1: Builder stage
FROM python:3.11-slim as builder

# Set working directory
WORKDIR /app

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Runtime stage
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy only installed packages from builder stage
COPY --from=builder /root/.local /root/.local

# Copy application package
COPY app/ ./app/

# Make sure scripts in .local are usable
ENV PATH=/root/.local/bin:$PATH

# Expose port 5000
EXPOSE 5000

# Set entrypoint
ENTRYPOINT ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "5000"]

