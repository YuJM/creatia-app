# frozen_string_literal: true

# SessionResponseSerializer - 세션 관련 응답 직렬화
class SessionResponseSerializer < BaseSerializer
  # 성공 플래그
  attribute :success do |data|
    data[:success] != false
  end
  
  # 에러 메시지
  attribute :error, if: proc { |data|
    data.is_a?(Hash) && data[:error]
  } do |data|
    data[:error]
  end
  
  # 메시지
  attribute :message, if: proc { |data|
    data.is_a?(Hash) && data[:message]
  } do |data|
    data[:message]
  end
  
  # 사용자 정보
  attribute :user, if: proc { |data|
    data.is_a?(Hash) && data[:user]
  } do |data|
    data[:user]
  end
  
  # 조직 목록
  attribute :organizations, if: proc { |data|
    data.is_a?(Hash) && data[:organizations]
  } do |data|
    data[:organizations]
  end
  
  # 돌아갈 조직
  attribute :return_organization, if: proc { |data|
    data.is_a?(Hash) && data[:return_organization]
  } do |data|
    data[:return_organization]
  end
  
  # 리다이렉트 URL
  attribute :redirect_url, if: proc { |data|
    data.is_a?(Hash) && data[:redirect_url]
  } do |data|
    data[:redirect_url]
  end
  
  # 조직 정보
  attribute :organization, if: proc { |data|
    data.is_a?(Hash) && data[:organization]
  } do |data|
    data[:organization]
  end
  
  # 접근 권한 정보
  attribute :access_denied_reason, if: proc { |data|
    data.is_a?(Hash) && data[:access_denied_reason]
  } do |data|
    data[:access_denied_reason]
  end
end