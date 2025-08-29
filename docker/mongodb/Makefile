# MongoDB Local Development with Podman/Docker

# 컨테이너 런타임 감지 (Podman 우선)
CONTAINER_RUNTIME := $(shell command -v podman 2> /dev/null || echo docker)
COMPOSE_RUNTIME := $(shell command -v podman-compose 2> /dev/null || echo docker-compose)

.PHONY: help up down restart logs shell mongo-shell status clean backup restore

help: ## 도움말 표시
	@echo "MongoDB 로컬 개발 환경 명령어:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "사용중인 컨테이너 런타임: $(CONTAINER_RUNTIME)"
	@echo "사용중인 Compose 런타임: $(COMPOSE_RUNTIME)"

up: ## MongoDB Atlas Local과 Mongo Express 시작
	$(COMPOSE_RUNTIME) up -d
	@echo "✅ MongoDB Atlas Local이 시작되었습니다!"
	@echo "📊 MongoDB: mongodb://localhost:27017"
	@echo "🔍 Mongo Express: http://localhost:8081 (admin/admin123)"

down: ## 컨테이너 중지
	$(COMPOSE_RUNTIME) down
	@echo "⏹️ MongoDB가 중지되었습니다."

restart: ## 컨테이너 재시작
	$(COMPOSE_RUNTIME) restart
	@echo "🔄 MongoDB가 재시작되었습니다."

logs: ## 컨테이너 로그 보기
	$(COMPOSE_RUNTIME) logs -f

mongo-shell: ## MongoDB 쉘 접속
	$(CONTAINER_RUNTIME) exec -it creatia_mongodb_atlas_local mongosh -u creatia_user -p creatia_pass --authenticationDatabase creatia_logs creatia_logs

shell: ## MongoDB 컨테이너 쉘 접속
	$(CONTAINER_RUNTIME) exec -it creatia_mongodb_atlas_local bash

status: ## 컨테이너 상태 확인
	$(COMPOSE_RUNTIME) ps
	@echo ""
	@echo "📊 MongoDB 연결 정보:"
	@echo "  - Host: localhost"
	@echo "  - Port: 27017"
	@echo "  - Database: creatia_logs"
	@echo "  - User: creatia_user"
	@echo "  - Password: creatia_pass"
	@echo "  - Admin User: admin"
	@echo "  - Admin Password: admin123"
	@echo ""
	@echo "📝 Rails .env 설정:"
	@echo "  MONGODB_URI=mongodb://creatia_user:creatia_pass@localhost:27017/creatia_logs"

clean: ## 컨테이너와 볼륨 삭제 (주의: 데이터 손실!)
	@echo "⚠️  경고: 모든 MongoDB 데이터가 삭제됩니다!"
	@echo "계속하려면 5초 내에 Ctrl+C로 취소하세요..."
	@sleep 5
	$(COMPOSE_RUNTIME) down -v
	@echo "🗑️ MongoDB 컨테이너와 데이터가 삭제되었습니다."

backup: ## MongoDB 백업
	@mkdir -p backups
	@BACKUP_FILE="backups/mongodb_backup_$$(date +%Y%m%d_%H%M%S).gz"
	$(CONTAINER_RUNTIME) exec creatia_mongodb_atlas_local mongodump -u creatia_user -p creatia_pass --db creatia_logs --archive --gzip > $$BACKUP_FILE
	@echo "✅ 백업 완료: $$BACKUP_FILE"

restore: ## MongoDB 복원 (최신 백업 파일 사용)
	@LATEST_BACKUP=$$(ls -t backups/*.gz 2>/dev/null | head -1); \
	if [ -z "$$LATEST_BACKUP" ]; then \
		echo "❌ 백업 파일을 찾을 수 없습니다."; \
		exit 1; \
	fi; \
	echo "복원할 백업: $$LATEST_BACKUP"; \
	cat $$LATEST_BACKUP | $(CONTAINER_RUNTIME) exec -i creatia_mongodb_atlas_local mongorestore -u creatia_user -p creatia_pass --db creatia_logs --archive --gzip
	@echo "✅ 복원 완료!"

test-connection: ## Rails에서 MongoDB 연결 테스트
	cd ../.. && bin/rails mongoid:test_connection

create-sample-logs: ## 샘플 로그 데이터 생성
	cd ../.. && bin/rails mongoid:create_sample_logs

stats: ## 로그 통계 확인
	cd ../.. && bin/rails mongoid:stats