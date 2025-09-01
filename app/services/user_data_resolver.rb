# frozen_string_literal: true

# UserDataResolver - Cross-database User 데이터 해결 전담 서비스
# PostgreSQL User와 MongoDB UserSnapshot 간의 데이터 통합을 담당
class UserDataResolver
  include Dry::Monads[:result, :maybe]

  # 캐시 TTL 설정
  CACHE_TTL = 5.minutes
  SNAPSHOT_TTL = 1.hour

  def initialize
    @stats = {
      snapshot_hits: 0,
      cache_hits: 0,
      db_queries: 0,
      background_syncs: 0
    }
  end

  # Task 컬렉션에 대한 User 데이터 해결
  def resolve_for_tasks(tasks)
    return Success([]) if tasks.empty?

    # N+1 방지: User ID 사전 수집 및 캐시 프리로드
    user_ids = tasks.flat_map { |t| [t.assignee_id, t.reviewer_id] }.compact.uniq
    preload_users_to_cache(user_ids) if user_ids.any?

    # Task별로 User 데이터 해결
    enriched_tasks = tasks.map do |task|
      assignee = resolve_user_for_task(task, :assignee)
      reviewer = resolve_user_for_task(task, :reviewer)
      
      
      {
        task: task,
        assignee: assignee,
        reviewer: reviewer
      }
    end

    # 백그라운드 동기화 스케줄링
    schedule_bulk_sync_if_needed(tasks)

    Success(enriched_tasks)
  end

  # 개별 Task의 User 데이터 해결
  def resolve_user_for_task(task, role_type)
    user_id = role_type == :assignee ? task.assignee_id : task.reviewer_id

    
    return nil unless user_id.present?

    # 1단계: Fresh Snapshot 조회 (별도 컬렉션에서)
    snapshot = UserSnapshot.where(user_id: user_id).first
    
    if snapshot&.fresh?(SNAPSHOT_TTL)
      @stats[:snapshot_hits] += 1
      return Dto::UserDto.from_snapshot(snapshot)
    end

    # 2단계: 캐시 조회
    cached_user = fetch_from_cache(user_id)
    
    if cached_user
      @stats[:cache_hits] += 1
      return cached_user
    end

    # 3단계: PostgreSQL 직접 조회
    user = fetch_from_database(user_id)
    
    cache_user_data(user) if user

    user
  end

  # 배치 User 데이터 해결 (성능 최적화)
  def resolve_users_batch(user_ids)
    return {} if user_ids.empty?

    resolved_users = {}
    remaining_ids = user_ids.dup

    # 1단계: 캐시에서 일괄 조회
    cached_data = fetch_batch_from_cache(remaining_ids)
    resolved_users.merge!(cached_data)
    remaining_ids -= cached_data.keys

    # 2단계: PostgreSQL에서 나머지 조회
    if remaining_ids.any?
      db_users = User.where(id: remaining_ids)
      @stats[:db_queries] += 1

      db_users.each do |user|
        user_dto = Dto::UserDto.from_user(user)
        resolved_users[user.id.to_s] = user_dto
        cache_user_data(user_dto, user.id.to_s)
      end
    end

    resolved_users
  end

  # 통계 정보 반환
  def stats
    @stats.dup
  end

  # 통계 초기화
  def reset_stats!
    @stats = {
      snapshot_hits: 0,
      cache_hits: 0,
      db_queries: 0,
      background_syncs: 0
    }
  end

  private

  # 캐시에서 User 조회
  def fetch_from_cache(user_id)
    cached = Rails.cache.read("user_dto/#{user_id}")
    return nil unless cached

    # 캐시된 데이터가 UserDto인지 Hash인지 확인
    case cached
    when Dto::UserDto
      cached
    when Hash
      Dto::UserDto.from_data(cached)
    else
      nil
    end
  end

  # 캐시에서 배치 조회
  def fetch_batch_from_cache(user_ids)
    cache_keys = user_ids.map { |id| "user_dto/#{id}" }
    cached_data = Rails.cache.read_multi(*cache_keys)

    result = {}
    cached_data.each do |cache_key, data|
      next unless data

      user_id = cache_key.split("/").last

      case data
      when Dto::UserDto
        result[user_id] = data
      when Hash
        result[user_id] = Dto::UserDto.from_data(data)
      end
    end

    result
  end

  # PostgreSQL에서 User 조회
  def fetch_from_database(user_id)
    user = User.find_by(id: user_id)
    return nil unless user

    @stats[:db_queries] += 1
    Dto::UserDto.from_user(user)
  end

  # User 데이터 캐싱
  def cache_user_data(user_dto, user_id = nil)
    cache_key = "user_dto/#{user_id || user_dto.id}"
    Rails.cache.write(cache_key, user_dto, expires_in: CACHE_TTL)
  end

  # 배치 User 프리로드 (N+1 방지)
  def preload_users_to_cache(user_ids)
    
    # 캐시에 없는 User만 조회
    missing_ids = user_ids.reject { |id| Rails.cache.exist?("user_dto/#{id}") }
    
    return if missing_ids.empty?
    
    # 한 번의 쿼리로 모든 User 조회
    users = User.where(id: missing_ids)
    
    users.each do |user|
      user_dto = Dto::UserDto.from_user(user)
      cache_user_data(user_dto, user.id.to_s)
    end
    
    @stats[:db_queries] += 1
  end

  # 백그라운드 동기화 스케줄링
  def schedule_bulk_sync_if_needed(tasks)
    user_ids = tasks.flat_map { |t| [ t.assignee_id, t.reviewer_id ] }.compact.uniq

    # 모든 관련 스냅샷 조회
    snapshots = UserSnapshot.where(user_id: { "$in" => user_ids }).index_by(&:user_id)

    stale_user_ids = user_ids.select do |user_id|
      snapshot = snapshots[user_id]
      snapshot.nil? || snapshot.stale?(SNAPSHOT_TTL)
    end

    if stale_user_ids.any?
      @stats[:background_syncs] += stale_user_ids.size

      # 배치로 동기화 Job 스케줄링
      BulkUserSnapshotSyncJob.perform_later(stale_user_ids)

      Rails.logger.info "[UserDataResolver] #{stale_user_ids.size}개 User 백그라운드 동기화 예약"
    end
  end

  # 성능 측정 래퍼
  def with_performance_tracking(operation_name)
    start_time = Time.current

    result = yield

    elapsed_time = Time.current - start_time

    if elapsed_time > 0.05 # 50ms 이상
      Rails.logger.warn "[UserDataResolver] #{operation_name} took #{(elapsed_time * 1000).round(2)}ms"
    end

    result
  end
end
