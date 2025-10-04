# 1) tar와 compose 파일 받기
curl.exe -f -L -o "sandboxdocker.tar" "https://github.com/joungwoo-lee/joungwoo-lee-open/releases/download/build-latest/sandboxdocker.tar"

curl.exe -f -L -o "docker-compose.yml" "https://github.com/joungwoo-lee/joungwoo-lee-open/releases/download/build-latest/docker-compose.yml"

# 2) 이미지 로드
wsl docker load -i sandboxdocker.tar

# 3) 컨테이너 실행
wsl docker compose up -d

# 4) 컨테이너 접속 (시작 위치: /root/ext_volume)
wsl docker compose exec sandboxdocker bash
