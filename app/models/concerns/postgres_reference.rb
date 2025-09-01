# app/models/concerns/postgres_reference.rb
module PostgresReference
  extend ActiveSupport::Concern
  
  included do
    # PostgreSQL 참조를 위한 캐싱된 접근자 메서드들
    
    # 사용자 정보 가져오기
    def user
      @user ||= UserCacheService.get_user(respond_to?(:user_id) ? user_id : nil)
    end
    
    def assignee
      @assignee ||= UserCacheService.get_user(assignee_id) if respond_to?(:assignee_id)
    end
    
    def reviewer
      @reviewer ||= UserCacheService.get_user(reviewer_id) if respond_to?(:reviewer_id)
    end
    
    def author
      @author ||= UserCacheService.get_user(author_id) if respond_to?(:author_id)
    end
    
    def actor
      @actor ||= UserCacheService.get_user(actor_id) if respond_to?(:actor_id)
    end
    
    def created_by
      @created_by ||= UserCacheService.get_user(created_by_id) if respond_to?(:created_by_id)
    end
    
    # 조직 정보 가져오기
    def organization
      @organization ||= UserCacheService.get_organization(organization_id) if respond_to?(:organization_id)
    end
    
    # 팀 정보 가져오기
    def team
      @team ||= UserCacheService.get_team(team_id) if respond_to?(:team_id)
    end
    
    # 서비스 정보 가져오기
    def service
      @service ||= UserCacheService.get_service(service_id) if respond_to?(:service_id)
    end
    
    # 참가자들 정보 일괄 조회
    def participants_users
      return [] unless respond_to?(:participants)
      @participants_users ||= User.cached_find_multi(participants).values.compact
    end
    
    # 언급된 사용자들 정보 일괄 조회
    def mentioned_users
      return [] unless respond_to?(:mentioned_user_ids)
      @mentioned_users ||= User.cached_find_multi(mentioned_user_ids).values.compact
    end
    
    # 감시자들 정보 일괄 조회
    def watchers_users
      return [] unless respond_to?(:watchers)
      @watchers_users ||= User.cached_find_multi(watchers).values.compact
    end
  end
  
  class_methods do
    # 여러 문서에 대한 사용자 정보 프리로드
    def preload_users(documents)
      user_ids = documents.flat_map do |doc|
        ids = []
        ids << doc.assignee_id if doc.respond_to?(:assignee_id)
        ids << doc.reviewer_id if doc.respond_to?(:reviewer_id)
        ids << doc.author_id if doc.respond_to?(:author_id)
        ids << doc.actor_id if doc.respond_to?(:actor_id)
        ids << doc.created_by_id if doc.respond_to?(:created_by_id)
        ids.concat(doc.participants) if doc.respond_to?(:participants)
        ids.concat(doc.mentioned_user_ids) if doc.respond_to?(:mentioned_user_ids)
        ids.compact
      end.uniq
      
      # 일괄 캐싱
      User.cached_find_multi(user_ids)
    end
    
    # 조직/팀 정보 프리로드
    def preload_organizations(documents)
      org_ids = documents.map { |d| d.organization_id if d.respond_to?(:organization_id) }.compact.uniq
      team_ids = documents.map { |d| d.team_id if d.respond_to?(:team_id) }.compact.uniq
      
      org_ids.each { |id| UserCacheService.get_organization(id) }
      team_ids.each { |id| UserCacheService.get_team(id) }
    end
  end
end