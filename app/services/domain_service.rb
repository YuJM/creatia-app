# frozen_string_literal: true

# DomainService - 도메인 관련 유틸리티 서비스
# 환경변수를 기반으로 동적 도메인 설정을 제공합니다.
class DomainService
  class << self
    prepend MemoWise
    
    # 기본 도메인 반환 (환경변수에서 가져옴) - 메모이제이션 적용
    memo_wise def base_domain
      ENV.fetch('BASE_DOMAIN', default_domain)
    end
    
    # HTTPS 사용 여부 - 메모이제이션 적용
    memo_wise def use_https?
      Rails.env.production? || ENV['USE_HTTPS'] == 'true'
    end
    
    # 프로토콜 반환 - 메모이제이션 적용
    memo_wise def protocol
      use_https? ? 'https' : 'http'
    end
    
    # 메인 도메인 URL 생성
    def main_url(path = nil)
      url = "#{protocol}://#{base_domain}"
      url += ":#{port}" if include_port?
      url += "/#{path}" if path.present?
      url
    end
    
    # 서브도메인 URL 생성
    def subdomain_url(subdomain, path = nil)
      url = "#{protocol}://#{subdomain}.#{base_domain}"
      url += ":#{port}" if include_port?
      url += "/#{path}" if path.present?
      url
    end
    
    # 인증 도메인 URL
    def auth_url(path = nil)
      subdomain_url('auth', path)
    end
    
    # API 도메인 URL
    def api_url(path = nil)
      subdomain_url('api', path)
    end
    
    # 관리자 도메인 URL
    def admin_url(path = nil)
      subdomain_url('admin', path)
    end
    
    # 조직 도메인 URL
    def organization_url(subdomain, path = nil)
      subdomain_url(subdomain, path)
    end
    
    # 로그인 URL (조직 컨텍스트 고려)
    def login_url(return_to_subdomain = nil)
      path = 'login'
      path += "?return_to=#{return_to_subdomain}" if return_to_subdomain.present?
      auth_url(path)
    end
    
    # 로그아웃 URL
    def logout_url
      auth_url('logout')
    end
    
    # 현재 요청이 특정 서브도메인인지 확인
    def subdomain_matches?(request, subdomain)
      extract_subdomain(request) == subdomain
    end
    
    # 현재 요청이 메인 도메인인지 확인
    def main_domain?(request)
      subdomain = extract_subdomain(request)
      subdomain.blank? || subdomain == 'www'
    end
    
    # 현재 요청이 인증 도메인인지 확인
    def auth_domain?(request)
      subdomain_matches?(request, 'auth')
    end
    
    # 현재 요청이 API 도메인인지 확인
    def api_domain?(request)
      subdomain_matches?(request, 'api')
    end
    
    # 현재 요청이 관리자 도메인인지 확인
    def admin_domain?(request)
      subdomain_matches?(request, 'admin')
    end
    
    # 현재 요청이 조직 도메인인지 확인
    def organization_domain?(request)
      subdomain = extract_subdomain(request)
      return false if subdomain.blank?
      return false if reserved_subdomain?(subdomain)
      
      # 조직이 실제로 존재하는지 확인
      Organization.exists?(subdomain: subdomain)
    end
    
    # 서브도메인 추출
    def extract_subdomain(request)
      if Rails.env.development?
        # 개발환경에서는 localhost:3000 형태이므로 HOST 헤더에서 추출
        host = request.host
        return nil if host == 'localhost' || host.match?(/^\d+\.\d+\.\d+\.\d+$/)
        
        # 메인 도메인 자체인 경우 nil 반환 (서브도메인 없음)
        return nil if host == base_domain
        
        # {subdomain}.base_domain 형태에서 subdomain 추출
        if host.end_with?(".#{base_domain}")
          host.sub(".#{base_domain}", '')
        else
          # 예상하지 못한 호스트인 경우 nil 반환
          nil
        end
      else
        request.subdomain
      end
    end
    
    # 예약된 서브도메인 목록
    def reserved_subdomains
      %w[www auth api admin mail ftp app blog docs help support status]
    end
    
    # 예약된 서브도메인인지 확인
    def reserved_subdomain?(subdomain)
      reserved_subdomains.include?(subdomain.to_s.downcase)
    end
    
    # 개발환경 호스트 설정 도움말
    def development_hosts_info
      return unless Rails.env.development?
      
      puts "\n" + "="*80
      puts "🏗️  멀티테넌트 개발환경 설정"
      puts "="*80
      puts ""
      puts "다음 도메인들을 /etc/hosts 파일에 추가해주세요:"
      puts ""
      puts "127.0.0.1 #{base_domain}"
      puts "127.0.0.1 auth.#{base_domain}"
      puts "127.0.0.1 api.#{base_domain}"
      puts "127.0.0.1 admin.#{base_domain}"
      puts "127.0.0.1 demo.#{base_domain}"
      puts "127.0.0.1 test.#{base_domain}"
      puts ""
      puts "추가 방법:"
      puts "sudo vim /etc/hosts"
      puts ""
      puts "그 후 다음 URL들로 접근하실 수 있습니다:"
      puts "- 메인: #{main_url}"
      puts "- 인증: #{auth_url}"
      puts "- API: #{api_url}"
      puts "- 관리자: #{admin_url}"
      puts "- 데모 조직: #{organization_url('demo')}"
      puts ""
      puts "="*80
      puts ""
    end
    
    private
    
    def default_domain
      Rails.env.production? ? 'creatia.io' : 'localhost'
    end
    
    def port
      @port ||= Rails.env.development? ? ':3000' : nil
    end
    
    def include_port?
      Rails.env.development? && !base_domain.include?(':')
    end
  end
end
