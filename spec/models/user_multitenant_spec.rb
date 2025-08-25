# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, "멀티테넌트 기능", type: :model do
  let(:user) { create(:user) }
  let(:organization_a) { create(:organization, subdomain: 'org-a', name: 'Organization A') }
  let(:organization_b) { create(:organization, subdomain: 'org-b', name: 'Organization B') }
  let(:organization_c) { create(:organization, subdomain: 'org-c', name: 'Organization C') }

  describe "조직 멤버십 관계" do
    context "사용자가 여러 조직의 멤버인 경우" do
      before do
        create(:organization_membership, user: user, organization: organization_a, role: 'owner')
        create(:organization_membership, user: user, organization: organization_b, role: 'admin')
        create(:organization_membership, user: user, organization: organization_c, role: 'member')
      end

      it "사용자는 여러 조직에 속할 수 있다" do
        # When: 사용자의 조직 목록 조회
        user_organizations = user.organizations
        
        # Then: 모든 조직이 포함됨
        expect(user_organizations).to include(organization_a, organization_b, organization_c)
        expect(user_organizations.count).to eq(3)
      end

      it "사용자의 조직별 멤버십을 조회할 수 있다" do
        # When: 사용자의 멤버십 목록 조회
        memberships = user.organization_memberships
        
        # Then: 모든 멤버십이 포함됨
        expect(memberships.count).to eq(3)
        expect(memberships.pluck(:role)).to contain_exactly('owner', 'admin', 'member')
      end

      it "특정 조직에서의 멤버 여부를 확인할 수 있다" do
        # When & Then: 멤버 여부 확인
        expect(user.member_of?(organization_a)).to be true
        expect(user.member_of?(organization_b)).to be true
        expect(user.member_of?(organization_c)).to be true
        
        # 멤버가 아닌 조직
        other_org = create(:organization)
        expect(user.member_of?(other_org)).to be false
      end

      it "특정 조직에서의 역할을 조회할 수 있다" do
        # When & Then: 역할 조회
        expect(user.role_in(organization_a)).to eq('owner')
        expect(user.role_in(organization_b)).to eq('admin')
        expect(user.role_in(organization_c)).to eq('member')
        
        # 멤버가 아닌 조직
        other_org = create(:organization)
        expect(user.role_in(other_org)).to be_nil
      end
    end

    context "조직에 대한 권한 확인" do
      before do
        create(:organization_membership, user: user, organization: organization_a, role: 'owner', active: true)
        create(:organization_membership, user: user, organization: organization_b, role: 'admin', active: true)
        create(:organization_membership, user: user, organization: organization_c, role: 'member', active: false)
      end

      it "사용자가 조직에 접근할 수 있는지 확인한다" do
        # When & Then: 접근 권한 확인 (활성 멤버십만)
        expect(user.can_access?(organization_a)).to be true
        expect(user.can_access?(organization_b)).to be true
        expect(user.can_access?(organization_c)).to be false  # 비활성 멤버십
        
        # 멤버가 아닌 조직
        other_org = create(:organization)
        expect(user.can_access?(other_org)).to be false
      end

      it "조직 소유자 여부를 확인할 수 있다" do
        # When & Then: 소유자 여부 확인
        expect(user.owner_of?(organization_a)).to be true
        expect(user.owner_of?(organization_b)).to be false
        expect(user.owner_of?(organization_c)).to be false
      end

      it "조직 관리자 여부를 확인할 수 있다" do
        # When & Then: 관리자 여부 확인 (소유자도 관리자로 간주)
        expect(user.admin_of?(organization_a)).to be true   # 소유자는 관리자
        expect(user.admin_of?(organization_b)).to be true   # 관리자
        expect(user.admin_of?(organization_c)).to be false  # 일반 멤버
      end
    end
  end

  describe "조직별 권한 관리" do
    context "사용자가 소유한 조직" do
      before do
        create(:organization_membership, user: user, organization: organization_a, role: 'owner')
        create(:organization_membership, user: user, organization: organization_b, role: 'admin')
        create(:organization_membership, user: user, organization: organization_c, role: 'member')
      end

      it "사용자가 소유한 조직만 반환한다" do
        # When: 소유 조직 조회
        owned_orgs = user.owned_organizations
        
        # Then: 소유자 역할의 조직만 포함
        expect(owned_orgs).to include(organization_a)
        expect(owned_orgs).not_to include(organization_b, organization_c)
      end

      it "사용자가 관리하는 조직(소유+관리)을 반환한다" do
        # When: 관리 조직 조회
        administered_orgs = user.administered_organizations
        
        # Then: 소유자 + 관리자 역할의 조직 포함
        expect(administered_orgs).to include(organization_a, organization_b)
        expect(administered_orgs).not_to include(organization_c)
      end
    end

    context "현재 조직 컨텍스트" do
      it "현재 설정된 조직을 반환한다" do
        # Given: 현재 조직 설정
        ActsAsTenant.current_tenant = organization_a
        
        # When: 현재 조직 조회
        current_org = user.current_organization
        
        # Then: 설정된 조직 반환
        expect(current_org).to eq(organization_a)
      end

      it "현재 조직이 설정되지 않으면 nil을 반환한다" do
        # Given: 현재 조직 미설정
        ActsAsTenant.current_tenant = nil
        
        # When: 현재 조직 조회
        current_org = user.current_organization
        
        # Then: nil 반환
        expect(current_org).to be_nil
      end
    end
  end

  describe "OAuth 인증과 조직 관계" do
    context "OAuth로 가입한 사용자" do
      let(:oauth_user) { create(:user, provider: 'github', uid: '123456') }

      it "OAuth 사용자도 조직 멤버십을 가질 수 있다" do
        # Given: OAuth 사용자의 조직 멤버십
        create(:organization_membership, user: oauth_user, organization: organization_a, role: 'member')
        
        # When: OAuth 사용자의 조직 조회
        # Then: 정상적으로 조직에 속함
        expect(oauth_user.member_of?(organization_a)).to be true
        expect(oauth_user.organizations).to include(organization_a)
      end

      it "OAuth 제공자 정보를 유지한다" do
        # When & Then: OAuth 정보 확인
        expect(oauth_user.provider).to eq('github')
        expect(oauth_user.uid).to eq('123456')
      end
    end
  end

  describe "사용자 활동 및 추적" do
    context "마지막 로그인 추적" do
      it "로그인 시 마지막 로그인 시간이 업데이트된다" do
        # Given: 이전 로그인 시간
        old_sign_in_at = 1.day.ago
        user.update!(last_sign_in_at: old_sign_in_at)
        
        # When: 새로운 로그인 (Devise trackable)
        user.update!(last_sign_in_at: Time.current)
        
        # Then: 로그인 시간 업데이트됨
        expect(user.last_sign_in_at).to be > old_sign_in_at
      end
    end

    context "IP 주소 추적" do
      it "마지막 로그인 IP가 기록된다" do
        # When: IP 주소와 함께 로그인
        user.update!(last_sign_in_ip: '192.168.1.100')
        
        # Then: IP 주소 기록됨
        expect(user.last_sign_in_ip).to eq('192.168.1.100')
      end
    end
  end

  describe "조직 컨텍스트에서의 데이터 접근" do
    let!(:membership_a) { create(:organization_membership, user: user, organization: organization_a, role: 'admin') }
    let!(:membership_b) { create(:organization_membership, user: user, organization: organization_b, role: 'member') }

    context "특정 조직 컨텍스트에서 작업" do
      it "현재 조직의 멤버십을 반환한다" do
        # Given: 조직 A 컨텍스트
        ActsAsTenant.current_tenant = organization_a
        
        # When: 현재 멤버십 조회
        current_membership = user.organization_memberships.find_by(organization: organization_a, active: true)
        
        # Then: 해당 조직의 멤버십 반환
        expect(current_membership).to eq(membership_a)
        expect(current_membership.role).to eq('admin')
      end

      it "현재 조직에서의 권한을 확인할 수 있다" do
        # Given: 조직 A 컨텍스트
        ActsAsTenant.current_tenant = organization_a
        
        # When & Then: 현재 조직에서의 권한 확인
        expect(user.admin_of?(organization_a)).to be true
        expect(user.owner_of?(organization_a)).to be false
      end
    end
  end

  describe "조직 관련 검색 및 필터링" do
    context "조직별 사용자 검색" do
      let(:other_user) { create(:user) }
      
      before do
        create(:organization_membership, user: user, organization: organization_a, role: 'admin')
        create(:organization_membership, user: other_user, organization: organization_a, role: 'member')
        create(:organization_membership, user: other_user, organization: organization_b, role: 'owner')
      end

      it "특정 조직의 모든 사용자를 조회할 수 있다" do
        # When: 조직 A의 사용자 조회
        org_a_users = organization_a.users
        
        # Then: 해당 조직의 사용자들만 포함
        expect(org_a_users).to include(user, other_user)
      end

      it "특정 역할의 사용자만 필터링할 수 있다" do
        # When: 조직 A의 관리자 조회
        org_a_admins = organization_a.users.joins(:organization_memberships)
                                           .where(organization_memberships: { role: ['owner', 'admin'] })
        
        # Then: 관리자 권한 사용자만 포함
        expect(org_a_admins).to include(user)
        expect(org_a_admins).not_to include(other_user)
      end
    end
  end

  describe "멀티테넌트 데이터 격리 검증" do
    context "조직 간 데이터 격리" do
      before do
        create(:organization_membership, user: user, organization: organization_a, role: 'member')
        # organization_b에는 멤버십 없음
      end

      it "사용자는 속하지 않은 조직의 정보에 접근할 수 없다" do
        # When & Then: 접근 권한 확인
        expect(user.can_access?(organization_a)).to be true
        expect(user.can_access?(organization_b)).to be false
      end

      it "비활성화된 멤버십으로는 조직에 접근할 수 없다" do
        # Given: 비활성화된 멤버십
        membership = user.organization_memberships.find_by(organization: organization_a)
        membership.update!(active: false)
        
        # When & Then: 접근 권한 확인
        expect(user.can_access?(organization_a)).to be false
      end
    end
  end

  describe "사용자 계정 관리" do
    context "계정 상태" do
      it "활성 사용자는 조직에 접근할 수 있다" do
        # Given: 활성 사용자와 멤버십
        create(:organization_membership, user: user, organization: organization_a, role: 'member')
        
        # When & Then: 접근 권한 확인
        expect(user.can_access?(organization_a)).to be true
      end

      it "사용자 삭제 시 관련 멤버십도 함께 삭제된다" do
        # Given: 사용자의 멤버십
        membership = create(:organization_membership, user: user, organization: organization_a, role: 'member')
        membership_id = membership.id
        
        # When: 사용자 삭제
        user.destroy
        
        # Then: 멤버십도 삭제됨
        expect(OrganizationMembership.find_by(id: membership_id)).to be_nil
      end
    end
  end

  describe "사용자 통계 및 요약 정보" do
    before do
      create(:organization_membership, user: user, organization: organization_a, role: 'owner')
      create(:organization_membership, user: user, organization: organization_b, role: 'admin')
      create(:organization_membership, user: user, organization: organization_c, role: 'member')
    end

    it "사용자의 조직 관련 통계를 제공한다" do
      # When: 사용자의 조직 통계
      stats = {
        total_organizations: user.organizations.count,
        owned_organizations: user.owned_organizations.count,
        administered_organizations: user.administered_organizations.count
      }
      
      # Then: 올바른 통계
      expect(stats[:total_organizations]).to eq(3)
      expect(stats[:owned_organizations]).to eq(1)
      expect(stats[:administered_organizations]).to eq(2)  # owner + admin
    end

    it "사용자의 최고 권한 역할을 반환한다" do
      # When: 사용자의 최고 권한 확인
      highest_role = user.organization_memberships.order(
        Arel.sql("CASE role 
         WHEN 'owner' THEN 1 
         WHEN 'admin' THEN 2 
         WHEN 'member' THEN 3 
         WHEN 'viewer' THEN 4 
         END")
      ).first.role
      
      # Then: 소유자가 최고 권한
      expect(highest_role).to eq('owner')
    end
  end
end
