require 'rails_helper'

RSpec.describe Sprint, type: :model do
  let(:organization) { create(:organization) }
  let(:service) { create(:service, organization: organization) }
  let(:user) { create(:user, organization: organization) }
  let(:sprint) { create(:sprint, service: service) }
  
  before do
    ActsAsTenant.with_tenant(organization) do
      @sprint = sprint
    end
  end

  describe 'associations' do
    it { should belong_to(:service) }
    it { should have_many(:tasks).dependent(:nullify) }
    it { should have_many(:users).through(:tasks) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:end_date) }
    
    context 'date validations' do
      it 'validates end_date is after start_date' do
        invalid_sprint = build(:sprint, 
          service: service,
          start_date: Date.today, 
          end_date: Date.yesterday
        )
        expect(invalid_sprint).not_to be_valid
        expect(invalid_sprint.errors[:end_date]).to include("must be after start date")
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(
      planning: 0,
      active: 1,
      completed: 2,
      cancelled: 3
    ) }
  end

  describe 'scopes' do
    describe '.current' do
      it 'returns active sprints containing today' do
        ActsAsTenant.with_tenant(organization) do
          past_sprint = create(:sprint, 
            service: service,
            start_date: 2.weeks.ago, 
            end_date: 1.week.ago,
            status: :completed
          )
          current_sprint = create(:sprint,
            service: service,
            start_date: 1.week.ago,
            end_date: 1.week.from_now,
            status: :active
          )
          future_sprint = create(:sprint,
            service: service,
            start_date: 1.week.from_now,
            end_date: 2.weeks.from_now,
            status: :planning
          )
          
          expect(Sprint.current).to include(current_sprint)
          expect(Sprint.current).not_to include(past_sprint, future_sprint)
        end
      end
    end

    describe '.past' do
      it 'returns completed sprints' do
        ActsAsTenant.with_tenant(organization) do
          active_sprint = create(:sprint, service: service, status: :active)
          completed_sprint = create(:sprint, service: service, status: :completed)
          
          expect(Sprint.past).to include(completed_sprint)
          expect(Sprint.past).not_to include(active_sprint)
        end
      end
    end

    describe '.upcoming' do
      it 'returns planning sprints with future start date' do
        ActsAsTenant.with_tenant(organization) do
          upcoming_sprint = create(:sprint,
            service: service,
            start_date: 1.week.from_now,
            status: :planning
          )
          active_sprint = create(:sprint, service: service, status: :active)
          
          expect(Sprint.upcoming).to include(upcoming_sprint)
          expect(Sprint.upcoming).not_to include(active_sprint)
        end
      end
    end
  end

  describe '#initialize_schedule' do
    it 'creates an Ice Cube schedule' do
      ActsAsTenant.with_tenant(organization) do
        new_sprint = build(:sprint, service: service)
        new_sprint.initialize_schedule(2)
        
        expect(new_sprint.schedule).to be_present
        expect(new_sprint.schedule).to be_a(Hash)
        
        # Reconstruct the schedule to verify
        schedule = IceCube::Schedule.from_hash(new_sprint.schedule)
        expect(schedule.start_time).to eq(new_sprint.start_date.to_time)
        expect(schedule.rrules.first.to_s).to include("weeks")
      end
    end
  end

  describe '#duration_in_days' do
    it 'calculates sprint duration correctly' do
      ActsAsTenant.with_tenant(organization) do
        sprint = create(:sprint,
          service: service,
          start_date: Date.today,
          end_date: 14.days.from_now
        )
        
        expect(sprint.duration_in_days).to eq(14)
      end
    end
  end

  describe '#progress_percentage' do
    context 'when sprint has not started' do
      it 'returns 0' do
        ActsAsTenant.with_tenant(organization) do
          future_sprint = create(:sprint,
            service: service,
            start_date: 1.week.from_now,
            end_date: 2.weeks.from_now
          )
          
          expect(future_sprint.progress_percentage).to eq(0)
        end
      end
    end

    context 'when sprint is active' do
      it 'calculates progress based on elapsed time' do
        ActsAsTenant.with_tenant(organization) do
          active_sprint = create(:sprint,
            service: service,
            start_date: 7.days.ago,
            end_date: 7.days.from_now
          )
          
          # Approximately 50% through the sprint
          expect(active_sprint.progress_percentage).to be_within(5).of(50)
        end
      end
    end

    context 'when sprint is completed' do
      it 'returns 100' do
        ActsAsTenant.with_tenant(organization) do
          past_sprint = create(:sprint,
            service: service,
            start_date: 2.weeks.ago,
            end_date: 1.week.ago
          )
          
          expect(past_sprint.progress_percentage).to eq(100)
        end
      end
    end
  end

  describe '#calculate_velocity' do
    it 'calculates velocity based on completed story points' do
      ActsAsTenant.with_tenant(organization) do
        sprint = create(:sprint, service: service, status: :active)
        
        # Create tasks with story points
        completed_task1 = create(:task, 
          sprint: sprint, 
          story_points: 3,
          completed_at: Time.current
        )
        completed_task2 = create(:task,
          sprint: sprint,
          story_points: 5,
          completed_at: Time.current
        )
        incomplete_task = create(:task,
          sprint: sprint,
          story_points: 2,
          completed_at: nil
        )
        
        expect(sprint.calculate_velocity).to eq(8)
      end
    end
  end

  describe '#burndown_data' do
    it 'generates burndown chart data' do
      ActsAsTenant.with_tenant(organization) do
        sprint = create(:sprint,
          service: service,
          start_date: 7.days.ago,
          end_date: 7.days.from_now,
          status: :active
        )
        
        # Create tasks
        create(:task, sprint: sprint, story_points: 5)
        create(:task, sprint: sprint, story_points: 3)
        
        burndown = sprint.burndown_data
        
        expect(burndown).to be_a(Array)
        expect(burndown.first).to include(:date, :ideal, :actual)
      end
    end
  end

  describe '#can_activate?' do
    it 'returns true for planning sprints with current date in range' do
      ActsAsTenant.with_tenant(organization) do
        ready_sprint = create(:sprint,
          service: service,
          start_date: Date.today,
          end_date: 2.weeks.from_now,
          status: :planning
        )
        
        expect(ready_sprint.can_activate?).to be true
      end
    end

    it 'returns false for already active sprints' do
      ActsAsTenant.with_tenant(organization) do
        active_sprint = create(:sprint, service: service, status: :active)
        expect(active_sprint.can_activate?).to be false
      end
    end
  end

  describe '#activate!' do
    it 'changes status to active' do
      ActsAsTenant.with_tenant(organization) do
        planning_sprint = create(:sprint,
          service: service,
          start_date: Date.today,
          status: :planning
        )
        
        expect { planning_sprint.activate! }
          .to change { planning_sprint.status }
          .from('planning')
          .to('active')
      end
    end
  end

  describe '#complete!' do
    it 'changes status to completed and calculates final velocity' do
      ActsAsTenant.with_tenant(organization) do
        active_sprint = create(:sprint, service: service, status: :active)
        
        create(:task, 
          sprint: active_sprint,
          story_points: 5,
          completed_at: Time.current
        )
        
        expect { active_sprint.complete! }
          .to change { active_sprint.status }
          .from('active')
          .to('completed')
        
        expect(active_sprint.velocity).to eq(5)
      end
    end
  end
end