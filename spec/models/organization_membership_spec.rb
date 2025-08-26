# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrganizationMembership, type: :model do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }

  describe "멤버십 생성 및 기본 설정" do
    context "유효한 멤버십 생성" do
      it "사용자와 조직으로 멤버십을 생성할 수 있다" do
        # Given: 사용자와 조직
        membership = build(:organization_membership, user: user, organization: organization, role: 'member')
        
        # When: 멤버십 저장
        # Then: 성공적으로 생성됨
        expect(membership).to be_valid
        expect { membership.save! }.not_to raise_error
      end

      it "멤버십은 기본적으로 활성화 상태로 생성된다" do
        # When: 멤버십 생성
        membership = create(:organization_membership, user: user, organization: organization)
        
        # Then: 기본적으로 활성화됨
        expect(membership.active?).to be true
      end

      it "역할이 지정되지 않으면 기본적으로 member 역할이 된다" do
        # Given: 역할을 지정하지 않은 멤버십
        membership = OrganizationMembership.new(user: user, organization: organization)
        
        # When: 유효성 검사 실행 (콜백 트리거)
        membership.valid?
        
        # Then: 기본 역할이 설정됨
        expect(membership.role).to eq('member')
      end
    end

    context "멤버십 고유성 제약" do
      it "동일한 사용자와 조직의 멤버십은 중복될 수 없다" do
        # Given: 기존 멤버십
        create(:organization_membership, user: user, organization: organization)
        
        # When: 같은 사용자-조직으로 중복 멤버십 생성 시도
        duplicate_membership = build(:organization_membership, user: user, organization: organization)
        
        # Then: 유효하지 않음
        expect(duplicate_membership).not_to be_valid
        expect(duplicate_membership.errors[:user_id]).to include("이미 이 조직의 멤버입니다")
      end

      it "같은 사용자라도 다른 조직의 멤버십은 가능하다" do
        # Given: 다른 조직
        other_organization = create(:organization, subdomain: 'other-org')
        create(:organization_membership, user: user, organization: organization)
        
        # When: 다른 조직의 멤버십 생성
        other_membership = build(:organization_membership, user: user, organization: other_organization)
        
        # Then: 유효함
        expect(other_membership).to be_valid
      end
    end
  end

  describe "역할 관리" do
    let(:membership) { create(:organization_membership, user: user, organization: organization) }

    context "역할 유효성 검증" do
      it "유효한 역할만 허용한다" do
        # Given: 유효한 역할들
        valid_roles = %w[owner admin member viewer]
        
        valid_roles.each do |role|
          # When: 각 역할로 멤버십 생성
          membership = build(:organization_membership, user: user, organization: organization, role: role)
          
          # Then: 유효함
          expect(membership).to be_valid, "#{role} should be valid"
        end
      end

      it "유효하지 않은 역할은 거부한다" do
        # Given: 유효하지 않은 역할
        membership = build(:organization_membership, user: user, organization: organization, role: 'invalid_role')
        
        # When: 유효성 검사
        # Then: 유효하지 않음
        expect(membership).not_to be_valid
        expect(membership.errors[:role]).to include("is not included in the list")
      end
    end

    context "역할별 권한 확인" do
      it "소유자는 모든 관리 권한을 가진다" do
        # Given: 소유자 멤버십
        membership.update!(role: 'owner')
        
        # When & Then: 권한 확인
        expect(membership.owner?).to be true
        expect(membership.admin?).to be true
        expect(membership.can_manage_members?).to be true
        expect(membership.can_manage_organization?).to be true
      end

      it "관리자는 멤버 관리 권한을 가지지만 조직 관리는 불가능하다" do
        # Given: 관리자 멤버십
        membership.update!(role: 'admin')
        
        # When & Then: 권한 확인
        expect(membership.owner?).to be false
        expect(membership.admin?).to be true
        expect(membership.can_manage_members?).to be true
        expect(membership.can_manage_organization?).to be false
      end

      it "일반 멤버는 관리 권한이 없다" do
        # Given: 일반 멤버 멤버십
        membership.update!(role: 'member')
        
        # When & Then: 권한 확인
        expect(membership.owner?).to be false
        expect(membership.admin?).to be false
        expect(membership.can_manage_members?).to be false
        expect(membership.can_manage_organization?).to be false
      end

      it "뷰어는 읽기 권한만 가진다" do
        # Given: 뷰어 멤버십
        membership.update!(role: 'viewer')
        
        # When & Then: 권한 확인
        expect(membership.owner?).to be false
        expect(membership.admin?).to be false
        expect(membership.can_manage_members?).to be false
        expect(membership.can_manage_organization?).to be false
      end
    end

    context "역할 표시명" do
      it "각 역할의 한국어 표시명을 제공한다" do
        # Given: 역할별 표시명 매핑
        role_display_names = {
          'owner' => '소유자',
          'admin' => '관리자',
          'member' => '멤버',
          'viewer' => '뷰어'
        }
        
        role_display_names.each do |role, display_name|
          # When: 역할 설정 및 표시명 조회
          membership.update!(role: role)
          
          # Then: 올바른 표시명 반환
          expect(membership.display_role).to eq(display_name)
        end
      end
    end
  end

  describe "소유자 관리" do
    let(:original_owner) { create(:user) }
    let(:new_owner) { create(:user) }
    let!(:owner_membership) { create(:organization_membership, user: original_owner, organization: organization, role: 'owner') }

    it "새로운 소유자가 지정되면 기존 소유자는 관리자가 된다" do
      # When: 새로운 사용자를 소유자로 지정
      new_owner_membership = create(:organization_membership, user: new_owner, organization: organization, role: 'owner')
      
      # Then: 기존 소유자는 관리자로 변경됨
      expect(owner_membership.reload.role).to eq('admin')
      expect(new_owner_membership.role).to eq('owner')
    end

    it "조직에는 항상 하나의 소유자만 존재한다" do
      # Given: 새로운 소유자 생성
      create(:organization_membership, user: new_owner, organization: organization, role: 'owner')
      
      # When: 소유자 역할 멤버십 수 조회
      owner_count = organization.organization_memberships.where(role: 'owner').count
      
      # Then: 소유자는 하나만 존재
      expect(owner_count).to eq(1)
    end
  end

  describe "멤버십 스코프" do
    let!(:active_membership) { create(:organization_membership, user: user, organization: organization, active: true) }
    let!(:inactive_membership) { create(:organization_membership, user: create(:user), organization: organization, active: false) }

    it "활성 멤버십만 조회할 수 있다" do
      # When: 활성 멤버십 조회
      active_memberships = organization.organization_memberships.active
      
      # Then: 활성 멤버십만 포함
      expect(active_memberships).to include(active_membership)
      expect(active_memberships).not_to include(inactive_membership)
    end

    context "역할별 스코프" do
      let!(:owner) { create(:organization_membership, user: create(:user), organization: organization, role: 'owner') }
      let!(:admin) { create(:organization_membership, user: create(:user), organization: organization, role: 'admin') }
      let!(:member) { create(:organization_membership, user: create(:user), organization: organization, role: 'member') }
      let!(:viewer) { create(:organization_membership, user: create(:user), organization: organization, role: 'viewer') }

      it "소유자만 조회할 수 있다" do
        # When: 소유자 스코프 조회
        owners = organization.organization_memberships.owners
        
        # Then: 소유자만 포함
        expect(owners).to include(owner)
        expect(owners).not_to include(admin, member, viewer)
      end

      it "관리자(소유자 포함)를 조회할 수 있다" do
        # When: 관리자 스코프 조회
        admins = organization.organization_memberships.admins
        
        # Then: 소유자와 관리자 포함
        expect(admins).to include(owner, admin)
        expect(admins).not_to include(member, viewer)
      end

      it "멤버(관리자 이상 포함)를 조회할 수 있다" do
        # When: 멤버 스코프 조회
        members = organization.organization_memberships.members
        
        # Then: 뷰어를 제외한 모든 역할 포함
        expect(members).to include(owner, admin, member)
        expect(members).not_to include(viewer)
      end

      it "특정 역할로 필터링할 수 있다" do
        # When: 특정 역할 조회
        member_role = organization.organization_memberships.by_role('member')
        
        # Then: 해당 역할만 포함
        expect(member_role).to include(member)
        expect(member_role).not_to include(owner, admin, viewer)
      end
    end
  end

  describe "멤버십 상태 관리" do
    let(:membership) { create(:organization_membership, user: user, organization: organization) }

    it "멤버십을 비활성화할 수 있다" do
      # Given: 활성 멤버십
      expect(membership.active?).to be true
      
      # When: 멤버십 비활성화
      membership.update!(active: false)
      
      # Then: 비활성화됨
      expect(membership.active?).to be false
    end

    it "비활성화된 멤버십은 조직 멤버로 인식되지 않는다" do
      # Given: 비활성화된 멤버십
      membership.update!(active: false)
      
      # When: 조직 멤버 여부 확인
      # Then: 멤버로 인식되지 않음
      expect(organization.member?(user)).to be false
    end

    it "멤버십을 다시 활성화할 수 있다" do
      # Given: 비활성화된 멤버십
      membership.update!(active: false)
      
      # When: 멤버십 재활성화
      membership.update!(active: true)
      
      # Then: 다시 활성화됨
      expect(membership.active?).to be true
      expect(organization.member?(user)).to be true
    end
  end

  describe "멤버십 연관 관계" do
    let!(:membership) { create(:organization_membership, user: user, organization: organization) }

    it "사용자와 조직에 올바르게 연결된다" do
      # When & Then: 연관 관계 확인
      expect(membership.user).to eq(user)
      expect(membership.organization).to eq(organization)
      expect(user.organization_memberships).to include(membership)
      expect(organization.organization_memberships).to include(membership)
    end

    it "사용자를 통해 조직에 접근할 수 있다" do
      # When: 사용자의 조직 조회
      user_organizations = user.organizations
      
      # Then: 조직이 포함됨
      expect(user_organizations).to include(organization)
    end

    it "조직을 통해 사용자에 접근할 수 있다" do
      # When: 조직의 사용자 조회
      organization_users = organization.users
      
      # Then: 사용자가 포함됨
      expect(organization_users).to include(user)
    end
  end

  describe "멤버십 데이터 무결성" do
    it "사용자 없이는 멤버십을 생성할 수 없다" do
      # Given: 사용자 없는 멤버십
      membership = build(:organization_membership, user: nil, organization: organization)
      
      # When: 유효성 검사
      # Then: 유효하지 않음
      expect(membership).not_to be_valid
      expect(membership.errors[:user]).to include("must exist")
    end

    it "조직 없이는 멤버십을 생성할 수 없다" do
      # Given: 조직 없는 멤버십
      membership = build(:organization_membership, user: user, organization: nil)
      
      # When: 유효성 검사
      # Then: 유효하지 않음
      expect(membership).not_to be_valid
      expect(membership.errors[:organization]).to include("must exist")
    end

    it "역할 없이는 멤버십을 생성할 수 없다" do
      # Given: 역할 없는 멤버십 (콜백 비활성화)
      membership = OrganizationMembership.new(user: user, organization: organization)
      
      # When: 콜백을 비활성화하고 role을 nil로 유지
      allow(membership).to receive(:set_default_role)
      membership.role = nil
      membership.valid?
      
      # Then: 유효하지 않음
      expect(membership).not_to be_valid
      expect(membership.errors[:role]).to include("can't be blank")
    end
  end

  describe "멤버십 검색 및 조회" do
    let!(:owner_membership) { create(:organization_membership, user: create(:user), organization: organization, role: 'owner') }
    let!(:admin_membership) { create(:organization_membership, user: create(:user), organization: organization, role: 'admin') }
    let!(:member_membership) { create(:organization_membership, user: user, organization: organization, role: 'member') }

    it "특정 사용자의 멤버십을 찾을 수 있다" do
      # When: 특정 사용자의 멤버십 조회
      found_membership = organization.organization_memberships.find_by(user: user)
      
      # Then: 올바른 멤버십 반환
      expect(found_membership).to eq(member_membership)
    end

    it "조직의 소유자를 빠르게 찾을 수 있다" do
      # When: 조직 소유자 조회
      owner = organization.owner
      
      # Then: 올바른 소유자 반환
      expect(owner).to eq(owner_membership.user)
    end

    it "관리자 권한을 가진 모든 사용자를 조회할 수 있다" do
      # When: 관리자들 조회
      admins = organization.admins
      
      # Then: 소유자와 관리자 포함
      expect(admins).to include(owner_membership.user, admin_membership.user)
      expect(admins).not_to include(member_membership.user)
    end
  end
end