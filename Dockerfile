# 베이스 이미지: 우분투 + 파이썬 런타임
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# 1) 기본 패키지 업데이트 및 필수 도구
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      software-properties-common ca-certificates gnupg curl wget && \
    apt-get install -y --no-install-recommends \
      git curl wget vim htop tree zip unzip ca-certificates gnupg lsb-release \
      bash-completion fzf build-essential make cmake pkg-config \
      nodejs npm \
      python3 python3-pip python3-venv && \
    ln -s /usr/bin/python3 /usr/local/bin/python && \
    ln -s /usr/bin/pip3 /usr/local/bin/pip && \
    rm -rf /var/lib/apt/lists/*

# 2) 파이썬 최신화
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# 3) 파이썬 패키지 설치
RUN pip install --no-cache-dir \
    langchain langchain-community langchain-openai langgraph \
    pydantic[dotenv] python-dotenv requests tqdm rich ipython ipykernel \
    fastapi fastmcp pymysql langchain_tavily \
    annotated-types==0.7.0 \
    anyio==4.10.0 \
    asgiref==3.9.1 \
    backoff==2.2.1 \
    bcrypt==4.3.0 \
    build==1.3.0 \
    cachetools==5.5.2 \
    certifi==2025.8.3 \
    charset-normalizer==3.4.3 \
    chroma-hnswlib==0.7.6 \
    chromadb==0.5.5 \
    click==8.3.0 \
    coloredlogs==15.0.1 \
    distro==1.9.0 \
    durationpy==0.10 \
    filelock==3.19.1 \
    flatbuffers==25.2.10 \
    fsspec==2025.9.0 \
    google-auth==2.40.3 \
    googleapis-common-protos==1.70.0 \
    grpcio==1.75.0 \
    h11==0.16.0 \
    hf-xet==1.1.10 \
    httpcore==1.0.9 \
    httptools==0.6.4 \
    httpx==0.28.1 \
    huggingface-hub==0.35.0 \
    humanfriendly==10.0 \
    idna==3.10 \
    importlib_metadata==8.7.0 \
    importlib_resources==6.5.2 \
    jiter==0.11.0 \
    jsonpatch==1.33 \
    jsonpointer==3.0.0 \
    kubernetes==33.1.0 \
    langchain-core==0.3.76 \
    langsmith==0.4.29 \
    markdown-it-py==4.0.0 \
    mdurl==0.1.2 \
    mmh3==5.2.0 \
    mpmath==1.3.0 \
    numpy==1.26.4 \
    oauthlib==3.3.1 \
    onnxruntime==1.22.1 \
    opentelemetry-api==1.37.0 \
    opentelemetry-exporter-otlp-proto-common==1.37.0 \
    opentelemetry-exporter-otlp-proto-grpc==1.37.0 \
    opentelemetry-instrumentation==0.58b0 \
    opentelemetry-instrumentation-asgi==0.58b0 \
    opentelemetry-instrumentation-fastapi==0.58b0 \
    opentelemetry-proto==1.37.0 \
    opentelemetry-sdk==1.37.0 \
    opentelemetry-semantic-conventions==0.58b0 \
    opentelemetry-util-http==0.58b0 \
    orjson==3.11.3 \
    overrides==7.7.0 \
    packaging==25.0 \
    posthog==6.7.5 \
    protobuf==6.32.1 \
    pyasn1==0.6.1 \
    pyasn1_modules==0.4.2 \
    pydantic==2.9.2 \
    pydantic_core==2.23.4 \
    Pygments==2.19.2 \
    PyPika==0.48.9 \
    pyproject_hooks==1.2.0 \
    python-dateutil==2.9.0.post0 \
    PyYAML==6.0.2 \
    redis==5.0.8 \
    regex==2025.9.18 \
    requests-oauthlib==2.0.0 \
    requests-toolbelt==1.0.0 \
    rsa==4.9.1 \
    shellingham==1.5.4 \
    six==1.17.0 \
    sniffio==1.3.1 \
    starlette==0.38.6 \
    sympy==1.14.0 \
    tenacity==9.1.2 \
    tiktoken==0.11.0 \
    tokenizers==0.22.1 \
    typer==0.17.4 \
    typing_extensions==4.15.0 \
    urllib3==2.5.0 \
    uvicorn==0.30.6 \
    uvloop==0.21.0 \
    watchfiles==1.1.0 \
    websocket-client==1.8.0 \
    websockets==15.0.1 \
    wrapt==1.17.3 \
    zipp==3.23.0 \
    zstandard==0.25.0 \
    google-adk \
    google-genai

# 4) bash-completion / fzf 설정
RUN echo "source /usr/share/bash-completion/bash_completion" >> /etc/bash.bashrc && \
    if [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then \
      echo "source /usr/share/doc/fzf/examples/key-bindings.bash" >> /etc/bash.bashrc; \
    fi

# 5) 디렉터리/작업 경로 준비
ENV CONTAINER_HOME=/root \
    PROJECT_DIR=/root/sandboxdocker \
    EXT_DIR=/root/ext_volume
RUN mkdir -p "$PROJECT_DIR" "$EXT_DIR"

# 6) 내부 LLM API 기본값(실행 시 덮어쓰기 가능)
ENV INTERNAL_LLM_API_BASE=http://host.docker.internal:11434/v1 \
    INTERNAL_LLM_API_KEY=dev-key

# 7) 포트 노출
EXPOSE 37910 37911 37912 37913 37914 37915 38010 38011

# 8) 레포 루트의 autorun.sh를 /root로 복사 (레포에 있어야 빌드 성공)
COPY autorun.sh /root/autorun.sh

# 9) 엔트리포인트 스크립트 생성: autorun 실행 후 bash -l 진입
RUN cat >/usr/local/bin/docker-entrypoint.sh <<'EOF' \
&& chmod +x /usr/local/bin/docker-entrypoint.sh
#!/usr/bin/env bash
set -euo pipefail
# autorun 실행(있으면)
if [ -f /root/autorun.sh ]; then
  chmod +x /root/autorun.sh || true
  /root/autorun.sh || true
fi
# 인자가 있으면 그걸 실행, 없으면 bash -l 실행
if [ "$#" -gt 0 ]; then
  exec "$@"
else
  exec bash -l
fi
EOF

# 10) 기본 작업 디렉토리: /root/ext_volume (컨테이너 터미널 시작 위치)
WORKDIR /root/ext_volume

# 11) 엔트리포인트/커맨드
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["bash","-l"]
