# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantSwitcher, type: :service do
  let(:user) { create(:user) }
  let(:session) { {} }
  
  let(:org_a) { create(:organization, subdomain: 'org-a', name: 'Organization A') }
  let(:org_b) { create(:organization, subdomain: 'org-b', name: 'Organization B') }
  let(:org_c) { create(:organization, subdomain: 'org-c', name: 'Organization C', active: false) }
  
  let!(:membership_a) { create(:organization_membership, user: user, organization: org_a, role: 'owner') }
  let!(:membership_b) { create(:organization_membership, user: user, organization: org_b, role: 'admin') }
  let!(:membership_c) { create(:organization_membership, user: user, organization: org_c, role: 'member') }
  
  let(:switcher) { TenantSwitcher.new(user, session) }

  before do
    ActsAsTenant.current_tenant = org_a
    allow(DomainService).to receive(:organization_url).and_call_original
  end

  describe "조직 전환 기능" do
    context "유효한 조직으로 전환" do
      it "사용자가 멤버인 조직으로 성공적으로 전환한다" do
        # Given: 사용자가 org-b의 멤버
        
        # When: org-b로 전환
        result = switcher.switch_to!('org-b', record_history: true)
        
        # Then: 전환 성공
        expect(result[:success]).to be true
        expect(result[:message]).to include('Organization B으로 전환되었습니다')
        expect(result[:redirect_url]).to include('org-b.creatia.local')
        expect(ActsAsTenant.current_tenant).to eq(org_b)
        
        # And: 세션에 조직 정보 저장
        expect(session[:current_organization_id]).to eq(org_b.id)
      end

      it "Organization 객체로도 전환할 수 있다" do
        # When: Organization 객체로 전환
        result = switcher.switch_to!(org_b)
        
        # Then: 전환 성공
        expect(result[:success]).to be true
        expect(ActsAsTenant.current_tenant).to eq(org_b)
      end

      it "전환 이력을 기록한다" do
        # When: 이력 기록 옵션과 함께 전환
        switcher.switch_to!('org-b', record_history: true)
        
        # Then: 세션에 전환 이력 저장
        history = session[:organization_switch_history]
        expect(history).to be_present
        expect(history.last['subdomain']).to eq('org-b')
        expect(history.last['name']).to eq('Organization B')
      end
    end

    context "전환 실패 시나리오" do
      it "존재하지 않는 조직으로 전환 시도시 실패한다" do
        # When: 존재하지 않는 조직으로 전환 시도
        result = switcher.switch_to!('nonexistent-org')
        
        # Then: 전환 실패
        expect(result[:success]).to be false
        expect(result[:error]).to include('조직을 찾을 수 없습니다')
        expect(ActsAsTenant.current_tenant).to eq(org_a) # 원래 조직 유지
      end

      it "멤버가 아닌 조직으로 전환 시도시 실패한다" do
        # Given: 사용자가 멤버가 아닌 조직
        other_org = create(:organization, subdomain: 'other-org')
        
        # When: 권한 없는 조직으로 전환 시도
        result = switcher.switch_to!('other-org')
        
        # Then: 전환 실패
        expect(result[:success]).to be false
        expect(result[:error]).to include('접근할 권한이 없습니다')
        expect(ActsAsTenant.current_tenant).to eq(org_a) # 원래 조직 유지
      end

      it "비활성화된 조직으로 전환 시도시 실패한다" do
        # When: 비활성화된 조직으로 전환 시도
        result = switcher.switch_to!('org-c')
        
        # Then: 전환 실패
        expect(result[:success]).to be false
        expect(result[:error]).to include('비활성화된 조직입니다')
        expect(ActsAsTenant.current_tenant).to eq(org_a) # 원래 조직 유지
      end

      it "이미 현재 조직으로 전환 시도시 적절한 메시지를 반환한다" do
        # When: 현재 조직으로 전환 시도
        result = switcher.switch_to!('org-a')
        
        # Then: 적절한 메시지
        expect(result[:success]).to be false
        expect(result[:error]).to include('이미 현재 조직입니다')
      end
    end
  end

  describe "전환 가능성 확인" do
    it "사용자가 멤버인 조직은 전환 가능하다" do
      # When & Then: 멤버인 조직은 전환 가능
      expect(switcher.can_switch_to?('org-a')).to be true
      expect(switcher.can_switch_to?('org-b')).to be true
      expect(switcher.can_switch_to?(org_b)).to be true
    end

    it "사용자가 멤버가 아닌 조직은 전환 불가능하다" do
      # Given: 멤버가 아닌 조직
      other_org = create(:organization, subdomain: 'other-org')
      
      # When & Then: 전환 불가능
      expect(switcher.can_switch_to?('other-org')).to be false
      expect(switcher.can_switch_to?(other_org)).to be false
    end

    it "비활성화된 조직은 전환 불가능하다" do
      # When & Then: 비활성화된 조직은 전환 불가능
      expect(switcher.can_switch_to?('org-c')).to be false
    end

    it "존재하지 않는 조직은 전환 불가능하다" do
      # When & Then: 존재하지 않는 조직은 전환 불가능
      expect(switcher.can_switch_to?('nonexistent')).to be false
    end
  end

  describe "전환 가능한 조직 목록" do
    it "사용자가 접근 가능한 활성 조직만 반환한다" do
      # When: 전환 가능한 조직 목록 조회
      available_orgs = switcher.available_organizations
      
      # Then: 활성 조직만 포함
      expect(available_orgs).to include(org_a, org_b)
      expect(available_orgs).not_to include(org_c) # 비활성화된 조직 제외
    end

    it "조직 목록을 이름순으로 정렬한다" do
      # When: 조직 목록 조회
      available_orgs = switcher.available_organizations
      
      # Then: 이름순 정렬
      org_names = available_orgs.pluck(:name)
      expect(org_names).to eq(org_names.sort)
    end
  end

  describe "조직에서 나가기" do
    it "현재 조직에서 나가면 테넌트 컨텍스트가 클리어된다" do
      # Given: 현재 조직이 설정된 상태
      expect(ActsAsTenant.current_tenant).to eq(org_a)
      
      # When: 현재 조직에서 나가기
      result = switcher.leave_current_organization!
      
      # Then: 테넌트 컨텍스트 클리어
      expect(result[:success]).to be true
      expect(result[:message]).to include('Organization A에서 나왔습니다')
      expect(ActsAsTenant.current_tenant).to be_nil
      expect(session[:current_organization_id]).to be_nil
    end

    it "현재 조직이 없으면 적절한 메시지를 반환한다" do
      # Given: 현재 조직이 설정되지 않음
      ActsAsTenant.current_tenant = nil
      
      # When: 조직에서 나가기 시도
      result = switcher.leave_current_organization!
      
      # Then: 적절한 메시지
      expect(result[:success]).to be false
      expect(result[:error]).to include('현재 조직이 설정되지 않았습니다')
    end
  end

  describe "전환기 UI 데이터" do
    before do
      # 전환 이력 설정
      session[:organization_switch_history] = [
        { 'subdomain' => 'org-b', 'name' => 'Organization B', 'switched_at' => 1.hour.ago.iso8601 }
      ]
      
      # 마지막 접근 시간 설정
      session[:last_accessed_organizations] = {
        'org-a' => 30.minutes.ago.iso8601,
        'org-b' => 2.hours.ago.iso8601
      }
    end

    it "전환기 UI에 필요한 모든 데이터를 제공한다" do
      # When: 전환기 데이터 조회
      data = switcher.switcher_data
      
      # Then: 필요한 모든 정보 포함
      expect(data).to include(
        :current_organization,
        :available_organizations,
        :total_organizations,
        :switch_history
      )
      
      # 현재 조직 정보
      expect(data[:current_organization]).to include(
        id: org_a.id,
        name: org_a.name,
        subdomain: org_a.subdomain
      )
      
      # 전환 가능한 조직 정보
      available = data[:available_organizations]
      expect(available).to be_an(Array)
      expect(available.first).to include(
        :id, :name, :subdomain, :display_name, :plan, :role, :is_current, :url
      )
    end

    it "각 조직의 상세 정보를 포함한다" do
      # When: 전환기 데이터 조회
      data = switcher.switcher_data
      
      # Then: 각 조직별 상세 정보
      org_a_data = data[:available_organizations].find { |org| org[:subdomain] == 'org-a' }
      expect(org_a_data).to include(
        role: 'owner',
        is_current: true,
        member_count: 1
      )
      
      org_b_data = data[:available_organizations].find { |org| org[:subdomain] == 'org-b' }
      expect(org_b_data).to include(
        role: 'admin',
        is_current: false
      )
    end
  end

  describe "전환 이력 관리" do
    it "최근 전환 이력을 제한된 개수로 반환한다" do
      # Given: 여러 전환 이력
      10.times do |i|
        session[:organization_switch_history] ||= []
        session[:organization_switch_history] << {
          'subdomain' => "org-#{i}",
          'name' => "Organization #{i}",
          'switched_at' => i.hours.ago.iso8601
        }
      end
      
      # When: 최근 5개 이력 조회
      history = switcher.recent_switch_history(5)
      
      # Then: 5개만 반환
      expect(history.size).to eq(5)
    end

    it "전환 이력의 중복을 제거한다" do
      # Given: 동일 조직으로 여러 번 전환
      3.times do
        switcher.switch_to!('org-b', record_history: true)
      end
      
      # When: 전환 이력 조회
      history = switcher.recent_switch_history
      
      # Then: 중복 없이 하나만 기록
      org_b_entries = history.select { |entry| entry[:subdomain] == 'org-b' }
      expect(org_b_entries.size).to eq(1)
    end

    it "전환 이력을 최대 10개까지만 유지한다" do
      # Given: 15개의 조직 생성 및 전환
      15.times do |i|
        org = create(:organization, subdomain: "test-org-#{i}")
        create(:organization_membership, user: user, organization: org, role: 'member')
        switcher.switch_to!("test-org-#{i}", record_history: true)
      end
      
      # When: 전환 이력 확인
      history_count = session[:organization_switch_history].size
      
      # Then: 최대 10개만 유지
      expect(history_count).to eq(10)
    end
  end

  describe "즐겨찾기 조직" do
    it "최근에 접근한 조직들을 즐겨찾기로 반환한다" do
      # Given: 최근 접근 이력
      session[:organization_switch_history] = [
        { 'subdomain' => 'org-b', 'name' => 'Organization B', 'switched_at' => 1.hour.ago.iso8601 },
        { 'subdomain' => 'org-a', 'name' => 'Organization A', 'switched_at' => 2.hours.ago.iso8601 }
      ]
      
      # When: 즐겨찾기 조직 조회
      favorites = switcher.favorite_organizations
      
      # Then: 최근 접근 순으로 반환
      expect(favorites.size).to be <= 3
      expect(favorites.first[:subdomain]).to eq('org-b')
    end
  end

  describe "빠른 전환 옵션" do
    it "자주 사용하는 조직들을 빠른 전환 옵션으로 제공한다" do
      # When: 빠른 전환 옵션 조회
      quick_options = switcher.quick_switch_options
      
      # Then: 제한된 개수의 조직 정보
      expect(quick_options.size).to be <= 5
      expect(quick_options.first).to include(
        :subdomain, :name, :display_name, :role, :is_current, :url
      )
    end

    it "현재 조직을 올바르게 표시한다" do
      # When: 빠른 전환 옵션 조회
      quick_options = switcher.quick_switch_options
      
      # Then: 현재 조직 표시
      current_org_option = quick_options.find { |opt| opt[:is_current] }
      expect(current_org_option[:subdomain]).to eq('org-a')
    end
  end

  describe "전환 통계" do
    it "사용자의 조직 관련 통계를 제공한다" do
      # When: 전환 통계 조회
      stats = switcher.switch_statistics
      
      # Then: 통계 정보 포함
      expect(stats).to include(
        total_organizations: 2, # 활성 조직만
        owned_organizations: 1,
        administered_organizations: 2, # owner + admin
        current_role: 'owner'
      )
    end
  end
end
