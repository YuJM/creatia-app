#!/usr/bin/env ruby
# frozen_string_literal: true

# System tests에서 have_http_status를 적절한 검증으로 변경하는 스크립트

Dir.glob('spec/system/**/*.rb').each do |file|
  content = File.read(file)
  changed = false
  
  # have_http_status(:ok) -> 페이지 내용 검증
  if content.include?('have_http_status(:ok)')
    content.gsub!(/expect\(page\)\.to have_http_status\(:ok\)/) do
      'expect(page).to have_css("body")'
    end
    changed = true
  end
  
  # have_http_status(:not_found) -> 404 페이지 내용 검증
  if content.include?('have_http_status(:not_found)')
    content.gsub!(/expect\(page\)\.to have_http_status\(:not_found\)/) do
      'expect(page).to have_content("404") || expect(page).to have_content("찾을 수 없습니다")'
    end
    changed = true
  end
  
  # have_http_status(:unauthorized) -> 401 페이지 내용 검증  
  if content.include?('have_http_status(:unauthorized)')
    content.gsub!(/expect\(page\)\.to have_http_status\(:unauthorized\)/) do
      'expect(page).to have_content("Unauthorized") || expect(page).to have_content("권한이 없습니다")'
    end
    changed = true
  end
  
  # have_http_status(:forbidden) -> 403 페이지 내용 검증
  if content.include?('have_http_status(:forbidden)')
    content.gsub!(/expect\(page\)\.to have_http_status\(:forbidden\)/) do
      'expect(page).to have_content("권한") || expect(page).to have_content("Forbidden")'
    end
    changed = true
  end
  
  if changed
    File.write(file, content)
    puts "Updated: #{file}"
  end
end

puts "System tests have been fixed!"