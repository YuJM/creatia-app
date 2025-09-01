# frozen_string_literal: true

module IconHelper
  # Phosphor 아이콘을 직접 로드하는 헬퍼
  def icon(name, options = {})
    # 기본 옵션 설정
    variant = options[:variant] || 'regular'
    css_class = options[:class] || 'inline-block flex-shrink-0 size-5'
    
    # SVG 파일 경로 생성
    svg_path = Rails.root.join('app', 'assets', 'svg', 'icons', 'phosphor', variant, "#{name}.svg")
    
    if File.exist?(svg_path)
      svg_content = File.read(svg_path)
      
      # 기존 SVG 속성 제거하고 새로운 클래스 추가
      svg_content = svg_content.gsub(/<svg[^>]*>/) do |match|
        # width와 height 속성 제거하고 class 추가
        match.sub(/width="[^"]*"/, '')
             .sub(/height="[^"]*"/, '')
             .sub(/class="[^"]*"/, '')
             .sub('<svg', "<svg class=\"#{css_class}\"")
      end
      
      svg_content.html_safe
    else
      # 아이콘을 찾을 수 없을 때 fallback
      content_tag(:span, "[#{name}]", class: css_class, title: "Icon not found: #{name}")
    end
  end
end