# frozen_string_literal: true

# MongoDB 기반 알림 발송 및 관리 서비스
class NotificationService
  class << self
    # Task 관련 알림
    def task_assigned(task, assignee, assigner)
      Notification.notify(
        assignee,
        'TaskAssignedNotification',
        sender_id: assigner.id,
        sender_name: assigner.name,
        title: "새로운 작업이 할당되었습니다",
        body: "#{assigner.name}님이 '#{task.title}' 작업을 할당했습니다.",
        category: 'task',
        priority: task.priority == 'urgent' ? 'high' : 'normal',
        action_url: "/tasks/#{task.id}",
        action_text: "작업 보기",
        icon: "📋",
        related_type: 'Task',
        related_id: task.id,
        related_data: {
          task_id: task.id,
          task_title: task.title,
          task_priority: task.priority,
          due_date: task.due_date
        },
        channels: ['in_app', 'email', 'push']
      )
    end

    def task_completed(task, completer)
      # 작업 생성자와 관련 팀원들에게 알림
      recipients = [task.creator]
      recipients += task.watchers if task.respond_to?(:watchers)
      recipients.uniq!

      Notification.notify_all(
        recipients,
        'TaskCompletedNotification',
        sender_id: completer.id,
        sender_name: completer.name,
        title: "작업이 완료되었습니다",
        body: "#{completer.name}님이 '#{task.title}' 작업을 완료했습니다.",
        category: 'task',
        priority: 'normal',
        action_url: "/tasks/#{task.id}",
        icon: "✅",
        related_type: 'Task',
        related_id: task.id,
        channels: ['in_app']
      )
    end

    def task_due_soon(task)
      return unless task.assignee

      Notification.notify(
        task.assignee,
        'TaskDueSoonNotification',
        title: "작업 마감일이 다가옵니다",
        body: "'#{task.title}' 작업이 #{task.due_date.strftime('%m월 %d일')}에 마감됩니다.",
        category: 'task',
        priority: 'high',
        action_url: "/tasks/#{task.id}",
        action_text: "작업 확인",
        icon: "⏰",
        related_type: 'Task',
        related_id: task.id,
        channels: ['in_app', 'email', 'push']
      )
    end

    def task_overdue(task)
      return unless task.assignee

      Notification.notify(
        task.assignee,
        'TaskOverdueNotification',
        title: "작업이 지연되고 있습니다",
        body: "'#{task.title}' 작업이 마감일을 넘겼습니다.",
        category: 'task',
        priority: 'urgent',
        action_url: "/tasks/#{task.id}",
        action_text: "즉시 확인",
        icon: "🚨",
        related_type: 'Task',
        related_id: task.id,
        channels: ['in_app', 'email', 'push']
      )
    end

    # Comment 관련 알림
    def comment_mention(comment, mentioned_user)
      Notification.notify(
        mentioned_user,
        'CommentMentionNotification',
        sender_id: comment.user_id,
        sender_name: comment.user.name,
        title: "댓글에서 언급되었습니다",
        body: "#{comment.user.name}님이 댓글에서 회원님을 언급했습니다: #{comment.body.truncate(100)}",
        category: 'mention',
        priority: 'normal',
        action_url: "/tasks/#{comment.task_id}#comment-#{comment.id}",
        action_text: "댓글 보기",
        icon: "💬",
        related_type: 'Comment',
        related_id: comment.id,
        channels: ['in_app', 'email', 'push']
      )
    end

    def comment_reply(original_comment, reply)
      return if original_comment.user_id == reply.user_id

      Notification.notify(
        original_comment.user,
        'CommentReplyNotification',
        sender_id: reply.user_id,
        sender_name: reply.user.name,
        title: "댓글에 답글이 달렸습니다",
        body: "#{reply.user.name}님이 답글을 남겼습니다: #{reply.body.truncate(100)}",
        category: 'comment',
        priority: 'normal',
        action_url: "/tasks/#{reply.task_id}#comment-#{reply.id}",
        icon: "💭",
        related_type: 'Comment',
        related_id: reply.id,
        parent_id: original_comment.id,
        channels: ['in_app', 'email']
      )
    end

    # Sprint 관련 알림
    def sprint_started(sprint)
      recipients = sprint.team.members

      Notification.notify_all(
        recipients,
        'SprintStartedNotification',
        title: "스프린트가 시작되었습니다",
        body: "#{sprint.name} 스프린트가 시작되었습니다. 목표 달성을 위해 함께 노력해요!",
        category: 'sprint',
        priority: 'normal',
        action_url: "/sprints/#{sprint.id}",
        action_text: "스프린트 보기",
        icon: "🏃",
        related_type: 'Sprint',
        related_id: sprint.id,
        channels: ['in_app', 'email']
      )
    end

    def sprint_ending_soon(sprint)
      recipients = sprint.team.members

      Notification.notify_all(
        recipients,
        'SprintEndingSoonNotification',
        title: "스프린트 종료가 다가옵니다",
        body: "#{sprint.name} 스프린트가 #{sprint.end_date.strftime('%m월 %d일')}에 종료됩니다.",
        category: 'sprint',
        priority: 'high',
        action_url: "/sprints/#{sprint.id}",
        icon: "⏳",
        related_type: 'Sprint',
        related_id: sprint.id,
        channels: ['in_app', 'push']
      )
    end

    def sprint_completed(sprint, stats = {})
      recipients = sprint.team.members

      Notification.notify_all(
        recipients,
        'SprintCompletedNotification',
        title: "스프린트가 완료되었습니다",
        body: "#{sprint.name} 스프린트가 완료되었습니다. 완료율: #{stats[:completion_rate]}%",
        category: 'sprint',
        priority: 'normal',
        action_url: "/sprints/#{sprint.id}/retrospective",
        action_text: "회고 보기",
        icon: "🎉",
        related_type: 'Sprint',
        related_id: sprint.id,
        metadata: stats,
        channels: ['in_app', 'email']
      )
    end

    # Team 관련 알림
    def team_invitation(team, invitee, inviter)
      Notification.notify(
        invitee,
        'TeamInvitationNotification',
        sender_id: inviter.id,
        sender_name: inviter.name,
        title: "팀 초대를 받았습니다",
        body: "#{inviter.name}님이 '#{team.name}' 팀에 초대했습니다.",
        category: 'team',
        priority: 'normal',
        action_url: "/teams/#{team.id}/invitation",
        action_text: "초대 확인",
        icon: "👥",
        related_type: 'Team',
        related_id: team.id,
        channels: ['in_app', 'email']
      )
    end

    def team_member_joined(team, new_member)
      recipients = team.members.where.not(id: new_member.id)

      Notification.notify_all(
        recipients,
        'TeamMemberJoinedNotification',
        title: "새로운 팀원이 합류했습니다",
        body: "#{new_member.name}님이 #{team.name} 팀에 합류했습니다.",
        category: 'team',
        priority: 'low',
        action_url: "/teams/#{team.id}/members",
        icon: "🤝",
        related_type: 'Team',
        related_id: team.id,
        channels: ['in_app']
      )
    end

    # System 관련 알림
    def system_announcement(title, body, recipients = nil, priority = 'normal')
      recipients ||= User.all

      Notification.notify_all(
        recipients,
        'SystemAnnouncementNotification',
        title: title,
        body: body,
        category: 'announcement',
        priority: priority,
        icon: "📢",
        channels: ['in_app', 'email']
      )
    end

    def system_maintenance(start_time, end_time, affected_users = nil)
      affected_users ||= User.all

      Notification.schedule(
        affected_users,
        'SystemMaintenanceNotification',
        start_time - 1.hour,
        title: "시스템 점검 예정",
        body: "#{start_time.strftime('%m월 %d일 %H시')}부터 #{end_time.strftime('%H시')}까지 시스템 점검이 예정되어 있습니다.",
        category: 'system',
        priority: 'high',
        icon: "🔧",
        channels: ['in_app', 'email', 'push'],
        expires_at: end_time
      )
    end

    # Pomodoro 관련 알림
    def pomodoro_session_complete(session)
      Notification.notify(
        session.user,
        'PomodoroSessionCompleteNotification',
        title: "포모도로 세션 완료!",
        body: "25분 집중 세션을 완료했습니다. 5분간 휴식하세요.",
        category: 'system',
        priority: 'low',
        icon: "🍅",
        related_type: 'PomodoroSessionMongo',
        related_id: session.id,
        channels: ['in_app', 'push']
      )
    end

    def pomodoro_break_over(session)
      Notification.notify(
        session.user,
        'PomodoroBreakOverNotification',
        title: "휴식 시간 종료",
        body: "휴식이 끝났습니다. 다음 세션을 시작할 준비가 되셨나요?",
        category: 'system',
        priority: 'low',
        action_url: "/pomodoro",
        action_text: "세션 시작",
        icon: "⏰",
        channels: ['in_app', 'push']
      )
    end

    # 알림 설정 관련
    def update_user_preferences(user, preferences)
      # 사용자 알림 설정 업데이트
      user.update!(notification_preferences: preferences)
      
      # 설정 변경 확인 알림
      Notification.notify(
        user,
        'PreferencesUpdatedNotification',
        title: "알림 설정이 변경되었습니다",
        body: "알림 설정이 성공적으로 업데이트되었습니다.",
        category: 'system',
        priority: 'low',
        icon: "⚙️",
        channels: ['in_app']
      )
    end

    # 일괄 작업
    def mark_all_as_read(user)
      Notification.for_recipient(user.id)
                 .unread
                 .update_all(
                   read_at: Time.current,
                   status: 'read'
                 )
    end

    def archive_old_notifications(user, days_old = 30)
      cutoff_date = days_old.days.ago
      
      Notification.for_recipient(user.id)
                 .where(:created_at.lt => cutoff_date)
                 .update_all(
                   archived_at: Time.current,
                   status: 'archived'
                 )
    end

    def delete_dismissed_notifications(user)
      Notification.for_recipient(user.id)
                 .where(dismissed: true)
                 .destroy_all
    end

    # 통계 및 분석
    def user_notification_stats(user, period = :week)
      range = case period
              when :day then 1.day.ago..Time.current
              when :week then 1.week.ago..Time.current
              when :month then 1.month.ago..Time.current
              else 1.week.ago..Time.current
              end

      notifications = Notification.for_recipient(user.id)
                                 .where(:created_at.in => range)

      {
        total: notifications.count,
        unread: notifications.unread.count,
        by_category: notifications.group_by(&:category).transform_values(&:count),
        by_priority: notifications.group_by(&:priority).transform_values(&:count),
        interaction_rate: calculate_interaction_rate(notifications),
        peak_hours: calculate_peak_hours(notifications)
      }
    end

    private

    def calculate_interaction_rate(notifications)
      return 0 if notifications.empty?
      
      interacted = notifications.select { |n| n.click_count > 0 }
      (interacted.count.to_f / notifications.count * 100).round(1)
    end

    def calculate_peak_hours(notifications)
      notifications.group_by { |n| n.created_at.hour }
                  .transform_values(&:count)
                  .sort_by { |_, count| -count }
                  .first(3)
                  .to_h
    end
  end
end