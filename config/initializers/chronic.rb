# config/initializers/chronic.rb
# Chronic gem 설정 - 자연어 시간 파싱

Chronic.time_class = Time.zone

# 한국어 패턴 지원을 위한 커스텀 파서
module ChronicKorean
  KOREAN_PATTERNS = {
    # 상대 시간
    '지금' => 'now',
    '오늘' => 'today',
    '내일' => 'tomorrow',
    '모레' => '2 days from now',
    '어제' => 'yesterday',
    '그저께' => '2 days ago',
    
    # 시간 단위
    '분 후' => 'minutes from now',
    '분 전' => 'minutes ago',
    '시간 후' => 'hours from now',
    '시간 전' => 'hours ago',
    '일 후' => 'days from now',
    '일 전' => 'days ago',
    '주 후' => 'weeks from now',
    '주 전' => 'weeks ago',
    '개월 후' => 'months from now',
    '개월 전' => 'months ago',
    
    # 요일
    '월요일' => 'monday',
    '화요일' => 'tuesday',
    '수요일' => 'wednesday',
    '목요일' => 'thursday',
    '금요일' => 'friday',
    '토요일' => 'saturday',
    '일요일' => 'sunday',
    
    # 시간대
    '오전' => 'am',
    '오후' => 'pm',
    '아침' => 'morning',
    '점심' => 'noon',
    '저녁' => 'evening',
    '밤' => 'night',
    
    # 특별한 시간
    '정오' => 'noon',
    '자정' => 'midnight',
    '새벽' => '4am',
    
    # 다음/이번
    '다음' => 'next',
    '이번' => 'this',
    '지난' => 'last',
    '다음주' => 'next week',
    '이번주' => 'this week',
    '지난주' => 'last week',
    '다음달' => 'next month',
    '이번달' => 'this month',
    '지난달' => 'last month'
  }.freeze
  
  def self.parse(text)
    # 한국어 패턴을 영어로 변환
    parsed_text = text.dup
    
    # 숫자 + 단위 패턴 처리 (예: "3일 후", "2시간 전")
    parsed_text.gsub!(/(\d+)(분|시간|일|주|개월)\s*(후|전)/) do |match|
      number = $1
      unit = case $2
             when '분' then 'minutes'
             when '시간' then 'hours'
             when '일' then 'days'
             when '주' then 'weeks'
             when '개월' then 'months'
             end
      direction = $3 == '후' ? 'from now' : 'ago'
      "#{number} #{unit} #{direction}"
    end
    
    # 시간 패턴 처리 (예: "오후 3시", "오전 10시 30분")
    parsed_text.gsub!(/(\오전|\오후)\s*(\d{1,2})시\s*(\d{1,2})?분?/) do |match|
      period = $1 == '오후' ? 'pm' : 'am'
      hour = $2
      minute = $3 || '00'
      "#{hour}:#{minute}#{period}"
    end
    
    # 일반 패턴 변환
    KOREAN_PATTERNS.each do |korean, english|
      parsed_text.gsub!(korean, english)
    end
    
    # Chronic으로 파싱
    Chronic.parse(parsed_text)
  end
end