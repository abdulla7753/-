FROM python:3.12-slim
# SUMO's manylinux wheel needs a few shared libraries at runtime.
RUN apt-get update && apt-get install -y --no-install-recommends libgl1 libglu1-mesa libxrender1 libxcursor1 libxft2 libxinerama1 \
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
