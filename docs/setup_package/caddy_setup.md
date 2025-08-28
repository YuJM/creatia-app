# Caddy 로컬 개발 환경 설정

> **작성일**: 2025년 8월 26일  
> **목적**: 멀티테넌트 Rails 앱의 서브도메인 개발 환경 구축

## 📋 개요

Caddy를 사용하여 로컬 개발 환경에서 멀티테넌트 서브도메인 기능을 테스트할 수 있도록 리버스 프록시를 설정합니다.

## 🚀 설치 및 설정

### 1. Caddy 설치

#### macOS (Homebrew)
```bash
brew install caddy
```

#### Ubuntu/Debian
```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy
```

#### 다른 OS
[Caddy 공식 설치 가이드](https://caddyserver.com/docs/install) 참조

### 2. hosts 파일 설정

로컬에서 서브도메인을 사용하기 위해 `/etc/hosts` 파일에 도메인을 추가합니다:

```bash
# hosts 파일 편집
sudo vim /etc/hosts

# 다음 라인들 추가
127.0.0.1 creatia.local
127.0.0.1 auth.creatia.local
127.0.0.1 api.creatia.local
127.0.0.1 admin.creatia.local
127.0.0.1 demo.creatia.local
127.0.0.1 test.creatia.local
127.0.0.1 dev.creatia.local
127.0.0.1 playwright-test.creatia.local
127.0.0.1 e2e-test.creatia.local
127.0.0.1 sample-org.creatia.local
127.0.0.1 acme-corp.creatia.local
127.0.0.1 health.creatia.local
```

### 3. 로그 디렉터리 생성

```bash
sudo mkdir -p /var/log/caddy
sudo chown $USER:$USER /var/log/caddy
```

## 🏗️ 서브도메인 구조

### 시스템 서브도메인
- **메인**: `http://creatia.local` - 랜딩 페이지, 사용자 등록
- **인증**: `http://auth.creatia.local` - SSO, 로그인/로그아웃  
- **API**: `http://api.creatia.local` - REST API 엔드포인트
- **관리자**: `http://admin.creatia.local` - 시스템 관리

### 개발/테스트 서브도메인
- **데모**: `http://demo.creatia.local` - 데모 조직
- **테스트**: `http://test.creatia.local` - 테스트 조직
- **개발**: `http://dev.creatia.local` - 개발용 조직
- **E2E 테스트**: `http://e2e-test.creatia.local` - 자동화 테스트용
- **Playwright**: `http://playwright-test.creatia.local` - Playwright 테스트용

### 샘플 조직 서브도메인
- **샘플 조직**: `http://sample-org.creatia.local`
- **ACME 회사**: `http://acme-corp.creatia.local`

### 동적 조직 서브도메인
- **와일드카드**: `http://*.creatia.local` - 모든 기타 조직 서브도메인

### 헬스체크
- **헬스체크**: `http://health.creatia.local` - 앱 상태 확인

## 🔧 사용법

### 1. Rails 앱 실행
```bash
# Rails 서버 시작 (포트 3000)
cd /path/to/creatia-app
bin/rails server
```

### 2. Caddy 실행
```bash
# 프로젝트 루트에서 Caddy 실행
cd /path/to/creatia-app
caddy run

# 또는 백그라운드에서 실행
caddy start
```

### 3. 서브도메인 접근 테스트
```bash
# 메인 도메인
curl -H "Host: creatia.local" http://creatia.local

# 인증 서브도메인
curl -H "Host: auth.creatia.local" http://auth.creatia.local

# API 서브도메인
curl -H "Host: api.creatia.local" http://api.creatia.local/api/v1/organizations

# 동적 조직 서브도메인
curl -H "Host: my-company.creatia.local" http://my-company.creatia.local
```

## 📊 로그 모니터링

### 실시간 로그 확인
```bash
# 전체 로그
tail -f /var/log/caddy/*.log

# 특정 서브도메인 로그
tail -f /var/log/caddy/auth.creatia.local.log
tail -f /var/log/caddy/api.creatia.local.log
tail -f /var/log/caddy/wildcard.creatia.local.log
```

### 로그 형식
모든 로그는 JSON 형식으로 저장되어 분석이 용이합니다:
```json
{
  "level": "info",
  "ts": 1692969600.123,
  "logger": "http.log.access",
  "msg": "handled request",
  "request": {
    "remote_ip": "127.0.0.1",
    "remote_port": "52081",
    "proto": "HTTP/1.1",
    "method": "GET",
    "host": "auth.creatia.local",
    "uri": "/users/sign_in",
    "headers": {
      "User-Agent": ["Mozilla/5.0..."]
    }
  },
  "bytes_read": 0,
  "user_id": "",
  "duration": 0.123456789,
  "size": 1234,
  "status": 200,
  "resp_headers": {
    "Content-Type": ["text/html; charset=utf-8"]
  }
}
```

## 🧪 테스트 시나리오

### 1. 기본 멀티테넌트 테스트
```bash
# 1. 메인 사이트 접근
open http://creatia.local

# 2. 인증 페이지 접근
open http://auth.creatia.local

# 3. 데모 조직 접근
open http://demo.creatia.local

# 4. API 테스트
curl http://api.creatia.local/up
```

### 2. 동적 조직 생성 테스트
```bash
# 새로운 조직 서브도메인 테스트
open http://new-company.creatia.local
open http://startup-xyz.creatia.local
```

### 3. E2E 테스트 환경
```bash
# Playwright 테스트용 도메인
open http://playwright-test.creatia.local

# 일반 E2E 테스트용 도메인  
open http://e2e-test.creatia.local
```

## 🔨 Caddy 관리 명령어

### 기본 명령어
```bash
# 설정 파일 구문 검사
caddy validate

# Caddy 시작
caddy start

# Caddy 중지
caddy stop

# Caddy 재시작
caddy reload

# 설정 실시간 적용
caddy reload --config Caddyfile

# 상태 확인
caddy list-modules
```

### 설정 변경 시
```bash
# 설정 파일 수정 후 실시간 적용
caddy reload
```

## 🚨 트러블슈팅

### 자주 발생하는 문제들

#### 1. 포트 충돌
```bash
# 80 포트 사용 중인 프로세스 확인
sudo lsof -i :80

# Apache/Nginx 중지 (필요시)
sudo systemctl stop apache2
sudo systemctl stop nginx
```

#### 2. 권한 문제
```bash
# Caddy에 80 포트 바인딩 권한 부여 (Linux)
sudo setcap CAP_NET_BIND_SERVICE=+eip $(which caddy)
```

#### 3. DNS 캐시 문제
```bash
# macOS DNS 캐시 클리어
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Ubuntu DNS 캐시 클리어
sudo systemctl restart systemd-resolved
```

#### 4. Rails 앱 연결 실패
```bash
# Rails 서버가 실행 중인지 확인
curl http://localhost:3000/up

# 포트 3000 확인
lsof -i :3000
```

### 로그 디버깅
```bash
# Caddy 실행 로그 확인
caddy run --config Caddyfile

# 자세한 디버그 로그
caddy run --config Caddyfile --debug
```

## ⚙️ 고급 설정

### 개발 환경별 설정 분리
```bash
# 개발용 Caddyfile
caddy run --config Caddyfile.dev

# 테스트용 Caddyfile  
caddy run --config Caddyfile.test
```

### 성능 최적화
```caddyfile
# Caddyfile에 추가할 성능 설정
{
    # 연결 풀링
    servers {
        metrics
    }
}

# 압축 활성화
http://creatia.local {
    encode gzip zstd
    reverse_proxy localhost:3000
}
```

### SSL/TLS (프로덕션 준비)
```caddyfile
# HTTPS 자동 설정 (실제 도메인 필요)
{
    email your-email@example.com
}

https://your-domain.com {
    reverse_proxy localhost:3000
}
```

## 📝 다음 단계

### 1. 프로덕션 배포
- 실제 도메인 구매 및 DNS 설정
- SSL/TLS 인증서 자동 관리
- 로드 밸런싱 설정

### 2. 모니터링 강화
- Prometheus 메트릭 수집
- Grafana 대시보드 구축
- 알림 설정

### 3. 보안 강화
- WAF (Web Application Firewall) 설정
- Rate limiting 구현
- IP 화이트리스트/블랙리스트

이제 로컬 개발 환경에서 **완전한 멀티테넌트 서브도메인 기능**을 테스트할 수 있습니다! 🚀
