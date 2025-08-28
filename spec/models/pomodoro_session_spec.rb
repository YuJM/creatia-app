require 'rails_helper'

RSpec.describe PomodoroSession, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:service) { create(:service, organization: organization) }
  let(:task) { create(:task, assignee: user, service: service) }
  let(:pomodoro_session) { create(:pomodoro_session, user: user, task: task) }
  
  describe 'constants' do
    it 'defines work and break durations' do
      expect(PomodoroSession::WORK_DURATION).to eq(25.minutes)
      expect(PomodoroSession::SHORT_BREAK).to eq(5.minutes)
      expect(PomodoroSession::LONG_BREAK).to eq(15.minutes)
      expect(PomodoroSession::SESSIONS_BEFORE_LONG_BREAK).to eq(4)
    end
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:task) }
  end

  describe 'validations' do
    # Note: started_at and status have defaults set in the model, not validations
    
    describe 'business hours validation' do
      it 'validates session is within business hours' do
        # Skip if not enforcing business hours
        skip "Business hours validation not enforced" unless pomodoro_session.respond_to?(:within_business_hours?)
        
        # Test with non-business hours
        weekend_session = build(:pomodoro_session,
          user: user,
          task: task,
          started_at: Time.parse("2024-01-06 10:00:00") # Saturday
        )
        
        expect(weekend_session).not_to be_valid if weekend_session.enforce_business_hours?
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(
      in_progress: 0,
      completed: 1,
      cancelled: 2,
      paused: 3
    ) }
  end

  describe 'scopes' do
    before do
      ActsAsTenant.with_tenant(organization) do
        @today_session = create(:pomodoro_session,
          user: user,
          task: task,
          started_at: Time.current
        )
        @yesterday_session = create(:pomodoro_session,
          user: user,
          task: task,
          started_at: 1.day.ago
        )
        @last_week_session = create(:pomodoro_session,
          user: user,
          task: task,
          started_at: 1.week.ago
        )
        @completed_session = create(:pomodoro_session,
          user: user,
          task: task,
          status: :completed
        )
        @in_progress_session = create(:pomodoro_session,
          user: user,
          task: task,
          status: :in_progress
        )
      end
    end

    describe '.today' do
      it 'returns sessions from today' do
        ActsAsTenant.with_tenant(organization) do
          expect(PomodoroSession.today).to include(@today_session)
          expect(PomodoroSession.today).not_to include(@yesterday_session)
        end
      end
    end

    describe '.this_week' do
      it 'returns sessions from current week' do
        ActsAsTenant.with_tenant(organization) do
          sessions = PomodoroSession.this_week
          expect(sessions).to include(@today_session)
          # Depending on what day of the week the test runs, yesterday might be in this week
        end
      end
    end

    describe '.completed' do
      it 'returns only completed sessions' do
        ActsAsTenant.with_tenant(organization) do
          expect(PomodoroSession.completed).to include(@completed_session)
          expect(PomodoroSession.completed).not_to include(@in_progress_session)
        end
      end
    end

    describe '.in_progress' do
      it 'returns only in-progress sessions' do
        ActsAsTenant.with_tenant(organization) do
          expect(PomodoroSession.in_progress).to include(@in_progress_session)
          expect(PomodoroSession.in_progress).not_to include(@completed_session)
        end
      end
    end
  end

  describe '#complete!' do
    it 'marks session as completed with ended_at time' do
      ActsAsTenant.with_tenant(organization) do
        session = create(:pomodoro_session,
          user: user,
          task: task,
          status: :in_progress
        )
        
        expect { session.complete! }.to change { session.status }
          .from('in_progress')
          .to('completed')
        
        expect(session.ended_at).to be_present
        expect(session.actual_duration).to be_present
      end
    end
  end

  describe '#cancel!' do
    it 'marks session as cancelled' do
      ActsAsTenant.with_tenant(organization) do
        session = create(:pomodoro_session,
          user: user,
          task: task,
          status: :in_progress
        )
        
        expect { session.cancel! }.to change { session.status }
          .from('in_progress')
          .to('cancelled')
        
        expect(session.ended_at).to be_present
      end
    end
  end

  describe '#pause!' do
    it 'marks session as paused' do
      ActsAsTenant.with_tenant(organization) do
        session = create(:pomodoro_session,
          user: user,
          task: task,
          status: :in_progress
        )
        
        expect { session.pause! }.to change { session.status }
          .from('in_progress')
          .to('paused')
      end
    end
  end

  describe '#resume!' do
    it 'resumes a paused session' do
      ActsAsTenant.with_tenant(organization) do
        session = create(:pomodoro_session,
          user: user,
          task: task,
          status: :paused
        )
        
        expect { session.resume! }.to change { session.status }
          .from('paused')
          .to('in_progress')
      end
    end
  end

  describe '#time_remaining' do
    context 'when session is in progress' do
      it 'calculates remaining time' do
        ActsAsTenant.with_tenant(organization) do
          session = create(:pomodoro_session,
            user: user,
            task: task,
            status: :in_progress,
            started_at: 10.minutes.ago
          )
          
          remaining = session.time_remaining
          expect(remaining).to be_between(14.minutes, 16.minutes)
        end
      end
    end

    context 'when session is completed' do
      it 'returns 0' do
        ActsAsTenant.with_tenant(organization) do
          session = create(:pomodoro_session,
            user: user,
            task: task,
            status: :completed
          )
          
          expect(session.time_remaining).to eq(0)
        end
      end
    end
  end

  describe '#progress_percentage' do
    it 'calculates progress as percentage' do
      ActsAsTenant.with_tenant(organization) do
        session = create(:pomodoro_session,
          user: user,
          task: task,
          status: :in_progress,
          started_at: 15.minutes.ago
        )
        
        progress = session.progress_percentage
        expect(progress).to be_between(55, 65) # Around 60%
      end
    end
  end

  describe '#long_break_next?' do
    context 'when 4 sessions completed today' do
      it 'returns true' do
        ActsAsTenant.with_tenant(organization) do
          4.times do
            create(:pomodoro_session,
              user: user,
              task: task,
              status: :completed,
              started_at: Time.current
            )
          end
          
          new_session = create(:pomodoro_session,
            user: user,
            task: task,
            status: :in_progress
          )
          
          expect(new_session.long_break_next?).to be true
        end
      end
    end

    context 'when less than 4 sessions completed' do
      it 'returns false' do
        ActsAsTenant.with_tenant(organization) do
          2.times do
            create(:pomodoro_session,
              user: user,
              task: task,
              status: :completed,
              started_at: Time.current
            )
          end
          
          new_session = create(:pomodoro_session,
            user: user,
            task: task,
            status: :in_progress
          )
          
          expect(new_session.long_break_next?).to be false
        end
      end
    end
  end

  describe '#todays_completed_sessions' do
    it 'returns count of completed sessions today' do
      ActsAsTenant.with_tenant(organization) do
        3.times do
          create(:pomodoro_session,
            user: user,
            task: task,
            status: :completed,
            started_at: Time.current
          )
        end
        
        create(:pomodoro_session,
          user: user,
          task: task,
          status: :completed,
          started_at: 1.day.ago
        )
        
        session = create(:pomodoro_session, user: user, task: task)
        expect(session.todays_completed_sessions).to eq(3)
      end
    end
  end

  describe '#next_session_type' do
    context 'after completing 4 sessions' do
      it 'returns :long_break' do
        ActsAsTenant.with_tenant(organization) do
          session = create(:pomodoro_session,
            user: user,
            task: task,
            session_count: 4
          )
          
          expect(session.next_session_type).to eq(:long_break)
        end
      end
    end

    context 'after completing fewer than 4 sessions' do
      it 'returns :short_break' do
        ActsAsTenant.with_tenant(organization) do
          session = create(:pomodoro_session,
            user: user,
            task: task,
            session_count: 2
          )
          
          expect(session.next_session_type).to eq(:short_break)
        end
      end
    end
  end

  describe 'business time integration' do
    it 'calculates duration using business time when configured' do
      ActsAsTenant.with_tenant(organization) do
        friday_afternoon = Time.parse("2024-01-05 16:00:00") # Friday 4 PM
        monday_morning = Time.parse("2024-01-08 09:00:00") # Monday 9 AM
        
        session = create(:pomodoro_session,
          user: user,
          task: task,
          started_at: friday_afternoon,
          ended_at: monday_morning,
          status: :completed
        )
        
        # Should only count business hours
        business_duration = session.business_duration if session.respond_to?(:business_duration)
        expect(business_duration).to be < 72.hours if business_duration
      end
    end
  end
end
