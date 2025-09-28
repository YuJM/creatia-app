# frozen_string_literal: true

require 'alba'

# Alba 직렬화를 위한 Notification 리소스
class NotificationResource
  include Alba::Resource

  # 기본 필드
  attributes :id, :type, :title, :body, :preview, :icon
  attributes :category, :priority, :status
  attributes :action_text, :action_url, :image_url

  # 시간 필드
  attribute :created_at do |notification|
    notification.created_at&.iso8601
  end

  attribute :sent_at do |notification|
    notification.sent_at&.iso8601
  end

  attribute :delivered_at do |notification|
    notification.delivered_at&.iso8601
  end

  attribute :read_at do |notification|
    notification.read_at&.iso8601
  end

  attribute :archived_at do |notification|
    notification.archived_at&.iso8601
  end

  attribute :expires_at do |notification|
    notification.expires_at&.iso8601
  end

  # 상태 체크
  attribute :is_read do |notification|
    notification.read?
  end

  attribute :is_archived do |notification|
    notification.archived?
  end

  attribute :is_expired do |notification|
    notification.expired?
  end

  attribute :is_high_priority do |notification|
    notification.high_priority?
  end

  # 발신자 정보
  attribute :sender do |notification|
    if notification.sender_id
      {
        id: notification.sender_id,
        type: notification.sender_type,
        name: notification.sender_name
      }
    end
  end

  # 관련 엔티티
  attribute :related do |notification|
    if notification.related_type && notification.related_id
      {
        type: notification.related_type,
        id: notification.related_id,
        data: notification.related_data
      }
    end
  end

  # 상호작용 통계
  attribute :stats do |notification|
    {
      read_count: notification.read_count,
      click_count: notification.click_count,
      dismissed: notification.dismissed
    }
  end

  # 채널 정보 (옵션)
  attribute :channels, if: proc { |notification, params|
    params && params[:include_channels]
  }

  attribute :channel_statuses, if: proc { |notification, params|
    params && params[:include_channels]
  }

  # 메타데이터 (옵션)
  attribute :metadata, if: proc { |notification, params|
    params && params[:include_metadata]
  }

  # 상호작용 히스토리 (옵션)
  attribute :interactions, if: proc { |notification, params|
    params && params[:include_interactions]
  }

  # 그룹/배치 정보 (옵션)
  attribute :group_id, if: proc { |notification, params|
    params && params[:include_grouping] && notification.group_id
  }

  attribute :batch_id, if: proc { |notification, params|
    params && params[:include_grouping] && notification.batch_id
  }

  attribute :thread_id, if: proc { |notification, params|
    params && params[:include_grouping] && notification.thread_id
  }

  # 컬렉션을 위한 메타 정보
  class << self
    def collection_meta(notifications, params = {})
      {
        total: notifications.total_count,
        page: notifications.current_page,
        per_page: notifications.limit_value,
        total_pages: notifications.total_pages,
        unread_count: notifications.unread.count,
        high_priority_count: notifications.high_priority.unread.count
      }
    end
  end
end