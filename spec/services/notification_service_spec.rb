# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotificationService do
  let(:user) { create(:user) }
  let(:assignee) { create(:user) }
  let(:task) { create(:task, assignee: assignee) }
  
  describe '.task_assigned' do
    it 'creates task assignment notification' do
      notification = NotificationService.task_assigned(task, assignee, user)
      
      expect(notification).to be_persisted
      expect(notification.recipient_id).to eq(assignee.id)
      expect(notification.type).to eq('TaskAssignedNotification')
      expect(notification.sender_id).to eq(user.id)
      expect(notification.related_type).to eq('Task')
      expect(notification.related_id).to eq(task.id)
    end

    it 'sets high priority for urgent tasks' do
      urgent_task = create(:task, assignee: assignee, priority: 'urgent')
      notification = NotificationService.task_assigned(urgent_task, assignee, user)
      
      expect(notification.priority).to eq('high')
    end
  end

  describe '.task_completed' do
    it 'notifies task creator and watchers' do
      task.watchers = create_list(:user, 2)
      
      notifications = NotificationService.task_completed(task, user)
      
      # Creator + 2 watchers
      expect(notifications.count).to eq(3)
      expect(notifications.map(&:type).uniq).to eq(['TaskCompletedNotification'])
    end
  end

  describe '.task_due_soon' do
    it 'creates due soon notification' do
      task.due_date = 1.day.from_now
      notification = NotificationService.task_due_soon(task)
      
      expect(notification.priority).to eq('high')
      expect(notification.channels).to include('push')
    end

    it 'returns nil if no assignee' do
      task.assignee = nil
      expect(NotificationService.task_due_soon(task)).to be_nil
    end
  end

  describe '.comment_mention' do
    let(:comment) { create(:comment, user: user, task: task) }
    
    it 'creates mention notification' do
      notification = NotificationService.comment_mention(comment, assignee)
      
      expect(notification.recipient_id).to eq(assignee.id)
      expect(notification.category).to eq('mention')
      expect(notification.related_type).to eq('Comment')
    end
  end

  describe '.sprint_started' do
    let(:sprint) { create(:sprint) }
    let(:team) { create(:team, members: create_list(:user, 3)) }
    
    before { sprint.team = team }
    
    it 'notifies all team members' do
      notifications = NotificationService.sprint_started(sprint)
      
      expect(notifications.count).to eq(3)
      expect(notifications.map(&:category).uniq).to eq(['sprint'])
    end
  end

  describe '.team_invitation' do
    let(:team) { create(:team) }
    
    it 'creates invitation notification' do
      notification = NotificationService.team_invitation(team, assignee, user)
      
      expect(notification.recipient_id).to eq(assignee.id)
      expect(notification.sender_id).to eq(user.id)
      expect(notification.category).to eq('team')
      expect(notification.channels).to include('email')
    end
  end

  describe '.system_announcement' do
    it 'sends to all users by default' do
      create_list(:user, 5)
      
      notifications = NotificationService.system_announcement(
        'System Update',
        'Maintenance scheduled'
      )
      
      expect(notifications.count).to eq(User.count)
    end

    it 'sends to specific recipients' do
      recipients = create_list(:user, 2)
      
      notifications = NotificationService.system_announcement(
        'Update',
        'Message',
        recipients,
        'high'
      )
      
      expect(notifications.count).to eq(2)
      expect(notifications.first.priority).to eq('high')
    end
  end

  describe '.pomodoro_session_complete' do
    let(:session) { create(:pomodoro_session_mongo, user: user) }
    
    it 'creates completion notification' do
      notification = NotificationService.pomodoro_session_complete(session)
      
      expect(notification.recipient_id).to eq(user.id)
      expect(notification.channels).to include('push')
      expect(notification.priority).to eq('low')
    end
  end

  describe '.mark_all_as_read' do
    before do
      create_list(:notification, 3, recipient_id: user.id, status: 'delivered')
    end
    
    it 'marks all notifications as read' do
      NotificationService.mark_all_as_read(user)
      
      unread = Notification.for_recipient(user.id).unread.count
      expect(unread).to eq(0)
    end
  end

  describe '.archive_old_notifications' do
    before do
      create(:notification, recipient_id: user.id, created_at: 45.days.ago)
      create(:notification, recipient_id: user.id, created_at: 15.days.ago)
      create(:notification, recipient_id: user.id, created_at: 1.day.ago)
    end
    
    it 'archives old notifications' do
      NotificationService.archive_old_notifications(user, 30)
      
      archived = Notification.for_recipient(user.id).archived.count
      expect(archived).to eq(1)
    end
  end

  describe '.user_notification_stats' do
    before do
      create_list(:notification, 2, 
        recipient_id: user.id, 
        category: 'task',
        status: 'read',
        read_at: Time.current
      )
      create(:notification, 
        recipient_id: user.id, 
        category: 'comment',
        priority: 'high',
        click_count: 3
      )
    end
    
    it 'returns notification statistics' do
      stats = NotificationService.user_notification_stats(user, :week)
      
      expect(stats[:total]).to eq(3)
      expect(stats[:unread]).to eq(1)
      expect(stats[:by_category]['task']).to eq(2)
      expect(stats[:by_category]['comment']).to eq(1)
      expect(stats[:by_priority]['high']).to eq(1)
      expect(stats[:interaction_rate]).to be_a(Float)
    end
  end
end