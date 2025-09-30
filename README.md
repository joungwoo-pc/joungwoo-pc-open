# GitHub Actions + Docker Compose (Self-hosted Runner)

이 워크플로는 다음을 자동으로 수행합니다.

1. **main 브랜치에 push**가 발생하면 실행됩니다.
2. 레포 root의 **Dockerfile**로 이미지를 빌드합니다.
3. Dockerfile의 **EXPOSE 포트들**을 파싱하여, 호스트:컨테이너 **동일 포트 매핑**을 구성합니다.
4. 호스트의 **HOME 디렉토리(`$HOME`)**를 컨테이너의 **`~/ext_volume`**로 마운트합니다.
5. 레포 root의 **`autorun.sh`**를 컨테이너 **홈 디렉토리(`~`)**로 복사하고 실행권한을 부여한 뒤, **컨테이너 시작 시 자동 실행**합니다.
6. 컨테이너는 **`restart: always`**로 기동되며, **작업 디렉토리**는 기본으로 `~/ext_volume` 입니다.

> **전제**: 이 워크플로는 **self-hosted 러너**에서 동작하도록 설계되어 있습니다. (러너가 설치된 머신에서 docker/compose를 직접 실행)

---

## 파일 구성

```
.github/workflows/build-run-compose.yml
.env (워크플로에서 자동 생성)
docker-compose.yml (워크플로에서 자동 생성)
```

- `.env`에는 아래 변수가 들어갑니다.
  - `IMAGE` : 빌드된 이미지 태그 (`<repo_name>:<commit_sha>`)
  - `HOME` : 러너의 홈 디렉토리 절대경로
  - `REPO_ABS` : 레포의 절대경로

---

## 수동 실행 (참고)

로컬에서 직접 실행하려면 다음을 수행하세요.

```bash
# 1) .env 작성 (필요시)
cat > .env <<EOF
IMAGE=myapp:local
HOME=$HOME
REPO_ABS=$(pwd)
EOF

# 2) 이미지 빌드
docker build -t "$IMAGE" .

# 3) docker-compose.yml 생성 (워크플로가 자동 생성하는 것과 동일 형태로 만들면 됩니다)
#    EXPOSE 포트 목록은 Dockerfile에서 그대로 호스트:컨테이너 동일 포트로 나열

# 4) 기동
docker compose up -d

# 5) 컨테이너 셸 진입 (기본 위치는 ~/ext_volume)
docker compose exec app sh
```

---

## 도커 컴포즈로 이 구성이 어떻게 실행되는가?

- `docker-compose.yml`의 `entrypoint`는 컨테이너 시작 시 다음을 수행합니다.
  1) `/ext_src/autorun.sh`를 `/root/autorun.sh`로 복사
  2) `chmod +x /root/autorun.sh`
  3) `exec /root/autorun.sh`로 교체 실행 (PID 1)

- `volumes`:
  - `"${HOME}:/root/ext_volume"` : 호스트의 홈 디렉토리를 컨테이너 `~/ext_volume`로 마운트
  - `"${REPO_ABS}:/ext_src:ro"` : 레포 루트를 읽기전용으로 마운트 (autorun.sh 복사용)

- `working_dir: /root/ext_volume` : 컨테이너 내 기본 작업 디렉토리 지정. `docker compose exec app sh` 시 이 위치에서 시작합니다.

- `ports` : Dockerfile의 EXPOSE 포트들을 자동으로 읽어와 `"호스트포트:컨테이너포트"` 형태로 모두 매핑합니다.

- `restart: always` : 컨테이너가 예기치 않게 종료되어도 자동으로 재시작됩니다.

---

## 주의사항

- 컨테이너 기본 사용자 홈은 보통 `/root`입니다. 다른 사용자로 동작하는 이미지라면 홈 경로가 다를 수 있으므로 필요시 `working_dir`와 `entrypoint`를 조정하세요.
- Dockerfile에 EXPOSE가 없다면 워크플로는 실패하도록 되어 있습니다(요구사항 보장을 위해). 포트가 필요 없다면 스텝을 완화하거나 제거하십시오.
- GitHub-hosted 러너를 사용해 원격 서버로 배포하려면 SSH 복사/실행 스텝을 추가하는 방식으로 변형이 필요합니다.


# joungwoo-pc-open

git fetch origin build
git checkout build

# tar 불러오기
docker load -i sandboxdocker.tar

# compose 실행
docker compose up -d

# 컨테이너 진입 (시작위치 ~/ext_volume)
docker compose exec sandboxdocker bash