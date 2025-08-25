# frozen_string_literal: true

# OrganizationMembershipSerializer - 조직 멤버십 정보를 직렬화합니다.
class OrganizationMembershipSerializer < BaseSerializer
  # 기본 속성들
  attributes :id, :role, :active, :created_at, :updated_at
  
  # 역할 표시명
  attribute :display_role do |membership|
    membership.display_role
  end
  
  # 사용자 정보 (기본)
  attribute :user do |membership|
    {
      id: membership.user.id,
      email: membership.user.email,
      display_name: membership.user.name || membership.user.email.split('@').first.capitalize
    }
  end
  
  # 사용자 상세 정보 (관리자만 볼 수 있음)
  attribute :user_details, if: :can_admin? do |membership|
    user = membership.user
    {
      username: user.username,
      last_sign_in_at: user.last_sign_in_at,
      sign_in_count: user.sign_in_count,
      provider: user.provider,
      created_at: user.created_at
    }
  end
  
  # 조직 정보 (간소화된 버전)
  attribute :organization, if: proc { |membership, params| 
    !params[:skip_organization] 
  } do |membership|
    {
      id: membership.organization.id,
      name: membership.organization.name,
      subdomain: membership.organization.subdomain,
      display_name: membership.organization.display_name
    }
  end
  
  # 권한 정보
  attribute :permissions do |membership|
    {
      can_manage_members: membership.can_manage_members?,
      can_manage_organization: membership.can_manage_organization?,
      is_admin: membership.admin?,
      is_owner: membership.owner?
    }
  end
  
  # 자신의 멤버십인지 여부
  attribute :is_current_user_membership, if: proc { |membership, params| 
    params[:current_user].present? 
  } do |membership, params|
    membership.user == params[:current_user]
  end
  
  # 멤버십 상태 정보
  attribute :status do |membership|
    if membership.active?
      'active'
    else
      'inactive'
    end
  end
  
  # 가입일로부터 경과 시간
  attribute :member_since, if: proc { |membership, params| 
    params[:time_helper].present? 
  } do |membership, params|
    params[:time_helper].time_ago_in_words(membership.created_at)
  end
end
