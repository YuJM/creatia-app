# frozen_string_literal: true

# OrganizationSerializer - 조직 정보를 직렬화합니다.
class OrganizationSerializer < BaseSerializer
  # 기본 속성들
  attributes :id, :name, :subdomain, :plan, :active, :created_at, :updated_at
  
  # 조건부 속성 - 설명은 멤버만 볼 수 있음
  attribute :description, if: :can_view_details? do |organization|
    organization.description
  end
  
  # 표시용 이름
  attribute :display_name do |organization|
    organization.display_name
  end
  
  # 현재 사용자의 역할 (해당 조직에서)
  attribute :current_user_role do |organization|
    if respond_to?(:params) && params[:current_user]
      params[:current_user].role_in(organization)
    end
  end
  
  # 멤버 수 (관리자만 볼 수 있음)
  attribute :members_count, if: :can_admin? do |organization|
    organization.organization_memberships.active.count
  end
  
  # 소유자 정보 (관리자만 볼 수 있음)
  attribute :owner, if: :can_admin? do |organization|
    owner = organization.owner
    if owner
      {
        id: owner.id,
        email: owner.email,
        name: owner.name
      }
    end
  end
  
  # 조직 설정 (소유자만 볼 수 있음)
  attribute :settings, if: :is_owner? do |organization|
    {
      can_invite_members: true,
      public_signup: false,
      require_email_verification: true
    }
  end
  
  # 멤버십 정보 (중첩된 association)
  has_many :organization_memberships, 
           serializer: OrganizationMembershipSerializer,
           if: :can_admin?
end
