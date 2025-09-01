module ApplicationHelper
  include TimeHelper
  include AppRoutes
  include IconHelper
  
  # 다른 공통 헬퍼 메서드들을 여기에 추가할 수 있습니다
  
  # 작업 상태 아이콘
  def task_status_icon(status)
    case status.to_s
    when 'completed'
      icon "check-circle", variant: "fill", class: "w-5 h-5 text-green-500"
    when 'in_progress'
      icon "circle-dashed", variant: "bold", class: "w-5 h-5 text-blue-500"
    when 'blocked'
      icon "warning-octagon", variant: "fill", class: "w-5 h-5 text-red-500"
    when 'waiting'
      icon "clock", class: "w-5 h-5 text-yellow-500"
    when 'todo'
      icon "circle", class: "w-5 h-5 text-gray-400"
    else
      icon "circle", class: "w-5 h-5 text-gray-300"
    end
  end
  
  # 우선순위 뱃지
  def priority_badge(priority)
    case priority.to_s
    when 'high'
      content_tag :div, class: "inline-flex items-center px-2 py-1 bg-red-100 text-red-800 rounded-full text-xs" do
        icon("flame", variant: "fill", class: "w-3 h-3 mr-1") + content_tag(:span, "높음")
      end
    when 'medium'
      content_tag :div, class: "inline-flex items-center px-2 py-1 bg-yellow-100 text-yellow-800 rounded-full text-xs" do
        icon("arrow-up", class: "w-3 h-3 mr-1") + content_tag(:span, "중간")
      end
    when 'low'
      content_tag :div, class: "inline-flex items-center px-2 py-1 bg-gray-100 text-gray-800 rounded-full text-xs" do
        icon("arrow-down", class: "w-3 h-3 mr-1") + content_tag(:span, "낮음")
      end
    else
      content_tag :div, class: "inline-flex items-center px-2 py-1 bg-gray-50 text-gray-600 rounded-full text-xs" do
        icon("minus", class: "w-3 h-3 mr-1") + content_tag(:span, "없음")
      end
    end
  end
  
  # 액션 아이콘
  def action_icon(action)
    case action.to_s
    when 'read', 'index', 'show'
      icon "eye", class: "w-4 h-4"
    when 'create', 'new'
      icon "plus", class: "w-4 h-4"
    when 'update', 'edit'
      icon "pencil", class: "w-4 h-4"
    when 'destroy', 'delete'
      icon "trash", class: "w-4 h-4"
    when 'manage'
      icon "crown", class: "w-4 h-4"
    else
      icon "question", class: "w-4 h-4"
    end
  end
  
  # 역할 아이콘
  def role_icon(role)
    case role.to_s
    when 'owner'
      icon "crown", variant: "fill", class: "w-4 h-4 text-purple-600"
    when 'admin'
      icon "shield-check", variant: "fill", class: "w-4 h-4 text-blue-600"
    when 'member'
      icon "user", class: "w-4 h-4 text-green-600"
    when 'viewer'
      icon "eye", class: "w-4 h-4 text-gray-600"
    else
      icon "user", class: "w-4 h-4 text-gray-400"
    end
  end
  
  # 알림 타입 아이콘
  def notification_icon(type)
    case type.to_s
    when 'success'
      icon "check-circle", variant: "fill", class: "w-5 h-5 text-green-500"
    when 'error'
      icon "x-circle", variant: "fill", class: "w-5 h-5 text-red-500"
    when 'warning'
      icon "warning-circle", variant: "fill", class: "w-5 h-5 text-yellow-500"
    when 'info'
      icon "info", variant: "fill", class: "w-5 h-5 text-blue-500"
    else
      icon "bell", class: "w-5 h-5 text-gray-500"
    end
  end
  
  def action_badge_color(action)
    case action
    when 'read', 'index', 'show'
      'bg-green-100 text-green-800'
    when 'create', 'new'
      'bg-blue-100 text-blue-800'
    when 'update', 'edit'
      'bg-yellow-100 text-yellow-800'
    when 'destroy', 'delete'
      'bg-red-100 text-red-800'
    when 'manage'
      'bg-purple-100 text-purple-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
end
