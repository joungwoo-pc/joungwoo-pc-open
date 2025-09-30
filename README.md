# Sandboxdocker 실행 방법

이 프로젝트는 `main` 브랜치에 변경이 생기면 자동으로 Docker 이미지를 빌드하여  
- Docker 이미지 tar 파일은 **GitHub Release (tag: `build-latest`)** 에 업로드  
- `docker-compose.yml` 파일은 **build 브랜치 루트**에 커밋  

되도록 구성되어 있습니다.

---

## 준비 사항
1. **Docker Desktop** (Windows/Mac) 또는 Docker (Linux) 설치
2. **Git** 설치
   - Windows: Git for Windows 설치 시 **Git Bash**도 같이 설치됩니다.
   - Git Bash를 사용하면 리눅스 명령어(`wget`, `ls`, `bash`)를 그대로 사용할 수 있습니다.

---

## 실행 방법

### 1. 최신 tar 다운로드
Release 페이지에서 최신 tar 파일을 다운로드합니다.

```bash
wget -O sandboxdocker.tar \
  https://github.com/joungwoo-pc/joungwoo-pc-open/releases/download/build-latest/sandboxdocker.tar