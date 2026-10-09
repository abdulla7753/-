FROM python:3.12-slim
# The eclipse-sumo wheel bundles most libraries; sumo/netconvert still link X11 and GL.
RUN apt-get update && apt-get install -y --no-install-recommends libgl1 libx11-6 libxext6 libxrender1 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY roadflow_server ./roadflow_server
ENV ROADFLOW_DATA_DIR=/data
VOLUME ["/data"]
EXPOSE 8000
USER 1000
CMD ["uvicorn", "roadflow_server.main:app", "--host", "0.0.0.0", "--port", "8000"]
