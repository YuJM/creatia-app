class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    if current_user
      stream_for current_user
      stream_from "user_#{current_user.id}"
      
      # 구독 성공 메시지
      ActionCable.server.broadcast(
        "user_#{current_user.id}",
        {
          type: "subscription_confirmed",
          message: "알림 채널에 연결되었습니다.",
          user_id: current_user.id
        }
      )
    else
      reject
    end
  end

  def unsubscribed
    # 정리 작업
    stop_all_streams
  end
  
  # 클라이언트에서 알림을 읽음으로 표시
  def mark_as_read(data)
    notification = current_user.notifications.find(data['notification_id'])
    notification.mark_as_read!
    
    transmit(
      type: "notification_read",
      notification_id: notification.id,
      success: true
    )
  rescue ActiveRecord::RecordNotFound
    transmit(
      type: "error",
      message: "알림을 찾을 수 없습니다."
    )
  end
  
  # 모든 알림을 읽음으로 표시
  def mark_all_as_read
    current_user.notifications.unread.update_all(read_at: Time.current)
    
    transmit(
      type: "all_notifications_read",
      success: true,
      timestamp: Time.current
    )
  end
end
