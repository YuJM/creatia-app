# app/models/concerns/user_cacheable.rb
module UserCacheable
  extend ActiveSupport::Concern

  class_methods do
    # 메모리 캐시를 사용한 사용자 정보 조회
    def cached_find(user_id)
      return nil unless user_id.present?
      
      Rails.cache.fetch("user/#{user_id}", expires_in: 1.hour) do
        User.find_by(id: user_id)
      end
    end

    # 여러 사용자 정보 일괄 조회 (N+1 방지)
    def cached_find_multi(user_ids)
      return {} if user_ids.blank?
      
      user_ids = user_ids.compact.uniq
      cache_keys = user_ids.map { |id| "user/#{id}" }
      
      # 캐시에서 먼저 조회
      cached_users = Rails.cache.read_multi(*cache_keys)
      
      # 캐시에 없는 사용자들만 DB에서 조회
      missing_ids = user_ids - cached_users.values.compact.map(&:id)
      
      if missing_ids.any?
        fresh_users = User.where(id: missing_ids).index_by(&:id)
        
        # 캐시에 저장
        fresh_users.each do |id, user|
          Rails.cache.write("user/#{id}", user, expires_in: 1.hour)
        end
        
        cached_users.merge!(fresh_users.transform_keys { |id| "user/#{id}" })
      end
      
      # 결과 정리
      user_ids.index_with do |id|
        cached_users["user/#{id}"]
      end
    end

    # 사용자 기본 정보만 캐싱 (경량화)
    def cached_basic_info(user_id)
      return nil unless user_id.present?
      
      Rails.cache.fetch("user_basic/#{user_id}", expires_in: 2.hours) do
        user = User.find_by(id: user_id)
        next nil unless user
        
        {
          id: user.id,
          name: user.name,
          email: user.email,
          avatar_url: user.avatar_url,
          role: user.role
        }
      end
    end

    # 캐시 무효화
    def invalidate_cache(user_id)
      Rails.cache.delete("user/#{user_id}")
      Rails.cache.delete("user_basic/#{user_id}")
    end
  end

  included do
    # 사용자 정보 업데이트 시 캐시 무효화
    after_update :invalidate_user_cache
    after_destroy :invalidate_user_cache
    
    private
    
    def invalidate_user_cache
      self.class.invalidate_cache(id)
    end
  end
end