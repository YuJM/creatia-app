# MongoDB Atlas Local 개발 환경

MongoDB Atlas Local을 사용한 로컬 개발 환경 설정입니다. MongoDB Atlas의 기능을 로컬에서 사용할 수 있습니다.

## 🚀 빠른 시작

### 1. Podman 설치 (macOS)

```bash
# Homebrew로 Podman 설치
brew install podman
brew install podman-compose

# Podman 머신 초기화 및 시작
podman machine init
podman machine start

# 설치 확인
podman --version
podman-compose --version
```

### 2. MongoDB Atlas Local 시작

```bash
# docker/mongodb 디렉토리로 이동
cd docker/mongodb

# MongoDB Atlas Local 시작
make up

# 상태 확인
make status
```

**MongoDB Atlas Local 특징:**
- Atlas Search 지원
- Atlas Vector Search 지원
- 자동 인덱싱 최적화
- MongoDB 최신 버전 (7.0+)

### 3. Rails 설정

`.env` 파일에 다음 내용 추가:

```bash
# 로컬 MongoDB (개발)
MONGODB_URI=mongodb://creatia_user:creatia_pass@localhost:27017/creatia_logs

# MongoDB Atlas (프로덕션 - 실제 배포시)
# MONGODB_URI_PRODUCTION=mongodb+srv://user:pass@cluster.mongodb.net/creatia_logs
```

### 4. 연결 테스트

```bash
# MongoDB 연결 테스트
make test-connection

# 또는 Rails 프로젝트 루트에서
bin/rails mongoid:test_connection
```

## 📝 명령어

```bash
# 도움말
make help

# 시작/중지
make up        # MongoDB 시작
make down      # MongoDB 중지
make restart   # 재시작

# 모니터링
make logs      # 로그 보기
make status    # 상태 확인

# 쉘 접속
make mongo-shell  # MongoDB 쉘
make shell        # 컨테이너 bash 쉘

# 데이터 관리
make backup    # 백업 생성
make restore   # 백업 복원
make clean     # 모든 데이터 삭제 (주의!)

# Rails 연동
make test-connection    # 연결 테스트
make create-sample-logs # 샘플 데이터 생성
make stats             # 통계 확인
```

## 🔍 Mongo Express (웹 UI)

MongoDB 관리를 위한 웹 인터페이스:

- URL: http://localhost:8081
- Username: `admin`
- Password: `admin123`

## 📊 접속 정보

### MongoDB
- **Host**: localhost
- **Port**: 27017
- **Database**: creatia_logs
- **User**: creatia_user
- **Password**: creatia_pass
- **Admin User**: admin
- **Admin Password**: admin123

### Connection String
```
# 애플리케이션용
mongodb://creatia_user:creatia_pass@localhost:27017/creatia_logs

# 관리자용
mongodb://admin:admin123@localhost:27017/admin
```

## 🗂️ 데이터베이스 구조

### creatia_logs (메인 데이터베이스)
#### activity_logs
- 사용자 활동 로그
- TTL: 90일 후 자동 삭제
- 인덱스: created_at, user_id, organization_id, action

#### error_logs
- 애플리케이션 에러 로그
- TTL: 180일 후 자동 삭제
- 인덱스: created_at, error_class, severity, resolved

#### api_request_logs
- API 요청/응답 로그
- TTL: 30일 후 자동 삭제
- 인덱스: created_at, endpoint, status_code, response_time

### creatia_logs_test (테스트 데이터베이스)
- 테스트 환경용 동일한 구조의 컬렉션

## 🔄 Podman vs Docker

이 설정은 Podman과 Docker 모두 지원합니다. Makefile이 자동으로 사용 가능한 런타임을 감지합니다.

### Podman 장점
- Daemonless 아키텍처
- Rootless 컨테이너 실행
- Docker와 호환되는 CLI
- 보안 강화

### Docker에서 Podman으로 전환
```bash
# MongoDB Atlas Local 이미지를 Podman으로 가져오기
podman pull docker.io/mongodb/mongodb-atlas-local:latest

# 별칭 설정 (선택사항)
alias docker=podman
```

## 📁 디렉토리 구조

```
docker/mongodb/
├── docker-compose.yml    # Docker Compose 설정 (MongoDB Atlas Local)
├── init-atlas.js        # 초기화 스크립트 (데이터베이스, 사용자, 인덱스 생성)
├── Makefile            # 편의 명령어
├── README.md           # 이 문서
├── data/              # MongoDB 데이터 (git 제외, 로컬 볼륨)
└── backups/           # 백업 파일 (git 제외)
```

## 🛠️ 문제 해결

### Podman 머신이 시작되지 않을 때
```bash
podman machine stop
podman machine rm
podman machine init --cpus=2 --memory=4096
podman machine start
```

### 포트가 이미 사용 중일 때
```bash
# 27017 포트 사용 프로세스 확인
lsof -i :27017

# docker-compose.yml에서 포트 변경
ports:
  - "27018:27017"  # 외부 포트를 27018로 변경
```

### 권한 문제
```bash
# Podman rootless 모드 확인
podman info | grep rootless

# 볼륨 권한 문제시
podman unshare chown -R 1000:1000 ./data
```

### MongoDB Atlas Local 초기화 문제
```bash
# 데이터 볼륨 완전 초기화
make clean

# 다시 시작 (초기화 스크립트 재실행)
make up
```

## 🚀 프로덕션 배포

프로덕션에서는 MongoDB Atlas 사용을 권장합니다:

1. [MongoDB Atlas](https://www.mongodb.com/cloud/atlas) 계정 생성
2. 클러스터 생성
3. 데이터베이스 사용자 추가
4. IP 화이트리스트 설정
5. 연결 문자열 복사
6. 프로덕션 환경변수 설정:
   ```bash
   MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/creatia_logs?retryWrites=true&w=majority
   ```

## ⚠️ 주의사항

1. **데이터 영속성**: `data/` 폴더에 데이터가 저장되며, git에는 포함되지 않습니다.
2. **초기화 스크립트**: 컨테이너 최초 실행 시에만 `init-atlas.js`가 실행됩니다.
3. **메모리 사용**: MongoDB Atlas Local은 일반 MongoDB보다 더 많은 메모리를 사용할 수 있습니다.
4. **백업**: 중요한 개발 데이터는 주기적으로 백업하세요.

## 📚 참고 자료

- [MongoDB Atlas Local Docker Hub](https://hub.docker.com/r/mongodb/mongodb-atlas-local)
- [Podman 공식 문서](https://podman.io/docs)
- [MongoDB 공식 문서](https://docs.mongodb.com/)
- [Mongoid ODM 문서](https://docs.mongodb.com/mongoid/)
- [MongoDB Atlas 문서](https://docs.atlas.mongodb.com/)
- [MongoDB TTL Indexes](https://www.mongodb.com/docs/manual/core/index-ttl/)