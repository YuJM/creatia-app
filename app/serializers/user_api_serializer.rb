# frozen_string_literal: true

# UserApiSerializer - API 엔드포인트용 간단한 사용자 직렬화
# 복잡한 조건부 속성을 제거하고 기본 정보만 제공합니다.
class UserApiSerializer < BaseSerializer
  # 기본 사용자 속성들
  attributes :id, :email, :created_at, :updated_at
  
  # 사용자 이름 (name 컬럼이 있는 경우)
  attribute :name do |user|
    user.respond_to?(:name) ? user.name : nil
  end
  
  # 사용자 역할 (role 컬럼이 있는 경우)
  attribute :role do |user|
    user.respond_to?(:role) ? user.role : nil
  end
  
  # 커스텀 속성 - 표시용 이름
  attribute :display_name do |user|
    if user.respond_to?(:name) && user.name.present?
      user.name
    elsif user.respond_to?(:username) && user.username.present?
      user.username.capitalize
    elsif user.email.present?
      user.email.split('@').first.capitalize
    else
      "사용자"
    end
  end
end