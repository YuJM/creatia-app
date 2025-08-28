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
    params.is_a?(Hash) && params[:include_admin_info] == true 
  } do |user|
    # admin 컬럼이 있다면 사용, 없다면 false 반환
    user.respond_to?(:admin?) ? user.admin? : false
  end
  
  # 시간 헬퍼를 사용한 상대 시간 표시
  attribute :joined_ago, if: proc { |user, params| 
    params.is_a?(Hash) && params[:time_helper].present? 
  } do |user, params|
    params[:time_helper].time_ago_in_words(user.created_at)
  end
  
  # 멀티테넌트 관련 속성들
  
  # 현재 조직에서의 역할
  attribute :current_organization_role, if: proc { |user, params| 
    params.is_a?(Hash) && params[:current_organization].present? 
  } do |user, params|
    organization = params[:current_organization]
    user.role_in(organization)
  end
  
  # 현재 조직에서의 멤버십 정보
  attribute :current_membership, if: proc { |user, params| 
    params.is_a?(Hash) && params[:current_organization].present? && params[:include_membership] 
  } do |user, params|
    organization = params[:current_organization]
    membership = user.organization_memberships.find_by(
      organization: organization, 
      active: true
    )
    
    if membership
      OrganizationMembershipSerializer.new(
        membership, 
        params: params.merge(skip_organization: true)
      ).serializable_hash
    end
  end
  
  # 사용자가 속한 조직 목록 (전체 조직 컨텍스트에서만)
  attribute :organizations, if: proc { |user, params| 
    params.is_a?(Hash) && params[:include_organizations] 
  } do |user, params|
    user.organizations.active.map do |org|
      {
        id: org.id,
        name: org.name,
        subdomain: org.subdomain,
        display_name: org.display_name,
        role: user.role_in(org),
        is_current: params[:current_organization] == org
      }
    end
  end
  
  # 권한 정보 (현재 조직 기준)
  attribute :permissions, if: proc { |user, params| 
    params.is_a?(Hash) && params[:current_organization].present? 
  } do |user, params|
    organization = params[:current_organization]
    {
      can_view_organization: user.member_of?(organization),
      can_manage_members: user.admin_of?(organization),
      can_manage_organization: user.owner_of?(organization),
      is_admin: user.admin_of?(organization),
      is_owner: user.owner_of?(organization)
    }
  end
  
  # OAuth 제공자 정보 (제한적 공개)
  attribute :oauth_provider, if: proc { |user, params| 
    params.is_a?(Hash) && params[:include_oauth_info] 
  } do |user|
    user.provider || 'email'
  end
end
