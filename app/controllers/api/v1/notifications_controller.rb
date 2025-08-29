# frozen_string_literal: true

module Api
  module V1
    # 알림 조회 및 관리 API
    class NotificationsController < BaseController
      before_action :set_notification, only: [:show, :mark_as_read, :dismiss, :archive]

      # GET /api/v1/notifications
      def index
        @notifications = current_user_notifications
        @notifications = apply_filters(@notifications)
        @notifications = @notifications.page(params[:page]).per(params[:per_page] || 20)

        render json: NotificationResource.new(@notifications, params: serialization_params)
      end

      # GET /api/v1/notifications/summary
      def summary
        summary = Notification.summary_for(current_user.id)
        
        render json: {
          total: summary[:total],
          unread: summary[:unread],
          high_priority: summary[:high_priority],
          by_category: summary[:by_category],
          recent: summary[:recent].map { |n| NotificationResource.new(n).as_json }
        }
      end

      # GET /api/v1/notifications/unread_count
      def unread_count
        count = Notification.unread_count_for(current_user.id)
        
        render json: { count: count }
      end

      # GET /api/v1/notifications/:id
      def show
        render json: NotificationResource.new(@notification)
      end

      # POST /api/v1/notifications/:id/read
      def mark_as_read
        @notification.mark_as_read!
        
        render json: NotificationResource.new(@notification)
      end

      # POST /api/v1/notifications/mark_all_read
      def mark_all_as_read
        NotificationService.mark_all_as_read(current_user)
        
        render json: { message: 'All notifications marked as read' }
      end

      # POST /api/v1/notifications/:id/dismiss
      def dismiss
        @notification.dismiss!
        
        render json: { message: 'Notification dismissed' }
      end

      # POST /api/v1/notifications/:id/archive
      def archive
        @notification.archive!
        
        render json: { message: 'Notification archived' }
      end

      # POST /api/v1/notifications/:id/interaction
      def track_interaction
        @notification = current_user_notifications.find(params[:id])
        
        @notification.track_interaction(
          params[:type] || 'click',
          params[:channel] || 'in_app',
          params[:details] || {}
        )
        
        render json: { message: 'Interaction tracked' }
      end

      # GET /api/v1/notifications/preferences
      def preferences
        preferences = current_user.notification_preferences || default_preferences
        
        render json: preferences
      end

      # PUT /api/v1/notifications/preferences
      def update_preferences
        NotificationService.update_user_preferences(
          current_user,
          notification_preferences_params
        )
        
        render json: current_user.notification_preferences
      end

      # POST /api/v1/notifications/test
      def send_test
        # Development/testing endpoint
        return render_unauthorized unless Rails.env.development?
        
        notification = Notification.notify(
          current_user,
          'TestNotification',
          title: params[:title] || 'Test Notification',
          body: params[:body] || 'This is a test notification',
          category: params[:category] || 'system',
          priority: params[:priority] || 'normal',
          channels: params[:channels] || ['in_app']
        )
        
        render json: NotificationResource.new(notification)
      end

      private

      def current_user_notifications
        Notification.for_recipient(current_user.id)
                   .not_expired
                   .not_archived
                   .recent
      end

      def set_notification
        @notification = current_user_notifications.find(params[:id])
      rescue Mongoid::Errors::DocumentNotFound
        render_not_found
      end

      def apply_filters(notifications)
        # 카테고리 필터
        if params[:category].present?
          notifications = notifications.by_category(params[:category])
        end

        # 우선순위 필터
        if params[:priority].present?
          notifications = notifications.by_priority(params[:priority])
        end

        # 상태 필터
        case params[:status]
        when 'unread'
          notifications = notifications.unread
        when 'read'
          notifications = notifications.read
        when 'archived'
          notifications = notifications.archived
        end

        # 타입 필터
        if params[:type].present?
          notifications = notifications.by_type(params[:type])
        end

        # 날짜 범위 필터
        if params[:from].present?
          notifications = notifications.where(:created_at.gte => Date.parse(params[:from]))
        end

        if params[:to].present?
          notifications = notifications.where(:created_at.lte => Date.parse(params[:to]))
        end

        notifications
      end

      def notification_preferences_params
        params.require(:preferences).permit(
          :email_enabled,
          :push_enabled,
          :sms_enabled,
          :slack_enabled,
          :do_not_disturb,
          :do_not_disturb_start,
          :do_not_disturb_end,
          :quiet_hours_enabled,
          :quiet_hours_start,
          :quiet_hours_end,
          channels: [],
          blocked_types: [],
          priority_overrides: {}
        )
      end

      def default_preferences
        {
          email_enabled: true,
          push_enabled: true,
          sms_enabled: false,
          slack_enabled: false,
          do_not_disturb: false,
          channels: ['in_app', 'email'],
          blocked_types: [],
          priority_overrides: {}
        }
      end

      def serialization_params
        {
          include: params[:include],
          fields: params[:fields]
        }
      end
    end
  end
end