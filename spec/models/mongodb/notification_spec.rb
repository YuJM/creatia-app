require 'rails_helper'

RSpec.describe Notification, type: :model do
  # 테스트 후 데이터 정리
  after(:each) do
    Notification.delete_all
  end

  describe 'validations' do
    it 'requires recipient_id' do
      notification = Notification.new(
        type: 'TestNotification',
        title: 'Test'
      )
      expect(notification).not_to be_valid
      expect(notification.errors[:recipient_id]).to include("can't be blank")
    end

    it 'requires type' do
      notification = Notification.new(
        recipient_id: 1,
        title: 'Test'
      )
      expect(notification).not_to be_valid
      expect(notification.errors[:type]).to include("can't be blank")
    end

    it 'requires title' do
      notification = Notification.new(
        recipient_id: 1,
        type: 'TestNotification'
      )
      expect(notification).not_to be_valid
      expect(notification.errors[:title]).to include("can't be blank")
    end

    it 'validates status inclusion' do
      notification = build(:notification, status: 'invalid_status')
      expect(notification).not_to be_valid
      expect(notification.errors[:status]).to include("is not included in the list")
    end

    it 'validates priority inclusion' do
      notification = build(:notification, priority: 'invalid_priority')
      expect(notification).not_to be_valid
      expect(notification.errors[:priority]).to include("is not included in the list")
    end

    it 'validates channels' do
      notification = build(:notification, channels: ['invalid_channel'])
      expect(notification).not_to be_valid
      expect(notification.errors[:channels]).to include("contains invalid channels: invalid_channel")
    end
  end

  describe 'defaults' do
    let(:notification) do
      Notification.create!(
        recipient_id: 1,
        type: 'TestNotification',
        title: 'Test Title',
        body: 'Test body content'
      )
    end

    it 'sets default status to pending' do
      expect(notification.status).to eq('pending')
    end

    it 'sets default priority to medium' do
      expect(notification.priority).to eq('medium')
    end

    it 'sets default channels to in_app' do
      expect(notification.channels).to eq(['in_app'])
    end

    it 'generates preview from body' do
      long_body = 'a' * 150
      notification = Notification.create!(
        recipient_id: 1,
        type: 'TestNotification',
        title: 'Test',
        body: long_body
      )
      expect(notification.preview).to eq('a' * 97 + '...')
    end
  end

  describe 'scopes' do
    before do
      # 읽지 않은 알림
      @unread1 = Notification.create!(
        recipient_id: 1,
        type: 'TestNotification',
        title: 'Unread 1',
        body: 'Body',
        status: 'delivered'
      )
      
      # 읽은 알림
      @read1 = Notification.create!(
        recipient_id: 1,
        type: 'TestNotification',
        title: 'Read 1',
        body: 'Body',
        read_at: Time.current
      )
      
      # 높은 우선순위 알림
      @high_priority = Notification.create!(
        recipient_id: 2,
        type: 'TestNotification',
        title: 'High Priority',
        body: 'Body',
        priority: 'high'
      )
      
      # 아카이브된 알림
      @archived = Notification.create!(
        recipient_id: 1,
        type: 'TestNotification',
        title: 'Archived',
        body: 'Body',
        archived_at: Time.current
      )
    end

    it 'returns unread notifications' do
      expect(Notification.unread).to include(@unread1)
      expect(Notification.unread).not_to include(@read1, @archived)
    end

    it 'returns read notifications' do
      expect(Notification.read).to include(@read1)
      expect(Notification.read).not_to include(@unread1)
    end

    it 'returns high priority notifications' do
      expect(Notification.high_priority).to include(@high_priority)
      expect(Notification.high_priority).not_to include(@unread1)
    end

    it 'returns notifications for specific recipient' do
      user1_notifications = Notification.for_recipient(1)
      expect(user1_notifications).to include(@unread1, @read1, @archived)
      expect(user1_notifications).not_to include(@high_priority)
    end

    it 'returns not archived notifications' do
      expect(Notification.not_archived).to include(@unread1, @read1, @high_priority)
      expect(Notification.not_archived).not_to include(@archived)
    end
  end

  describe 'instance methods' do
    let(:notification) do
      Notification.create!(
        recipient_id: 1,
        type: 'TestNotification',
        title: 'Test',
        body: 'Test body'
      )
    end

    describe '#mark_as_read!' do
      it 'marks notification as read' do
        expect(notification.read?).to be_falsey
        notification.mark_as_read!
        expect(notification.read?).to be_truthy
        expect(notification.read_at).not_to be_nil
        expect(notification.status).to eq('read')
        expect(notification.read_count).to eq(1)
      end

      it 'updates channel status' do
        notification.mark_as_read!('email')
        expect(notification.channel_statuses['email']).to eq('read')
      end
    end

    describe '#archive!' do
      it 'archives notification' do
        expect(notification.archived?).to be_falsey
        notification.archive!
        expect(notification.archived?).to be_truthy
        expect(notification.archived_at).not_to be_nil
        expect(notification.status).to eq('archived')
      end
    end

    describe '#dismiss!' do
      it 'dismisses notification' do
        expect(notification.dismissed).to be_falsey
        notification.dismiss!
        expect(notification.dismissed).to be_truthy
        expect(notification.dismissed_at).not_to be_nil
      end
    end

    describe '#track_interaction' do
      it 'tracks user interactions' do
        notification.track_interaction('click', 'in_app', { button: 'view' })
        expect(notification.interactions.size).to eq(1)
        expect(notification.interactions.first['type']).to eq('click')
        expect(notification.click_count).to eq(1)
      end
    end

    describe '#high_priority?' do
      it 'returns true for high priority notifications' do
        high = Notification.create!(
          recipient_id: 1,
          type: 'TestNotification',
          title: 'Test',
          body: 'Body',
          priority: 'urgent'
        )
        expect(high.high_priority?).to be_truthy
        expect(notification.high_priority?).to be_falsey
      end
    end
  end

  describe 'class methods' do
    describe '.notify' do
      it 'creates a notification for recipient' do
        user = double('User', id: 1, email: 'test@example.com', organization_id: 1)
        
        notification = Notification.notify(
          user,
          'TaskAssignedNotification',
          title: 'Task Assigned',
          body: 'You have been assigned a new task'
        )
        
        expect(notification).to be_persisted
        expect(notification.recipient_id).to eq(1)
        expect(notification.recipient_email).to eq('test@example.com')
        expect(notification.organization_id).to eq(1)
      end
    end

    describe '.unread_count_for' do
      before do
        3.times do
          Notification.create!(
            recipient_id: 1,
            type: 'TestNotification',
            title: 'Test',
            body: 'Body',
            status: 'delivered'
          )
        end
        
        # 읽은 알림
        Notification.create!(
          recipient_id: 1,
          type: 'TestNotification',
          title: 'Test',
          body: 'Body',
          read_at: Time.current
        )
      end

      it 'returns unread count for user' do
        expect(Notification.unread_count_for(1)).to eq(3)
      end
    end

    describe '.summary_for' do
      before do
        # 다양한 카테고리의 알림 생성
        Notification.create!(
          recipient_id: 1,
          type: 'TestNotification',
          title: 'Task',
          body: 'Body',
          category: 'task',
          priority: 'high',
          status: 'delivered'
        )
        
        Notification.create!(
          recipient_id: 1,
          type: 'TestNotification',
          title: 'System',
          body: 'Body',
          category: 'system',
          status: 'delivered'
        )
      end

      it 'returns summary statistics for user' do
        summary = Notification.summary_for(1)
        
        expect(summary[:total]).to eq(2)
        expect(summary[:unread]).to eq(2)
        expect(summary[:high_priority]).to eq(1)
        expect(summary[:by_category]).to include('task' => 1, 'system' => 1)
        expect(summary[:recent]).to be_an(Array)
      end
    end
  end

  describe 'MongoDB specific features' do
    it 'uses MongoDB as database' do
      expect(Notification.collection.database.name).to include('test')
    end

    it 'creates indexes' do
      indexes = Notification.collection.indexes.to_a
      index_keys = indexes.map { |i| i['key'] }
      
      expect(index_keys).to include({ 'recipient_id' => 1, 'created_at' => -1 })
      expect(index_keys).to include({ 'status' => 1, 'scheduled_for' => 1 })
    end

    it 'supports complex queries' do
      # 복잡한 쿼리 테스트
      Notification.create!(
        recipient_id: 1,
        type: 'TestNotification',
        title: 'Test',
        body: 'Body',
        priority: 'high',
        category: 'task',
        tags: ['important', 'urgent']
      )
      
      result = Notification.where(
        recipient_id: 1,
        :priority.in => ['high', 'urgent'],
        :tags.in => ['important']
      ).first
      
      expect(result).not_to be_nil
      expect(result.tags).to include('important')
    end
  end
end