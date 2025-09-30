#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 설정 (필요시 환경변수로 덮어쓰기 가능)
# ==============================================================================
OWNER="${OWNER:-joungwoo-pc}"
REPO="${REPO:-joungwoo-pc-open}"
BRANCH="${BRANCH:-build}"
TAR_NAME="${TAR_NAME:-sandboxdocker.tar}"

# 컴포즈 서비스명
SERVICE_NAME="${SERVICE_NAME:-sandboxdocker}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"

# 기본 포트 매핑
PORTS_DEFAULT=(37910 37911 37912 37913 37914 37915 38010 38011)

# 외부 볼륨: EXT_HOST가 디렉터리면 bind, 아니면 네임드
EXT_HOST="${EXT_HOST:-}"
NAMED_VOLUME="${NAMED_VOLUME:-sandboxdocker_ext_volume}"

# 내부 LLM 환경변수
INTERNAL_LLM_API_BASE="${INTERNAL_LLM_API_BASE:-http://host.docker.internal:11434/v1}"
INTERNAL_LLM_API_KEY="${INTERNAL_LLM_API_KEY:-dev-key}"

# ==============================================================================
# 유틸
# ==============================================================================
log() { printf '[%s] %s\n' "$(date +'%Y-%m-%dT%H:%M:%S')" "$*"; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

need_bin() { command -v "$1" >/dev/null 2>&1 || die "필요한 명령어 없음: $1"; }

need_bin curl
need_bin docker

# ==============================================================================
# [1] TAR 다운로드
# ==============================================================================
if [[ -f "$TAR_NAME" ]]; then
  log "로컬에 $TAR_NAME 존재 → 다운로드 생략"
else
  URL="https://raw.githubusercontent.com/${OWNER}/${REPO}/${BRANCH}/${TAR_NAME}"
  log "다운로드: $URL"
  curl -fSL -C - "$URL" -o "$TAR_NAME" || die "다운로드 실패"
fi

# ==============================================================================
# [2] 이미지 로드
# ==============================================================================
log "Docker 이미지 로드: $TAR_NAME"
LOAD_OUT="$(docker load -i "$TAR_NAME")"
IMAGE_REF="$(echo "$LOAD_OUT" | awk -F': ' '/Loaded image:/ {print $2}' | tail -n1)"
if [[ -z "$IMAGE_REF" ]]; then
  IMAGE_REF="${SERVICE_NAME}:latest"
  log "이미지 태그 파싱 실패 → $IMAGE_REF 사용"
fi
log "사용할 이미지: $IMAGE_REF"

# ==============================================================================
# [3] docker-compose.yml 생성
# ==============================================================================
log "docker-compose.yml 생성: $COMPOSE_FILE"

cat > "$COMPOSE_FILE" <<EOF
version: "3.8"
services:
  $SERVICE_NAME:
    image: $IMAGE_REF
    container_name: $SERVICE_NAME
    restart: unless-stopped
    working_dir: /root/ext_volume
    tty: true
    environment:
      INTERNAL_LLM_API_BASE: "$INTERNAL_LLM_API_BASE"
      INTERNAL_LLM_API_KEY: "$INTERNAL_LLM_API_KEY"
    volumes:
EOF

if [[ -n "$EXT_HOST" && -d "$EXT_HOST" ]]; then
  echo "      - $EXT_HOST:/root/ext_volume" >> "$COMPOSE_FILE"
else
  docker volume inspect "$NAMED_VOLUME" >/dev/null 2>&1 || docker volume create "$NAMED_VOLUME" >/dev/null
  echo "      - $NAMED_VOLUME:/root/ext_volume" >> "$COMPOSE_FILE"
fi

echo "    ports:" >> "$COMPOSE_FILE"
for p in "${PORTS_DEFAULT[@]}"; do
  echo "      - \"$p:$p\"" >> "$COMPOSE_FILE"
done

cat >> "$COMPOSE_FILE" <<'EOF'
    entrypoint: >
      bash -lc "
        if [ -f /root/autorun.sh ]; then
          chmod +x /root/autorun.sh || true;
          /root/autorun.sh || true;
        fi;
        exec sleep infinity
      "
EOF

# ==============================================================================
# [4] docker compose up
# ==============================================================================
log "docker compose up -d"
docker compose -f "$COMPOSE_FILE" up -d

log "컨테이너 기동 완료 → docker compose ps 로 확인 가능"
log "컨테이너 진입: docker compose exec $SERVICE_NAME bash"