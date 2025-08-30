module ApplicationHelper
  include TimeHelper
  
  # 다른 공통 헬퍼 메서드들을 여기에 추가할 수 있습니다
  
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
