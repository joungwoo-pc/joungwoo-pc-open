# Sandboxdocker Run Guide

이 레포는 `main` 브랜치 변경 시 자동으로
- `sandboxdocker.tar` (Docker 이미지) 와
- `docker-compose.yml`
을 **GitHub Release (tag: build-latest)** 에 올립니다.

아래 명령만 실행하면 바로 기동됩니다.

---

## Quick Start

```bash
# 1) tar와 compose 파일 받기
wget https://github.com/joungwoo-pc/joungwoo-pc-open/releases/download/build-latest/sandboxdocker.tar
wget https://github.com/joungwoo-pc/joungwoo-pc-open/releases/download/build-latest/docker-compose.yml

# 2) 이미지 로드
docker load -i sandboxdocker.tar

# 3) 컨테이너 실행
docker compose up -d

# 4) 컨테이너 접속 (시작 위치: /root/ext_volume)
docker compose exec sandboxdocker bash