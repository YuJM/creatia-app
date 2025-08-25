# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Task, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  
  before do
    ActsAsTenant.current_tenant = organization
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe "테넌트 스코핑" do
    context "태스크는 조직별로 격리된다" do
      it "태스크는 특정 조직에 속해야 한다" do
        # Given: 조직 컨텍스트에서 태스크 생성
        task = build(:task, organization: organization, title: 'Test Task')
        
        # When: 태스크 저장
        # Then: 성공적으로 생성됨
        expect(task).to be_valid
        expect { task.save! }.not_to raise_error
        expect(task.organization).to eq(organization)
      end

      it "현재 테넌트 컨텍스트의 태스크만 조회된다" do
        # Given: 현재 조직과 다른 조직의 태스크
        current_org_task = create(:task, organization: organization, title: 'Current Org Task')
        
        other_org = create(:organization, subdomain: 'other-org')
        
        # 다른 조직 컨텍스트에서 태스크 생성
        ActsAsTenant.with_tenant(other_org) do
          create(:task, organization: other_org, title: 'Other Org Task')
        end
        
        # When: 태스크 목록 조회 (현재 테넌트 컨텍스트에서)
        ActsAsTenant.with_tenant(organization) do
          tasks = Task.all
          
          # Then: 현재 조직의 태스크만 포함
          expect(tasks).to include(current_org_task)
          expect(tasks.count).to eq(1)
          expect(tasks.first.organization).to eq(organization)
        end
      end

      it "다른 조직의 태스크에는 직접 접근할 수 없다" do
        # Given: 다른 조직의 태스크
        other_org = create(:organization, subdomain: 'other-org')
        other_task = nil
        
        # 다른 조직 컨텍스트에서 태스크 생성
        ActsAsTenant.with_tenant(other_org) do
          other_task = create(:task, organization: other_org, title: 'Other Task')
        end
        
        # When: 현재 조직 컨텍스트에서 다른 조직 태스크 검색
        found_task = Task.find_by(id: other_task.id)
        
        # Then: 찾을 수 없음 (테넌트 격리)
        expect(found_task).to be_nil
      end
    end

    context "조직 없이는 태스크를 생성할 수 없다" do
      it "조직이 필수이다" do
        # Given: 테넌트 컨텍스트를 해제하고 조직 없는 태스크 생성
        ActsAsTenant.current_tenant = nil
        task = Task.new(title: 'No Org Task', organization: nil)
        
        # When: 유효성 검사
        # Then: 유효하지 않음
        expect(task).not_to be_valid
        expect(task.errors[:organization]).to include("can't be blank")
        
        # 원래 테넌트 컨텍스트 복원
        ActsAsTenant.current_tenant = organization
      end
    end
  end

  describe "태스크 기본 속성" do
    context "유효한 태스크 생성" do
      it "제목과 조직으로 태스크를 생성할 수 있다" do
        # Given: 최소 필수 정보
        task = build(:task, organization: organization, title: 'Simple Task')
        
        # When: 태스크 저장
        # Then: 성공적으로 생성됨
        expect(task).to be_valid
        expect(task.title).to eq('Simple Task')
        expect(task.organization).to eq(organization)
      end

      it "기본값이 적절히 설정된다" do
        # When: 기본값으로 태스크 생성
        task = create(:task, organization: organization, title: 'Default Task')
        
        # Then: 기본값 설정됨
        expect(task.status).to eq('todo')
        expect(task.priority).to eq('medium')
        expect(task.position).to eq(0)
      end
    end

    context "태스크 제목 검증" do
      it "제목은 필수이다" do
        # Given: 제목 없는 태스크
        task = build(:task, organization: organization, title: nil)
        
        # When: 유효성 검사
        # Then: 유효하지 않음
        expect(task).not_to be_valid
        expect(task.errors[:title]).to include("can't be blank")
      end

      it "제목은 1-200자 사이여야 한다" do
        # Given: 너무 짧거나 긴 제목
        empty_title = build(:task, organization: organization, title: '')
        too_long = build(:task, organization: organization, title: 'A' * 201)
        valid_title = build(:task, organization: organization, title: 'A')
        
        # When: 유효성 검사
        # Then: 빈 제목은 유효하지 않음, 1자는 유효함, 201자는 유효하지 않음
        expect(empty_title).not_to be_valid
        expect(too_long).not_to be_valid
        expect(valid_title).to be_valid
      end
    end

    context "상태 및 우선순위 검증" do
      it "유효한 상태만 허용한다" do
        # Given: 유효한 상태들
        valid_statuses = %w[todo in_progress review done archived]
        
        valid_statuses.each do |status|
          # When: 각 상태로 태스크 생성
          task = build(:task, organization: organization, status: status)
          
          # Then: 유효함
          expect(task).to be_valid, "#{status} should be valid"
        end
      end

      it "유효한 우선순위만 허용한다" do
        # Given: 유효한 우선순위들
        valid_priorities = %w[low medium high urgent]
        
        valid_priorities.each do |priority|
          # When: 각 우선순위로 태스크 생성
          task = build(:task, organization: organization, priority: priority)
          
          # Then: 유효함
          expect(task).to be_valid, "#{priority} should be valid"
        end
      end

      it "유효하지 않은 상태는 거부한다" do
        # Given: 유효하지 않은 상태
        task = build(:task, organization: organization, status: 'invalid_status')
        
        # When: 유효성 검사
        # Then: 유효하지 않음
        expect(task).not_to be_valid
        expect(task.errors[:status]).to include("is not included in the list")
      end
    end
  end

  describe "태스크 할당" do
    context "사용자 할당" do
      it "조직 멤버에게 태스크를 할당할 수 있다" do
        # Given: 조직 멤버
        create(:organization_membership, user: user, organization: organization, role: 'member')
        task = create(:task, organization: organization, title: 'Assigned Task')
        
        # When: 태스크 할당
        task.update!(assigned_user: user)
        
        # Then: 할당 성공
        expect(task.assigned_user).to eq(user)
        expect(task.assigned?).to be true
      end

      it "할당되지 않은 태스크는 assigned? 메서드가 false를 반환한다" do
        # Given: 할당되지 않은 태스크
        task = create(:task, organization: organization, assigned_user: nil)
        
        # When & Then: 할당 여부 확인
        expect(task.assigned?).to be false
      end
    end
  end

  describe "태스크 스코프와 필터링" do
      let!(:todo_task) { create(:task, organization: organization, status: 'todo', priority: 'high') }
  let!(:progress_task) { create(:task, organization: organization, status: 'in_progress', priority: 'medium') }
  let!(:done_task) { create(:task, organization: organization, status: 'done', priority: 'low') }
  let!(:urgent_task) { create(:task, organization: organization, status: 'todo', priority: 'urgent') }

    context "상태별 스코프" do
      it "TODO 태스크만 필터링할 수 있다" do
        # When: TODO 태스크 조회
        todo_tasks = Task.todo
        
        # Then: TODO 상태의 태스크만 포함
        expect(todo_tasks).to include(todo_task, urgent_task)
        expect(todo_tasks).not_to include(progress_task, done_task)
      end

      it "진행 중인 태스크만 필터링할 수 있다" do
        # When: 진행 중 태스크 조회
        in_progress_tasks = Task.in_progress
        
        # Then: 진행 중 상태의 태스크만 포함
        expect(in_progress_tasks).to include(progress_task)
        expect(in_progress_tasks).not_to include(todo_task, done_task, urgent_task)
      end

      it "완료된 태스크만 필터링할 수 있다" do
        # When: 완료 태스크 조회
        done_tasks = Task.done
        
        # Then: 완료 상태의 태스크만 포함
        expect(done_tasks).to include(done_task)
        expect(done_tasks).not_to include(todo_task, progress_task, urgent_task)
      end
    end

    context "우선순위별 스코프" do
      it "높은 우선순위 태스크만 필터링할 수 있다" do
        # When: 높은 우선순위 태스크 조회
        high_priority_tasks = Task.by_priority('high')
        
        # Then: 높은 우선순위 태스크만 포함
        expect(high_priority_tasks).to include(todo_task)
        expect(high_priority_tasks).not_to include(progress_task, done_task, urgent_task)
      end

      it "긴급 우선순위 태스크만 필터링할 수 있다" do
        # When: 긴급 우선순위 태스크 조회
        urgent_tasks = Task.by_priority('urgent')
        
        # Then: 긴급 우선순위 태스크만 포함
        expect(urgent_tasks).to include(urgent_task)
        expect(urgent_tasks).not_to include(todo_task, progress_task, done_task)
      end
    end

    context "사용자별 스코프" do
      before do
        create(:organization_membership, user: user, organization: organization, role: 'member')
        todo_task.update!(assigned_user: user)
        urgent_task.update!(assigned_user: user)
      end

      it "특정 사용자에게 할당된 태스크만 필터링할 수 있다" do
        # When: 특정 사용자 태스크 조회
        user_tasks = Task.assigned_to(user)
        
        # Then: 해당 사용자 태스크만 포함
        expect(user_tasks).to include(todo_task, urgent_task)
        expect(user_tasks).not_to include(progress_task, done_task)
      end
    end

    context "정렬 스코프" do
      it "태스크를 위치순으로 정렬할 수 있다" do
        # Given: 새로운 조직과 위치가 다른 태스크들 생성
        test_org = create(:organization, subdomain: 'test-order-org')
        ActsAsTenant.with_tenant(test_org) do
          task1 = create(:task, organization: test_org, title: 'Order Task 1', position: 2)
          task2 = create(:task, organization: test_org, title: 'Order Task 2', position: 1)
          task3 = create(:task, organization: test_org, title: 'Order Task 3', position: 3)
          
          # When: 위치순 정렬
          ordered_tasks = Task.ordered
          
          # Then: 위치순으로 정렬됨 (이 조직의 태스크만)
          expect(ordered_tasks.count).to eq(3)
          expect(ordered_tasks.map(&:title)).to eq(['Order Task 2', 'Order Task 1', 'Order Task 3'])
          expect(ordered_tasks.map(&:position)).to eq([1, 2, 3])
        end
      end
    end
  end

  describe "태스크 기한 관리" do
    context "기한 설정" do
      it "기한을 설정할 수 있다" do
        # Given: 기한이 있는 태스크
        due_date = 3.days.from_now
        task = create(:task, organization: organization, due_date: due_date)
        
        # When & Then: 기한 확인
        expect(task.due_date).to eq(due_date)
      end

      it "기한이 지난 태스크를 확인할 수 있다" do
        # Given: 기한이 지난 태스크
        overdue_task = create(:task, organization: organization, due_date: 1.day.ago, status: 'todo')
        current_task = create(:task, organization: organization, due_date: 1.day.from_now, status: 'todo')
        
        # When & Then: 기한 초과 확인
        expect(overdue_task.overdue?).to be true
        expect(current_task.overdue?).to be false
      end

      it "완료된 태스크는 기한이 지나도 overdue가 아니다" do
        # Given: 기한이 지났지만 완료된 태스크
        completed_task = create(:task, organization: organization, due_date: 1.day.ago, status: 'done')
        
        # When & Then: 기한 초과 확인
        expect(completed_task.overdue?).to be false
      end

      it "기한이 임박한 태스크를 확인할 수 있다" do
        # Given: 내일까지인 태스크
        due_soon_task = create(:task, organization: organization, due_date: 1.day.from_now)
        not_due_soon_task = create(:task, organization: organization, due_date: 5.days.from_now)
        
        # When & Then: 기한 임박 확인
        expect(due_soon_task.due_soon?).to be true
        expect(not_due_soon_task.due_soon?).to be false
      end
    end

    context "기한별 스코프" do
      let!(:overdue_task) { create(:task, organization: organization, due_date: 1.day.ago, status: 'todo') }
      let!(:due_today_task) { create(:task, organization: organization, due_date: Date.current) }
      let!(:future_task) { create(:task, organization: organization, due_date: 5.days.from_now) }

      it "기한이 지난 태스크만 조회할 수 있다" do
        # When: 기한 초과 태스크 조회
        overdue_tasks = Task.overdue
        
        # Then: 기한이 지난 태스크만 포함
        expect(overdue_tasks).to include(overdue_task)
        expect(overdue_tasks).not_to include(due_today_task, future_task)
      end

      it "오늘까지인 태스크를 조회할 수 있다" do
        # When: 오늘까지인 태스크 조회
        due_today_tasks = Task.due_today
        
        # Then: 오늘까지인 태스크만 포함
        expect(due_today_tasks).to include(due_today_task)
        expect(due_today_tasks).not_to include(overdue_task, future_task)
      end
    end
  end

  describe "태스크 표시 및 헬퍼 메서드" do
    context "상태 표시명" do
      it "각 상태의 한국어 표시명을 제공한다" do
        # Given: 상태별 표시명 매핑
        status_displays = {
          'todo' => '할 일',
          'in_progress' => '진행 중',
          'review' => '검토 중',
          'done' => '완료',
          'archived' => '보관됨'
        }
        
        status_displays.each do |status, display_name|
          # When: 상태 설정 및 표시명 조회
          task = create(:task, organization: organization, status: status)
          
          # Then: 올바른 표시명 반환
          expect(task.status_display_name).to eq(display_name)
        end
      end
    end

    context "우선순위 표시명 및 색상" do
      it "각 우선순위의 한국어 표시명을 제공한다" do
        # Given: 우선순위별 표시명 매핑
        priority_displays = {
          'low' => '낮음',
          'medium' => '보통',
          'high' => '높음',
          'urgent' => '긴급'
        }
        
        priority_displays.each do |priority, display_name|
          # When: 우선순위 설정 및 표시명 조회
          task = create(:task, organization: organization, priority: priority)
          
          # Then: 올바른 표시명 반환
          expect(task.priority_display_name).to eq(display_name)
        end
      end

      it "각 우선순위의 색상을 제공한다" do
        # Given: 우선순위별 색상 매핑
        priority_colors = {
          'low' => 'green',
          'medium' => 'yellow',
          'high' => 'orange',
          'urgent' => 'red'
        }
        
        priority_colors.each do |priority, color|
          # When: 우선순위 설정 및 색상 조회
          task = create(:task, organization: organization, priority: priority)
          
          # Then: 올바른 색상 반환
          expect(task.priority_color).to eq(color)
        end
      end
    end
  end

  describe "태스크 데이터 무결성" do
    it "위치 값은 숫자여야 한다" do
      # Given: 유효한 위치 값
      task = build(:task, organization: organization, position: 5)
      
      # When & Then: 유효성 확인
      expect(task).to be_valid
      expect(task.position).to eq(5)
    end

    it "설명은 선택사항이다" do
      # Given: 설명 없는 태스크
      task = build(:task, organization: organization, description: nil)
      
      # When & Then: 유효성 확인
      expect(task).to be_valid
    end

    it "설명이 있으면 저장된다" do
      # Given: 설명이 있는 태스크
      description = "This is a detailed task description."
      task = create(:task, organization: organization, description: description)
      
      # When & Then: 설명 확인
      expect(task.description).to eq(description)
    end
  end
end