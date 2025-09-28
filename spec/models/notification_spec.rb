# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notification, type: :model do
  let(:user) { create(:user) }
  let(:sender) { create(:user) }
  
  describe 'validations' do
    it { should validate_presence_of(:recipient_id) }
    it { should validate_presence_of(:type) }
    it { should validate_presence_of(:title) }
    it { should validate_inclusion_of(:status).in_array(Notification::STATUSES) }
    it { should validate_inclusion_of(:priority).in_array(Notification::PRIORITIES) }
  end

  describe 'indexes' do
    it 'has proper indexes for performance' do
      indexes = Notification.collection.indexes.map { |i| i['key'] }
      
      expect(indexes).to include({ 'recipient_id' => 1, 'created_at' => -1 })
      expect(indexes).to include({ 'status' => 1, 'scheduled_for' => 1 })
      expect(indexes).to include({ 'expires_at' => 1 })
    end
  end

  describe '.notify' do
    it 'creates a notification for a user' do
      notification = Notification.notify(
        user,
        'TestNotification',
        title: 'Test Title',
        body: 'Test Body',
        sender_id: sender.id,
        sender_name: sender.name
      )

      expect(notification).to be_persisted
      expect(notification.recipient_id).to eq(user.id)
      expect(notification.type).to eq('TestNotification')
      expect(notification.title).to eq('Test Title')
      expect(notification.body).to eq('Test Body')
    end

    it 'sets default values' do
      notification = Notification.notify(
        user,
        'TestNotification',
        title: 'Test',
        body: 'Body'
      )

      expect(notification.status).to eq('pending')
      expect(notification.priority).to eq('normal')
      expect(notification.channels).to eq(['in_app'])
    end
  end

  describe '.notify_all' do
    let(:users) { create_list(:user, 3) }

    it 'creates notifications for multiple users' do
      notifications = Notification.notify_all(
        users,
        'BroadcastNotification',
        title: 'Broadcast',
        body: 'Message to all'
      )

      expect(notifications.count).to eq(3)
      expect(notifications.map(&:batch_id).uniq.count).to eq(1)
    end
  end

  describe '.schedule' do
    it 'creates a scheduled notification' do
      scheduled_time = 1.hour.from_now
      
      notification = Notification.schedule(
        user,
        'ScheduledNotification',
        scheduled_time,
        title: 'Scheduled',
        body: 'Later'
      )

      expect(notification.scheduled_for).to be_within(1.second).of(scheduled_time)
      expect(notification.scheduled?).to be true
    end
  end

  describe '#deliver!' do
    let(:notification) do
      Notification.notify(
        user,
        'TestNotification',
        title: 'Test',
        body: 'Body'
      )
    end

    it 'queues the notification for delivery' do
      expect {
        notification.deliver!
      }.to have_enqueued_job(NotificationDeliveryJob)

      notification.reload
      expect(notification.status).to eq('queued')
      expect(notification.queued_at).to be_present
    end

    it 'returns false if already sent' do
      notification.update!(status: 'sent')
      expect(notification.deliver!).to be false
    end
  end

  describe '#mark_as_read!' do
    let(:notification) do
      Notification.notify(
        user,
        'TestNotification',
        title: 'Test',
        body: 'Body',
        status: 'delivered'
      )
    end

    it 'marks the notification as read' do
      notification.mark_as_read!
      
      expect(notification.read?).to be true
      expect(notification.read_at).to be_present
      expect(notification.read_count).to eq(1)
      expect(notification.status).to eq('read')
    end

    it 'increments read count on multiple reads' do
      notification.mark_as_read!
      notification.update!(read_at: nil, status: 'delivered')
      notification.mark_as_read!
      
      expect(notification.read_count).to eq(2)
    end
  end

  describe '#archive!' do
    let(:notification) { create(:notification, recipient_id: user.id) }

    it 'archives the notification' do
      notification.archive!
      
      expect(notification.archived?).to be true
      expect(notification.archived_at).to be_present
      expect(notification.status).to eq('archived')
    end
  end

  describe '#track_interaction' do
    let(:notification) { create(:notification, recipient_id: user.id) }

    it 'tracks user interactions' do
      notification.track_interaction('click', 'in_app', { button: 'action' })
      
      expect(notification.interactions.count).to eq(1)
      expect(notification.interactions.first['type']).to eq('click')
      expect(notification.click_count).to eq(1)
    end
  end

  describe '#dismiss!' do
    let(:notification) { create(:notification, recipient_id: user.id) }

    it 'dismisses the notification' do
      notification.dismiss!
      
      expect(notification.dismissed?).to be true
      expect(notification.dismissed_at).to be_present
    end
  end

  describe '#retry!' do
    let(:notification) do
      create(:notification, 
        recipient_id: user.id,
        status: 'failed',
        retry_count: 1
      )
    end

    it 'retries failed notification' do
      expect {
        notification.retry!
      }.to have_enqueued_job(NotificationDeliveryJob)
      
      expect(notification.retry_count).to eq(2)
      expect(notification.last_retry_at).to be_present
      expect(notification.status).to eq('pending')
    end

    it 'does not retry after max attempts' do
      notification.update!(retry_count: 3)
      expect(notification.retry!).to be false
    end
  end

  describe 'scopes' do
    before do
      create(:notification, recipient_id: user.id, status: 'delivered', read_at: nil)
      create(:notification, recipient_id: user.id, status: 'read', read_at: Time.current)
      create(:notification, recipient_id: user.id, status: 'archived', archived_at: Time.current)
      create(:notification, recipient_id: user.id, priority: 'high')
      create(:notification, recipient_id: user.id, priority: 'urgent')
    end

    it 'filters unread notifications' do
      expect(Notification.for_recipient(user.id).unread.count).to eq(1)
    end

    it 'filters read notifications' do
      expect(Notification.for_recipient(user.id).read.count).to eq(1)
    end

    it 'filters archived notifications' do
      expect(Notification.for_recipient(user.id).archived.count).to eq(1)
    end

    it 'filters high priority notifications' do
      expect(Notification.for_recipient(user.id).high_priority.count).to eq(2)
    end
  end

  describe '.unread_count_for' do
    before do
      create_list(:notification, 3, recipient_id: user.id, status: 'delivered')
      create(:notification, recipient_id: user.id, status: 'read', read_at: Time.current)
    end

    it 'returns count of unread notifications' do
      expect(Notification.unread_count_for(user.id)).to eq(3)
    end
  end

  describe '.summary_for' do
    before do
      create_list(:notification, 2, recipient_id: user.id, status: 'delivered', category: 'task')
      create(:notification, recipient_id: user.id, status: 'delivered', category: 'comment', priority: 'high')
      create(:notification, recipient_id: user.id, status: 'read', read_at: Time.current)
    end

    it 'returns notification summary' do
      summary = Notification.summary_for(user.id)
      
      expect(summary[:total]).to eq(4)
      expect(summary[:unread]).to eq(3)
      expect(summary[:high_priority]).to eq(1)
      expect(summary[:by_category]['task']).to eq(2)
      expect(summary[:by_category]['comment']).to eq(1)
      expect(summary[:recent].count).to eq(4)
    end
  end

  describe 'TTL index' do
    it 'has TTL index on archived_at' do
      ttl_index = Notification.collection.indexes.find { |i| i['expireAfterSeconds'] }
      
      expect(ttl_index).to be_present
      expect(ttl_index['key']).to eq({ 'archived_at' => 1 })
      expect(ttl_index['expireAfterSeconds']).to eq(31536000) # 1 year
    end
  end

  describe 'multi-channel delivery' do
    let(:notification) do
      Notification.notify(
        user,
        'MultiChannelNotification',
        title: 'Multi',
        body: 'Channel',
        channels: ['in_app', 'email', 'push']
      )
    end

    it 'tracks channel statuses separately' do
      notification.deliver_to_channel('in_app')
      notification.deliver_to_channel('email')
      
      expect(notification.channel_statuses['in_app']).to eq('delivered')
      expect(notification.channel_statuses['email']).to eq('sent')
      expect(notification.channel_statuses['push']).to be_nil
    end
  end
end