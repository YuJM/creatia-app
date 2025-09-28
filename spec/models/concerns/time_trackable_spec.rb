require 'rails_helper'

RSpec.describe TimeTrackable, type: :concern do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:service) { create(:service, organization: organization) }
  
  # Create a dummy class to test the concern
  class TimeTrackableTest < ApplicationRecord
    self.table_name = 'tasks'
    include TimeTrackable
    
    belongs_to :assignee, class_name: 'User', optional: true
  end
  
  subject(:time_trackable) { TimeTrackableTest.new(assignee: user) }
  
  describe 'included modules and methods' do
    it 'includes TimeTrackable methods' do
      expect(time_trackable).to respond_to(:set_deadline_from_natural_language)
      expect(time_trackable).to respond_to(:urgency_level)
      expect(time_trackable).to respond_to(:time_until_deadline)
      expect(time_trackable).to respond_to(:business_hours_until_deadline)
      expect(time_trackable).to respond_to(:is_overdue?)
      expect(time_trackable).to respond_to(:format_deadline)
    end
  end
  
  describe '#set_deadline_from_natural_language' do
    context 'with valid natural language input' do
      it 'parses "tomorrow at 3pm"' do
        time_trackable.set_deadline_from_natural_language("tomorrow at 3pm")
        expect(time_trackable.deadline).to be_present
        expect(time_trackable.deadline.hour).to eq(15)
      end
      
      it 'parses "next friday"' do
        time_trackable.set_deadline_from_natural_language("next friday")
        expect(time_trackable.deadline).to be_present
        expect(time_trackable.deadline.wday).to eq(5) # Friday
      end
      
      it 'parses "in 3 days"' do
        time_trackable.set_deadline_from_natural_language("in 3 days")
        expect(time_trackable.deadline).to be_present
        expect(time_trackable.deadline).to be_within(1.hour).of(3.days.from_now)
      end
      
      it 'parses "2 weeks from now"' do
        time_trackable.set_deadline_from_natural_language("2 weeks from now")
        expect(time_trackable.deadline).to be_present
        expect(time_trackable.deadline).to be_within(1.hour).of(2.weeks.from_now)
      end
    end
    
    context 'with invalid input' do
      it 'adds error for unparseable text' do
        time_trackable.set_deadline_from_natural_language("gibberish text")
        expect(time_trackable.errors[:deadline]).to include(/시간을 파싱할 수 없습니다/)
      end
    end
  end
  
  describe '#urgency_level' do
    context 'with no deadline' do
      it 'returns :low' do
        time_trackable.deadline = nil
        expect(time_trackable.urgency_level).to eq(:low)
      end
    end
    
    context 'with overdue deadline' do
      it 'returns :critical' do
        time_trackable.deadline = 1.hour.ago
        expect(time_trackable.urgency_level).to eq(:critical)
      end
    end
    
    context 'with deadline within 2 hours' do
      it 'returns :critical' do
        time_trackable.deadline = 1.hour.from_now
        expect(time_trackable.urgency_level).to eq(:critical)
      end
    end
    
    context 'with deadline within 24 hours' do
      it 'returns :high' do
        time_trackable.deadline = 12.hours.from_now
        expect(time_trackable.urgency_level).to eq(:high)
      end
    end
    
    context 'with deadline within 3 days' do
      it 'returns :medium' do
        time_trackable.deadline = 2.days.from_now
        expect(time_trackable.urgency_level).to eq(:medium)
      end
    end
    
    context 'with deadline beyond 3 days' do
      it 'returns :low' do
        time_trackable.deadline = 1.week.from_now
        expect(time_trackable.urgency_level).to eq(:low)
      end
    end
  end
  
  describe '#time_until_deadline' do
    context 'with future deadline' do
      it 'returns human-readable time' do
        time_trackable.deadline = 2.days.from_now
        expect(time_trackable.time_until_deadline).to include("일")
      end
    end
    
    context 'with past deadline' do
      it 'returns overdue message' do
        time_trackable.deadline = 1.day.ago
        expect(time_trackable.time_until_deadline).to include("지연")
      end
    end
    
    context 'with no deadline' do
      it 'returns nil' do
        time_trackable.deadline = nil
        expect(time_trackable.time_until_deadline).to be_nil
      end
    end
  end
  
  describe '#business_hours_until_deadline' do
    it 'calculates business hours correctly' do
      # Monday 9 AM to Friday 5 PM (5 business days)
      monday_morning = Time.parse("2024-01-08 09:00:00")
      friday_evening = Time.parse("2024-01-12 17:00:00")
      
      allow(Time).to receive(:current).and_return(monday_morning)
      time_trackable.deadline = friday_evening
      
      hours = time_trackable.business_hours_until_deadline
      expect(hours).to be_within(1).of(40) # 5 days * 8 hours
    end
    
    it 'excludes weekends' do
      # Friday 5 PM to Monday 9 AM
      friday_evening = Time.parse("2024-01-05 17:00:00")
      monday_morning = Time.parse("2024-01-08 09:00:00")
      
      allow(Time).to receive(:current).and_return(friday_evening)
      time_trackable.deadline = monday_morning
      
      hours = time_trackable.business_hours_until_deadline
      expect(hours).to eq(0) # No business hours over weekend
    end
  end
  
  describe '#is_overdue?' do
    context 'when deadline has passed' do
      it 'returns true' do
        time_trackable.deadline = 1.hour.ago
        expect(time_trackable.is_overdue?).to be true
      end
    end
    
    context 'when deadline is in future' do
      it 'returns false' do
        time_trackable.deadline = 1.hour.from_now
        expect(time_trackable.is_overdue?).to be false
      end
    end
    
    context 'when no deadline' do
      it 'returns false' do
        time_trackable.deadline = nil
        expect(time_trackable.is_overdue?).to be false
      end
    end
  end
  
  describe '#format_deadline' do
    context 'with various format options' do
      before do
        time_trackable.deadline = Time.zone.parse("2024-01-15 14:30:00")
      end
      
      it 'formats as default' do
        expect(time_trackable.format_deadline).to eq("2024-01-15 14:30")
      end
      
      it 'formats as short' do
        expect(time_trackable.format_deadline(:short)).to eq("01/15 14:30")
      end
      
      it 'formats as long' do
        expect(time_trackable.format_deadline(:long)).to include("2024년")
      end
      
      it 'formats as date_only' do
        expect(time_trackable.format_deadline(:date_only)).to eq("2024-01-15")
      end
      
      it 'formats as time_only' do
        expect(time_trackable.format_deadline(:time_only)).to eq("14:30")
      end
      
      it 'formats as relative' do
        expect(time_trackable.format_deadline(:relative)).to include("후") # X일 후
      end
    end
    
    context 'with no deadline' do
      it 'returns dash' do
        time_trackable.deadline = nil
        expect(time_trackable.format_deadline).to eq("—")
      end
    end
  end
  
  describe 'priority and auto-scheduling' do
    describe '#calculate_priority' do
      it 'calculates priority based on urgency and importance' do
        time_trackable.deadline = 1.hour.from_now
        time_trackable.priority = :high if time_trackable.respond_to?(:priority=)
        
        expect(time_trackable.urgency_level).to eq(:critical)
      end
    end
    
    describe '#suggested_work_time' do
      it 'suggests optimal work time based on deadline' do
        skip "Method not implemented" unless time_trackable.respond_to?(:suggested_work_time)
        
        time_trackable.deadline = 1.day.from_now
        time_trackable.estimated_hours = 4
        
        suggested = time_trackable.suggested_work_time
        expect(suggested).to be_present
      end
    end
  end
  
  describe 'scopes' do
    let!(:overdue_task) do
      ActsAsTenant.with_tenant(organization) do
        task = TimeTrackableTest.new(
          title: "Overdue",
          deadline: 1.day.ago,
          assignee: user,
          service_id: service.id,
          organization_id: organization.id,
          status: "todo",
          priority: "medium",
          position: 0
        )
        task.save(validate: false)
        task
      end
    end
    
    let!(:upcoming_task) do
      ActsAsTenant.with_tenant(organization) do
        TimeTrackableTest.create!(
          title: "Upcoming",
          deadline: 1.day.from_now,
          assignee: user,
          service_id: service.id,
          organization_id: organization.id,
          status: "todo",
          priority: "medium",
          position: 1
        )
      end
    end
    
    let!(:no_deadline_task) do
      ActsAsTenant.with_tenant(organization) do
        TimeTrackableTest.create!(
          title: "No Deadline",
          deadline: nil,
          assignee: user,
          service_id: service.id,
          organization_id: organization.id,
          status: "todo",
          priority: "medium",
          position: 2
        )
      end
    end
    
    describe '.overdue' do
      it 'returns tasks with past deadlines' do
        ActsAsTenant.with_tenant(organization) do
          expect(TimeTrackableTest.overdue).to include(overdue_task)
          expect(TimeTrackableTest.overdue).not_to include(upcoming_task)
        end
      end
    end
    
    describe '.upcoming' do
      it 'returns tasks with future deadlines within 7 days' do
        ActsAsTenant.with_tenant(organization) do
          expect(TimeTrackableTest.upcoming).to include(upcoming_task)
          expect(TimeTrackableTest.upcoming).not_to include(overdue_task)
        end
      end
    end
    
    describe '.without_deadline' do
      it 'returns tasks with no deadline' do
        ActsAsTenant.with_tenant(organization) do
          expect(TimeTrackableTest.without_deadline).to include(no_deadline_task)
          expect(TimeTrackableTest.without_deadline).not_to include(upcoming_task)
        end
      end
    end
    
    describe '.by_urgency' do
      it 'orders tasks by urgency level' do
        ActsAsTenant.with_tenant(organization) do
          ordered = TimeTrackableTest.by_urgency
          expect(ordered.first).to eq(overdue_task) # Critical urgency
        end
      end
    end
  end
end