require 'rails_helper'

RSpec.describe NotificationSchedulerJob, type: :job do
  include ActiveJob::TestHelper
  
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:service) { create(:service, organization: organization) }
  let(:job) { described_class.new }
  
  describe '#perform' do
    it 'calls all check methods' do
      expect(job).to receive(:check_task_deadlines)
      expect(job).to receive(:check_overdue_tasks)
      expect(job).to receive(:check_upcoming_tasks)
      expect(job).to receive(:process_pomodoro_sessions)
      
      job.perform
    end
  end
  
  describe '#check_task_deadlines' do
    context 'with tasks due within an hour' do
      let!(:task_due_soon) do
        ActsAsTenant.with_tenant(organization) do
          create(:task,
            assignee: user,
            service: service,
            deadline: 59.minutes.from_now
          )
        end
      end
      
      let!(:task_due_later) do
        ActsAsTenant.with_tenant(organization) do
          create(:task,
            assignee: user,
            service: service,
            deadline: 2.hours.from_now
          )
        end
      end
      
      it 'sends notification for tasks due within an hour' do
        expect(TaskReminderNotifier).to receive(:with).with(
          hash_including(
            task: task_due_soon,
            reminder_type: :one_hour
          )
        ).and_return(double(deliver: true))
        
        job.send(:check_task_deadlines)
      end
      
      it 'does not send notification for tasks due later' do
        allow(TaskReminderNotifier).to receive(:with).and_return(double(deliver: true))
        
        job.send(:check_task_deadlines)
        
        expect(TaskReminderNotifier).not_to have_received(:with).with(
          hash_including(task: task_due_later)
        )
      end
    end
    
    context 'with completed tasks' do
      let!(:completed_task) do
        ActsAsTenant.with_tenant(organization) do
          create(:task,
            assignee: user,
            service: service,
            deadline: 30.minutes.from_now,
            completed_at: 1.hour.ago
          )
        end
      end
      
      it 'does not send notification for completed tasks' do
        expect(TaskReminderNotifier).not_to receive(:with)
        
        job.send(:check_task_deadlines)
      end
    end
  end
  
  describe '#check_overdue_tasks' do
    let!(:overdue_task) do
      ActsAsTenant.with_tenant(organization) do
        create(:task,
          assignee: user,
          service: service,
          deadline: 1.hour.ago
        )
      end
    end
    
    it 'sends notification for overdue tasks' do
      expect(TaskReminderNotifier).to receive(:with).with(
        hash_including(
          task: overdue_task,
          reminder_type: :overdue
        )
      ).and_return(double(deliver: true))
      
      job.send(:check_overdue_tasks)
    end
    
    context 'when already notified today' do
      before do
        Rails.cache.write(
          "notified_task:#{overdue_task.id}:overdue",
          Time.current,
          expires_in: 24.hours
        )
      end
      
      it 'does not send duplicate notification' do
        expect(TaskReminderNotifier).not_to receive(:with)
        
        job.send(:check_overdue_tasks)
      end
    end
  end
  
  describe '#check_upcoming_tasks' do
    let!(:upcoming_task) do
      ActsAsTenant.with_tenant(organization) do
        create(:task,
          assignee: user,
          service: service,
          deadline: 12.hours.from_now
        )
      end
    end
    
    it 'sends notification for upcoming tasks' do
      expect(TaskReminderNotifier).to receive(:with).with(
        hash_including(
          task: upcoming_task,
          reminder_type: :upcoming
        )
      ).and_return(double(deliver: true))
      
      job.send(:check_upcoming_tasks)
    end
  end
  
  describe '#process_pomodoro_sessions' do
    context 'with expired sessions' do
      let!(:expired_session) do
        ActsAsTenant.with_tenant(organization) do
          create(:pomodoro_session,
            user: user,
            task: create(:task, assignee: user, service: service),
            status: :in_progress,
            started_at: 26.minutes.ago
          )
        end
      end
      
      it 'completes expired pomodoro sessions' do
        expect_any_instance_of(PomodoroSession).to receive(:complete!)
        expect(PomodoroNotifier).to receive(:with).and_return(double(deliver: true))
        
        job.send(:process_pomodoro_sessions)
      end
      
      it 'schedules break notification job' do
        allow_any_instance_of(PomodoroSession).to receive(:complete!)
        allow(PomodoroNotifier).to receive(:with).and_return(double(deliver: true))
        
        expect(EndBreakJob).to receive(:set).with(wait: anything).and_return(
          double(perform_later: true)
        )
        
        job.send(:process_pomodoro_sessions)
      end
    end
    
    context 'with active sessions within time' do
      let!(:active_session) do
        ActsAsTenant.with_tenant(organization) do
          create(:pomodoro_session,
            user: user,
            task: create(:task, assignee: user, service: service),
            status: :in_progress,
            started_at: 10.minutes.ago
          )
        end
      end
      
      it 'does not complete active sessions' do
        expect_any_instance_of(PomodoroSession).not_to receive(:complete!)
        
        job.send(:process_pomodoro_sessions)
      end
    end
  end
  
  describe 'caching and deduplication' do
    let!(:task) do
      ActsAsTenant.with_tenant(organization) do
        create(:task,
          assignee: user,
          service: service,
          deadline: 30.minutes.from_now
        )
      end
    end
    
    it 'marks tasks as notified to prevent duplicates' do
      allow(TaskReminderNotifier).to receive(:with).and_return(double(deliver: true))
      
      job.send(:check_task_deadlines)
      
      cached_ids = Rails.cache.fetch("notified_tasks:one_hour")
      expect(cached_ids).to include(task.id)
    end
    
    it 'respects notification intervals' do
      # Mark as recently notified
      job.send(:mark_as_notified, task.id, :upcoming)
      
      # Should not send another notification
      expect(TaskReminderNotifier).not_to receive(:with)
      
      job.send(:check_upcoming_tasks)
    end
  end
  
  describe 'error handling' do
    it 'retries on ActiveRecord::RecordNotFound' do
      assert_enqueued_with(job: described_class) do
        described_class.perform_later
      end
    end
  end
end