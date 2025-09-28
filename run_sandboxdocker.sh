#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 설정(요청하신 기본값으로 고정; 필요 시 환경변수로 덮어쓰기 가능)
# ==============================================================================
OWNER="${OWNER:-joungwoo-pc}"
REPO="${REPO:-joungwoo-pc-open}"
BRANCH="${BRANCH:-build}"
TAR_NAME="${TAR_NAME:-sandboxdocker.tar}"

# 컨테이너 실행 옵션
CONTAINER_NAME="${CONTAINER_NAME:-sandboxdocker}"
RESTART_POLICY="${RESTART_POLICY:-unless-stopped}"

# 포트 매핑 (필요 시 환경변수로 덮어쓰기)
PORTS_DEFAULT=(-p 37910-37915:37910-37915 -p 38010-38011:38010-38011)
PORTS=("${PORTS_OVERRIDE[@]:-${PORTS_DEFAULT[@]}}")

# 내부 LLM 환경변수 (필요 시 환경변수로 덮어쓰기)
INTERNAL_LLM_API_BASE="${INTERNAL_LLM_API_BASE:-http://host.docker.internal:11434/v1}"
INTERNAL_LLM_API_KEY="${INTERNAL_LLM_API_KEY:-dev-key}"

# 외부 볼륨: EXT_HOST가 디렉터리 경로면 bind mount, 아니면 네임드 볼륨 사용
EXT_HOST="${EXT_HOST:-}"
NAMED_VOLUME="${NAMED_VOLUME:-sandboxdocker_ext_volume}"

# ==============================================================================
# 유틸
# ==============================================================================
log() { printf '[%s] %s\n' "$(date +'%Y-%m-%dT%H:%M:%S')" "$*"; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

need_bin() {
  command -v "$1" >/dev/null 2>&1 || die "필요한 명령어가 없습니다: $1"
}

# 필수 도구 확인
need_bin curl
need_bin docker

# jq는 선택(있으면 사용, 없으면 단순 경로로 다운로드)
HAVE_JQ=1
if ! command -v jq >/dev/null 2>&1; then
  HAVE_JQ=0
  log "jq 미설치: 파일 크기 검증 없이 raw URL로 다운로드합니다."
fi

# ==============================================================================
# [1] TAR 파일 확인 및 다운로드 (없으면 GitHub에서 가져오기)
# ==============================================================================
if [[ -f "$TAR_NAME" ]]; then
  log "로컬에 $TAR_NAME 존재 → 다운로드 생략"
else
  log "로컬에 $TAR_NAME 없음 → 원격에서 다운로드 시도"

  if [[ $HAVE_JQ -eq 1 ]]; then
    # GitHub API에서 파일 메타정보 조회 후 download_url/size 이용
    API_URL="https://api.github.com/repos/${OWNER}/${REPO}/contents/${TAR_NAME}?ref=${BRANCH}"
    log "메타 조회: $API_URL"
    FILE_INFO="$(curl -fsSL "$API_URL")" || die "GitHub API 조회 실패"
    DOWNLOAD_URL="$(printf '%s' "$FILE_INFO" | jq -r '.download_url')"
    SIZE="$(printf '%s' "$FILE_INFO" | jq -r '.size')"
    [[ "$DOWNLOAD_URL" == "null" || -z "$DOWNLOAD_URL" ]] && die "download_url 파싱 실패"

    log "다운로드: $DOWNLOAD_URL (크기: ${SIZE:-unknown} bytes)"
    curl -fSL -C - "$DOWNLOAD_URL" -o "$TAR_NAME" || die "다운로드 실패"

    # 크기 검증
    if [[ -n "${SIZE:-}" && "$SIZE" != "null" ]]; then
      ACTUAL_SIZE="$(stat -c%s "$TAR_NAME")"
      if [[ "$ACTUAL_SIZE" -ne "$SIZE" ]]; then
        die "다운로드된 파일 크기 불일치: 기대=${SIZE}, 실제=${ACTUAL_SIZE}"
      fi
      log "파일 크기 검증 완료"
    fi
  else
    # raw URL 직접 다운로드 (크기 검증 생략)
    RAW_URL="https://raw.githubusercontent.com/${OWNER}/${REPO}/${BRANCH}/${TAR_NAME}"
    log "다운로드(raw): $RAW_URL"
    curl -fSL -C - "$RAW_URL" -o "$TAR_NAME" || die "다운로드 실패"
  fi
fi

# ==============================================================================
# [2] Docker 이미지 로드
# ==============================================================================
log "Docker 이미지 로드: $TAR_NAME"
LOAD_OUT="$(docker load -i "$TAR_NAME")" || die "docker load 실패"
# 출력 예: "Loaded image: repo/name:tag"
IMAGE_REF="$(printf '%s' "$LOAD_OUT" | awk -F': ' '/Loaded image:/ {print $2}' | tail -n1)"

if [[ -z "${IMAGE_REF:-}" ]]; then
  # 일부 Docker 버전은 "Loaded image ID: sha256:..."만 찍기도 함 → 태그 추정 실패 시 사용자 지정
  IMAGE_REF="${IMAGE_REF_FALLBACK:-${CONTAINER_NAME}:latest}"
  log "이미지 레퍼런스 파싱 실패 → ${IMAGE_REF} 로 가정"
fi
log "사용할 이미지: ${IMAGE_REF}"

# ==============================================================================
# [3] 볼륨 준비
# ==============================================================================
VOLUME_FLAG=()
if [[ -n "$EXT_HOST" && -d "$EXT_HOST" ]]; then
  log "호스트 디렉터리 바인드 마운트 사용: $EXT_HOST -> /root/ext_volume"
  VOLUME_FLAG=(-v "${EXT_HOST}:/root/ext_volume")
else
  log "네임드 볼륨 사용: ${NAMED_VOLUME} -> /root/ext_volume"
  docker volume inspect "$NAMED_VOLUME" >/dev/null 2>&1 || docker volume create "$NAMED_VOLUME" >/dev/null
  VOLUME_FLAG=(-v "${NAMED_VOLUME}:/root/ext_volume")
fi

# 기존 동일 이름 컨테이너가 있으면 제거
if docker ps -a --format '{{.Names}}' | grep -Fxq "${CONTAINER_NAME}"; then
  log "기존 컨테이너 제거: ${CONTAINER_NAME}"
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

# ==============================================================================
# [4] 컨테이너 실행 (자동 재시작, 백그라운드)
#     - 시작 시 /root/startrun.sh 존재하면 실행 권한 부여 후 실행
#     - 없으면 조용히 건너뜀(에러 없음)
#     - 컨테이너는 sleep infinity로 유지되어 재시작 정책 적용 가능
# ==============================================================================
log "컨테이너 실행: ${CONTAINER_NAME} (restart=${RESTART_POLICY})"
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart "${RESTART_POLICY}" \
  "${PORTS[@]}" \
  "${VOLUME_FLAG[@]}" \
  -e INTERNAL_LLM_API_BASE="${INTERNAL_LLM_API_BASE}" \
  -e INTERNAL_LLM_API_KEY="${INTERNAL_LLM_API_KEY}" \
  "${IMAGE_REF}" \
  bash -lc ' \
    if [ -f /root/startrun.sh ]; then \
      chmod +x /root/startrun.sh || true; \
      /root/startrun.sh || true; \
    fi; \
    exec sleep infinity \
  ' >/dev/null

log "컨테이너 기동 완료"

# 기동 상태 확인
if ! docker ps --format '{{.Names}}' | grep -Fxq "${CONTAINER_NAME}"; then
  die "컨테이너가 실행 중이 아닙니다"
fi

# ==============================================================================
# [5] 컨테이너 진입 (작업 디렉터리: /root/ext_volume)
# ==============================================================================
log "컨테이너에 진입합니다. 작업 디렉터리: /root/ext_volume"
exec docker exec -it -w /root/ext_volume "${CONTAINER_NAME}" bash