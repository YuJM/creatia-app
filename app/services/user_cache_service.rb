# app/services/user_cache_service.rb
class UserCacheService
  class << self
    # Rails.cache를 사용한 다층 캐싱
    
    # 1. 로컬 메모리 캐시 (Request 단위)
    def request_cache
      Thread.current[:user_cache] ||= {}
    end
    
    def clear_request_cache
      Thread.current[:user_cache] = {}
    end
    
    # 2. 사용자 정보 조회 (다층 캐싱)
    def get_user(user_id)
      return nil unless user_id.present?
      
      # L1: 요청 레벨 캐시
      cached = request_cache[user_id]
      return cached if cached
      
      # L2: Rails.cache
      user = User.cached_find(user_id)
      
      # L1 캐시에 저장
      request_cache[user_id] = user if user
      
      user
    end
    
    # 3. 대량 사용자 정보 조회 (MongoDB 문서에서 사용)
    def get_users_for_mongodb_docs(documents)
      user_ids = extract_user_ids(documents)
      return {} if user_ids.empty?
      
      # 일괄 조회로 N+1 방지
      users = User.cached_find_multi(user_ids)
      
      # 결과를 해시로 변환
      users.transform_values do |user|
        next nil unless user
        {
          id: user.id,
          name: user.name,
          email: user.email,
          avatar_url: user.avatar_url
        }
      end.compact
    end
    
    # 4. 조직/팀 정보 캐싱
    def get_organization(org_id)
      return nil unless org_id.present?
      
      Rails.cache.fetch("org/#{org_id}", expires_in: 2.hours) do
        Organization.find_by(id: org_id)
      end
    end
    
    def get_team(team_id)
      return nil unless team_id.present?
      
      Rails.cache.fetch("team/#{team_id}", expires_in: 2.hours) do
        Team.find_by(id: team_id)
      end
    end
    
    # 5. 서비스 정보 캐싱 (Task ID 생성에 자주 사용)
    def get_service(service_id)
      return nil unless service_id.present?
      
      Rails.cache.fetch("service/#{service_id}", expires_in: 4.hours) do
        Service.find_by(id: service_id)
      end
    end
    
    # 6. 사용자 권한 캐싱
    def user_permissions(user_id, org_id)
      cache_key = "permissions/#{user_id}/#{org_id}"
      
      Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
        user = User.find_by(id: user_id)
        org = Organization.find_by(id: org_id)
        
        return nil unless user && org
        
        membership = user.organization_memberships.find_by(organization: org)
        
        {
          is_member: membership.present?,
          role: membership&.role,
          permissions: membership&.permissions || []
        }
      end
    end
    
    # 7. 캐시 워밍 (프리로드)
    def warm_cache_for_sprint(sprint)
      # Sprint에 관련된 모든 사용자 정보 미리 로드
      task_ids = sprint.task_ids
      tasks = Mongodb::MongoTask.where(:_id.in => task_ids)
      
      user_ids = tasks.flat_map do |task|
        [task.assignee_id, task.reviewer_id, task.created_by_id].compact
      end.uniq
      
      # 일괄 캐싱
      User.cached_find_multi(user_ids)
    end
    
    private
    
    def extract_user_ids(documents)
      documents.flat_map do |doc|
        case doc
        when Mongodb::MongoTask
          [doc.assignee_id, doc.reviewer_id, doc.created_by_id, *doc.participants].compact
        when Mongodb::MongoSprint
          # Sprint 관련 사용자 추출
          []
        when Mongodb::MongoComment
          [doc.author_id, doc.resolved_by_id, *doc.mentioned_user_ids].compact
        when Mongodb::MongoActivity
          [doc.actor_id, *doc.mentioned_user_ids].compact
        else
          []
        end
      end.uniq
    end
  end
end