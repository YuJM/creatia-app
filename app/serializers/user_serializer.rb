# frozen_string_literal: true

# UserSerializer - 사용자 정보를 직렬화합니다.
# 
# 사용 예시:
#   UserSerializer.new(user).serializable_hash
#   # => { "id" => "uuid", "email" => "user@example.com", "createdAt" => "2025-01-01T00:00:00Z" }
class UserSerializer < BaseSerializer
  # 기본 사용자 속성들
  attributes :id, :email, :created_at, :updated_at
  
  # 커스텀 속성 예시
  attribute :display_name do |user|
    if user.name.present?
      user.name
    elsif user.username.present?
      user.username.capitalize
    elsif user.email.present?
      user.email.split('@').first.capitalize
    else
      "사용자"
    end
  end
  
  # 조건부 속성 - admin 정보는 권한이 있을 때만 포함
  attribute :admin, if: proc { |user, params| 
    params[:include_admin_info] == true 
  } do |user|
    # admin 컬럼이 있다면 사용, 없다면 false 반환
    user.respond_to?(:admin?) ? user.admin? : false
  end
  
  # 시간 헬퍼를 사용한 상대 시간 표시
  attribute :joined_ago, if: proc { |user, params| 
    params[:time_helper].present? 
  } do |user, params|
    params[:time_helper].time_ago_in_words(user.created_at)
  end
end
