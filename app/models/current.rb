# frozen_string_literal: true

# Current - 현재 요청 컨텍스트를 관리하는 클래스
# ActiveSupport::CurrentAttributes를 사용하여 요청별 정보 저장
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :organization

  # 현재 사용자의 이름을 안전하게 반환
  def self.user_name
    user&.name || 'System'
  end

  # 현재 조직의 이름을 안전하게 반환  
  def self.organization_name
    organization&.name || 'Unknown'
  end
end