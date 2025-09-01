# frozen_string_literal: true

require 'rails_helper'

RSpec.feature "조직 관리 및 권한 시스템", type: :feature do
  let(:owner) { create(:user, email: 'owner@creatia.local') }
  let(:admin) { create(:user, email: 'admin@creatia.local') }
  let(:member) { create(:user, email: 'member@creatia.local') }
  let(:viewer) { create(:user, email: 'viewer@creatia.local') }
  let(:outsider) { create(:user, email: 'outsider@creatia.local') }
  
  let(:organization) { create(:organization, subdomain: 'testorg') }
  
  let!(:owner_membership) { create(:organization_membership, user: owner, organization: organization, role: 'owner') }
  let!(:admin_membership) { create(:organization_membership, user: admin, organization: organization, role: 'admin') }
  let!(:member_membership) { create(:organization_membership, user: member, organization: organization, role: 'member') }
  let!(:viewer_membership) { create(:organization_membership, user: viewer, organization: organization, role: 'viewer') }

  before do
    allow(DomainService).to receive(:base_domain).and_return('creatia.local')
    allow(DomainService).to receive(:extract_subdomain).and_return('testorg')
    allow(ActsAsTenant).to receive(:current_tenant).and_return(organization)
  end

  feature "조직 생성 및 소유권 관리" do
    scenario "사용자가 새로운 조직을 생성하면 자동으로 소유자가 됨" do
      # Given: 로그인한 사용자가 조직 생성 페이지에 접근
      sign_in owner
      visit '/organizations/new'
      
      # When: 새 조직 정보를 입력하고 생성
      fill_in '조직명', with: 'New Organization'
      fill_in '서브도메인', with: 'neworg'
      fill_in '설명', with: 'A new organization for testing'
      select 'team', from: '플랜'
      click_button '조직 생성'
      
      # Then: 조직이 생성되고 사용자가 소유자로 설정됨
      new_org = Organization.find_by(subdomain: 'neworg')
      expect(new_org).to be_present
      expect(new_org.owner).to eq(owner)
      expect(page).to have_content('조직이 성공적으로 생성되었습니다')
    end

    scenario "조직 소유자만 조직 설정을 변경할 수 있음" do
      # Given: 관리자가 조직 설정 페이지에 접근
      sign_in admin
      visit "/organizations/#{organization.id}/edit"
      
      # When: 조직 설정 변경 시도
      fill_in '조직명', with: 'Updated Name'
      click_button '업데이트'
      
      # Then: 권한 없음 메시지 표시
      expect(page).to have_content('이 작업을 수행할 권한이 없습니다')
    end

    scenario "조직 소유자는 조직을 삭제할 수 있음" do
      # Given: 조직 소유자가 로그인
      sign_in owner
      
      # When: 조직 삭제 요청
      page.driver.delete "/organizations/#{organization.id}"
      
      # Then: 조직이 삭제됨
      expect(Organization.find_by(id: organization.id)).to be_nil
    end
  end

  feature "멤버 관리 및 초대" do
    scenario "관리자가 새로운 멤버를 조직에 초대" do
      # Given: 관리자가 멤버 관리 페이지에 접근
      sign_in admin
      visit "/organizations/#{organization.id}/members"
      
      # When: 새 멤버 초대
      fill_in '이메일', with: 'newmember@creatia.local'
      select 'member', from: '역할'
      click_button '초대'
      
      # Then: 초대 성공 메시지와 함께 멤버 목록에 추가
      expect(page).to have_content('멤버가 성공적으로 초대되었습니다')
      expect(page).to have_content('newmember@creatia.local')
    end

    scenario "일반 멤버는 다른 멤버를 초대할 수 없음" do
      # Given: 일반 멤버가 로그인
      sign_in member
      
      # When: 멤버 초대 페이지 접근 시도
      visit "/organizations/#{organization.id}/members/new"
      
      # Then: 권한 없음 메시지 표시
      expect(page).to have_content('You are not authorized')
    end

    scenario "관리자가 멤버의 역할을 변경" do
      # Given: 관리자가 멤버 목록 페이지에 접근
      sign_in admin
      visit "/organizations/#{organization.id}/members"
      
      # When: 멤버의 역할을 admin으로 변경
      within "#member-#{member.id}" do
        select 'admin', from: '역할'
        click_button '역할 변경'
      end
      
      # Then: 역할이 성공적으로 변경됨
      expect(member_membership.reload.role).to eq('admin')
      expect(page).to have_content('역할이 변경되었습니다')
    end

    scenario "소유자만 다른 사용자를 소유자로 지정할 수 있음" do
      # Given: 관리자가 소유자 역할 변경 시도
      sign_in admin
      
      # When: 멤버를 소유자로 변경 시도
      page.driver.patch "/organization_memberships/#{member_membership.id}", {
        organization_membership: { role: 'owner' }
      }
      
      # Then: 권한 없음 메시지 표시
      expect(page).to have_content('You are not authorized')
    end
  end

  feature "역할별 접근 권한 테스트" do
    let!(:task) { create(:mongo_task, organization: organization, title: 'Test Task') }

    scenario "뷰어는 읽기만 가능하고 수정/삭제 불가" do
      # Given: 뷰어가 로그인하여 태스크 목록 접근
      sign_in viewer
      visit "/tasks"
      
      # Then: 태스크 목록은 볼 수 있음
      expect(page).to have_content('Test Task')
      
      # But: 생성/수정/삭제 버튼은 보이지 않음
      expect(page).not_to have_link('새 태스크')
      expect(page).not_to have_link('수정')
      expect(page).not_to have_link('삭제')
      
      # When: 직접 수정 페이지 접근 시도
      visit "/tasks/#{task.id}/edit"
      
      # Then: 권한 없음 메시지
      expect(page).to have_content('이 작업을 수행할 권한이 없습니다')
    end

    scenario "멤버는 태스크를 생성하고 자신이 담당인 태스크를 수정할 수 있음" do
      # Given: 멤버가 로그인
      sign_in member
      visit "/tasks"
      
      # When: 새 태스크 생성
      click_link '새 태스크'
      fill_in '제목', with: 'Member Task'
      fill_in '설명', with: 'Task created by member'
      click_button '생성'
      
      # Then: 태스크가 생성됨
      expect(page).to have_content('태스크가 생성되었습니다')
      expect(page).to have_content('Member Task')
      
      # When: 자신이 담당인 태스크에 수정 시도
      member_task = Mongodb::MongoTask.find_by(title: 'Member Task')
      member_task.update!(assigned_user: member)
      visit "/tasks/#{member_task.id}/edit"
      
      # Then: 수정 가능
      expect(page).to have_field('제목', with: 'Member Task')
    end

    scenario "관리자는 모든 태스크를 관리할 수 있음" do
      # Given: 관리자가 로그인
      sign_in admin
      
      # When: 다른 사용자의 태스크 수정
      visit "/tasks/#{task.id}/edit"
      
      # Then: 수정 페이지에 접근 가능
      expect(page).to have_field('제목')
      
      # When: 태스크 삭제
      page.driver.delete "/tasks/#{task.id}"
      
      # Then: 삭제 성공
      expect(Mongodb::MongoTask.find_by(id: task.id)).to be_nil
    end

    scenario "소유자는 조직의 모든 기능에 접근 가능" do
      # Given: 소유자가 로그인
      sign_in owner
      
      # When: 조직 설정 페이지 접근
      visit "/organizations/#{organization.id}/settings"
      
      # Then: 모든 설정에 접근 가능
      expect(page).to have_content('조직 설정')
      expect(page).to have_content('멤버 관리')
      expect(page).to have_content('빌링 설정')
      
      # When: 위험한 작업 (조직 삭제) 수행
      visit "/organizations/#{organization.id}/danger_zone"
      
      # Then: 위험한 작업에도 접근 가능
      expect(page).to have_button('조직 삭제')
    end
  end

  feature "조직 외부인 접근 차단" do
    scenario "조직에 속하지 않은 사용자는 접근할 수 없음" do
      # Given: 조직에 속하지 않은 사용자가 로그인
      sign_in outsider
      
      # When: 조직의 리소스에 접근 시도
      visit "/tasks"
      
      # Then: 접근 거부
      expect(page).to have_content('이 조직에 접근할 권한이 없습니다')
    end

    scenario "비활성화된 멤버십을 가진 사용자는 접근할 수 없음" do
      # Given: 멤버십이 비활성화된 사용자
      member_membership.update!(active: false)
      sign_in member
      
      # When: 조직 리소스 접근 시도
      visit "/tasks"
      
      # Then: 접근 거부
      expect(page).to have_content('이 조직에 접근할 권한이 없습니다')
    end

    scenario "비활성화된 조직에는 누구도 접근할 수 없음" do
      # Given: 비활성화된 조직
      organization.update!(active: false)
      
      # When: 소유자도 접근 시도
      sign_in owner
      visit "/dashboard"
      
      # Then: 접근 거부
      expect(page).to have_content('비활성화된 조직입니다')
    end
  end

  feature "데이터 격리 검증" do
    let(:other_org) { create(:organization, subdomain: 'otherorg') }
    let!(:other_task) { create(:mongo_task, organization: other_org, title: 'Other Org Task') }

    scenario "한 조직의 사용자는 다른 조직의 데이터를 볼 수 없음" do
      # Given: 현재 조직의 멤버가 로그인
      sign_in member
      allow(ActsAsTenant).to receive(:current_tenant).and_return(organization)
      
      # When: 태스크 목록 조회
      visit "/tasks"
      
      # Then: 자신의 조직 태스크만 표시됨
      expect(page).not_to have_content('Other Org Task')
      
      # When: 다른 조직 태스크에 직접 접근 시도
      visit "/tasks/#{other_task.id}"
      
      # Then: 접근 불가 메시지 표시
      expect(page).to have_content('not found').or have_content('not authorized')
    end

    scenario "API를 통한 크로스 테넌트 접근도 차단" do
      # Given: 현재 조직의 멤버가 API 요청
      sign_in member
      
      # When: 다른 조직의 태스크 API 접근 시도
      page.driver.header 'Accept', 'application/json'
      page.driver.get "/tasks/#{other_task.id}"
      
      # Then: 접근 거부 JSON 응답
      response = JSON.parse(page.body)
      expect(response['error']).to be_present
    end
  end

  private

  def sign_in(user)
    login_as(user, scope: :user)
  end
end
