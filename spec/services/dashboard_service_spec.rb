require 'rails_helper'

RSpec.describe DashboardService, type: :service do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:service) { create(:service, organization: organization) }
  let(:user1) { create(:user, organization: organization) }
  let(:user2) { create(:user, organization: organization) }

  describe '.weekly_task_completion' do
    before do
      # Create tasks completed in different weeks
      Timecop.freeze(3.weeks.ago) do
        create_list(:task, 2, service: service, team: team, completed_at: Time.current)
      end
      
      Timecop.freeze(2.weeks.ago) do
        create_list(:task, 3, service: service, team: team, completed_at: Time.current)
      end
      
      Timecop.freeze(1.week.ago) do
        create_list(:task, 4, service: service, team: team, completed_at: Time.current)
      end
      
      # Current week
      create_list(:task, 1, service: service, team: team, completed_at: Time.current)
      
      # Incomplete tasks (should not be counted)
      create_list(:task, 2, service: service, team: team, completed_at: nil)
    end

    it 'groups tasks by week' do
      result = DashboardService.weekly_task_completion(team)
      
      expect(result.keys.size).to eq(4) # 4 weeks of data
    end

    it 'counts completed tasks only' do
      result = DashboardService.weekly_task_completion(team)
      
      expect(result.values.sum).to eq(10) # 2+3+4+1 completed tasks
    end

    it 'respects date range of 4 weeks' do
      # Create old task
      Timecop.freeze(5.weeks.ago) do
        create(:task, service: service, team: team, completed_at: Time.current)
      end
      
      result = DashboardService.weekly_task_completion(team)
      
      expect(result.values.sum).to eq(10) # Should not include the 5-week-old task
    end

    it 'returns empty hash when no tasks exist' do
      team.tasks.destroy_all
      
      result = DashboardService.weekly_task_completion(team)
      
      expect(result).to be_empty
    end
  end

  describe '.daily_task_creation_pattern' do
    before do
      # Create tasks at different hours of the day
      Timecop.freeze(Time.zone.local(2025, 1, 15, 9, 0, 0)) do # 9am
        create_list(:task, 3, service: service, team: team)
      end
      
      Timecop.freeze(Time.zone.local(2025, 1, 15, 14, 0, 0)) do # 2pm
        create_list(:task, 5, service: service, team: team)
      end
      
      Timecop.freeze(Time.zone.local(2025, 1, 15, 17, 0, 0)) do # 5pm
        create_list(:task, 2, service: service, team: team)
      end
    end

    it 'groups tasks by hour of day' do
      result = DashboardService.daily_task_creation_pattern(team)
      
      expect(result[9]).to eq(3)  # 9am
      expect(result[14]).to eq(5) # 2pm
      expect(result[17]).to eq(2) # 5pm
    end

    it 'returns 24 hour keys' do
      result = DashboardService.daily_task_creation_pattern(team)
      
      (0..23).each do |hour|
        expect(result).to have_key(hour)
      end
    end

    it 'shows zero for hours with no tasks' do
      result = DashboardService.daily_task_creation_pattern(team)
      
      expect(result[3]).to eq(0)  # 3am should have 0 tasks
      expect(result[22]).to eq(0) # 10pm should have 0 tasks
    end
  end

  describe '.team_velocity_trend' do
    let(:sprint1) { create(:sprint, service: service, end_date: 3.weeks.ago.to_date) }
    let(:sprint2) { create(:sprint, service: service, end_date: 2.weeks.ago.to_date) }
    let(:sprint3) { create(:sprint, service: service, end_date: 1.week.ago.to_date) }

    before do
      # Sprint 1 tasks
      create(:task, sprint: sprint1, team: team, story_points: 5, status: 'completed')
      create(:task, sprint: sprint1, team: team, story_points: 3, status: 'completed')
      
      # Sprint 2 tasks
      create(:task, sprint: sprint2, team: team, story_points: 8, status: 'completed')
      create(:task, sprint: sprint2, team: team, story_points: 5, status: 'completed')
      
      # Sprint 3 tasks
      create(:task, sprint: sprint3, team: team, story_points: 3, status: 'completed')
      
      # Incomplete tasks (should not be counted)
      create(:task, sprint: sprint3, team: team, story_points: 10, status: 'in_progress')
    end

    it 'calculates sprint velocity over time' do
      result = DashboardService.team_velocity_trend(team)
      
      expect(result.values).to eq([8, 13, 3]) # Sprint velocities
    end

    it 'groups by sprint end date week' do
      result = DashboardService.team_velocity_trend(team)
      
      expect(result.keys.size).to eq(3) # 3 sprints
    end

    it 'includes only completed tasks' do
      result = DashboardService.team_velocity_trend(team)
      
      # Sprint 3 should only have 3 points (not 13)
      expect(result.values.last).to eq(3)
    end
  end

  describe '.task_completion_by_member' do
    before do
      # User 1 tasks
      Timecop.freeze(2.weeks.ago) do
        create_list(:task, 2, assignee: user1, team: team, completed_at: Time.current)
      end
      
      Timecop.freeze(1.week.ago) do
        create_list(:task, 3, assignee: user1, team: team, completed_at: Time.current)
      end
      
      # User 2 tasks
      Timecop.freeze(2.weeks.ago) do
        create_list(:task, 1, assignee: user2, team: team, completed_at: Time.current)
      end
      
      Timecop.freeze(1.week.ago) do
        create_list(:task, 4, assignee: user2, team: team, completed_at: Time.current)
      end
      
      # Old tasks (outside period)
      Timecop.freeze(2.months.ago) do
        create(:task, assignee: user1, team: team, completed_at: Time.current)
      end
    end

    it 'groups tasks by member and week' do
      result = DashboardService.task_completion_by_member(team, 1.month)
      
      expect(result).to have_key(user1.name)
      expect(result).to have_key(user2.name)
    end

    it 'respects the time period' do
      result = DashboardService.task_completion_by_member(team, 1.month)
      
      total_tasks = result.values.map(&:values).flatten.sum
      expect(total_tasks).to eq(10) # Should not include 2-month-old task
    end

    it 'counts completed tasks per member per week' do
      result = DashboardService.task_completion_by_member(team, 1.month)
      
      user1_total = result[user1.name].values.sum
      user2_total = result[user2.name].values.sum
      
      expect(user1_total).to eq(5) # 2 + 3
      expect(user2_total).to eq(5) # 1 + 4
    end
  end

  describe '.average_task_completion_time' do
    before do
      # Task 1: 4 business hours
      task1 = create(:task, team: team, status: 'completed')
      task1.update!(
        started_at: Time.zone.local(2025, 1, 15, 9, 0, 0),   # 9am
        completed_at: Time.zone.local(2025, 1, 15, 13, 0, 0)  # 1pm
      )
      
      # Task 2: 8 business hours (full day)
      task2 = create(:task, team: team, status: 'completed')
      task2.update!(
        started_at: Time.zone.local(2025, 1, 15, 9, 0, 0),   # Wed 9am
        completed_at: Time.zone.local(2025, 1, 15, 18, 0, 0)  # Wed 6pm (9 hours)
      )
      
      # Task 3: 2 business hours (crosses weekend)
      task3 = create(:task, team: team, status: 'completed')
      task3.update!(
        started_at: Time.zone.local(2025, 1, 24, 16, 0, 0),   # Fri 4pm
        completed_at: Time.zone.local(2025, 1, 27, 10, 0, 0)  # Mon 10am
      )
      
      # Incomplete task (should not be counted)
      create(:task, team: team, started_at: 1.day.ago, completed_at: nil)
    end

    it 'calculates average completion time in business hours' do
      average = DashboardService.average_task_completion_time(team)
      
      # (4 + 9 + 2) / 3 = 5 hours
      expect(average).to eq(5.0)
    end

    it 'excludes tasks without start time' do
      create(:task, team: team, started_at: nil, completed_at: Time.current, status: 'completed')
      
      average = DashboardService.average_task_completion_time(team)
      
      expect(average).to eq(5.0) # Should still be 5, not affected
    end

    it 'excludes tasks without completion time' do
      create(:task, team: team, started_at: 1.day.ago, completed_at: nil)
      
      average = DashboardService.average_task_completion_time(team)
      
      expect(average).to eq(5.0) # Should still be 5, not affected
    end

    it 'returns nil when no completed tasks with times exist' do
      team.tasks.update_all(started_at: nil)
      
      average = DashboardService.average_task_completion_time(team)
      
      expect(average).to be_nil
    end
  end

  describe '.sprint_burndown_data' do
    let(:sprint) { create(:sprint, service: service, start_date: Date.new(2025, 1, 13), end_date: Date.new(2025, 1, 24)) }
    
    before do
      # Create tasks with story points
      task1 = create(:task, sprint: sprint, team: team, story_points: 5)
      task2 = create(:task, sprint: sprint, team: team, story_points: 3)
      task3 = create(:task, sprint: sprint, team: team, story_points: 8)
      task4 = create(:task, sprint: sprint, team: team, story_points: 2)
      
      # Complete tasks on different days
      task1.update!(completed_at: Date.new(2025, 1, 14), status: 'completed')
      task2.update!(completed_at: Date.new(2025, 1, 16), status: 'completed')
      task3.update!(completed_at: Date.new(2025, 1, 20), status: 'completed')
      # task4 remains incomplete
    end

    it 'generates burndown data with remaining points' do
      data = DashboardService.sprint_burndown_data(sprint)
      
      expect(data[Date.new(2025, 1, 13)]).to eq(18) # All points at start
      expect(data[Date.new(2025, 1, 14)]).to eq(13) # 18 - 5
      expect(data[Date.new(2025, 1, 16)]).to eq(10) # 13 - 3
      expect(data[Date.new(2025, 1, 20)]).to eq(2)  # 10 - 8
      expect(data[Date.new(2025, 1, 24)]).to eq(2)  # 2 points remain
    end
  end
end