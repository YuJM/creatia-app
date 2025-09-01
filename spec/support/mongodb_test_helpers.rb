# MongoDB Test Helpers
module MongodbTestHelpers
  extend ActiveSupport::Concern
  
  included do
    # MongoDB 테스트 데이터베이스 정리
    def clean_mongodb
      Mongoid.default_client.database.collections.each do |collection|
        next if collection.name.start_with?('system.')
        collection.drop
      end
    end
    
    # MongoDB 연결 설정 확인
    def mongodb_connected?
      Mongoid.default_client.database.command(ping: 1)
      true
    rescue => e
      Rails.logger.warn "MongoDB connection failed: #{e.message}"
      false
    end
    
    # MongoDB 컬렉션 존재 확인
    def collection_exists?(collection_name)
      Mongoid.default_client.database.collection_names.include?(collection_name)
    end
    
    # MongoDB 문서 개수 확인
    def document_count(model_class)
      model_class.count
    rescue => e
      Rails.logger.warn "Failed to count documents for #{model_class}: #{e.message}"
      0
    end
  end
end

# MongoDB 스코프 매칭 헬퍼
module MongodbScopeMatchers
  # MongoDB에서 current 스코프는 날짜 범위 쿼리로 구현
  def be_current_sprint
    satisfy do |sprint|
      today = Date.current
      sprint.start_date <= today && sprint.end_date >= today && sprint.status == 'active'
    end
  end
  
  # MongoDB에서 past 스코프는 상태 기반 쿼리로 구현
  def be_past_sprint
    satisfy { |sprint| sprint.status == 'completed' }
  end
  
  # MongoDB에서 upcoming 스코프는 상태와 날짜 조건으로 구현
  def be_upcoming_sprint
    satisfy do |sprint|
      sprint.status == 'planning' && sprint.start_date > Date.current
    end
  end
  
  # MongoDB에서 overdue 태스크 확인
  def be_overdue_task
    satisfy do |task|
      task.due_date.present? && 
      task.due_date < Date.current && 
      task.status != 'done'
    end
  end
  
  # MongoDB에서 today 세션 확인
  def be_today_session
    satisfy do |session|
      session.started_at >= Time.current.beginning_of_day &&
      session.started_at <= Time.current.end_of_day
    end
  end
end

RSpec.configure do |config|
  config.include MongodbTestHelpers
  config.include MongodbScopeMatchers
  
  # MongoDB 테스트 전후 정리
  config.before(:suite) do
    if defined?(Mongoid)
      # 테스트 시작 전 MongoDB 정리
      Mongoid.default_client.database.collections.each do |collection|
        next if collection.name.start_with?('system.')
        collection.drop
      end
    end
  end
  
  config.after(:each) do
    if defined?(Mongoid) && example.metadata[:type] == :model
      # 각 테스트 후 MongoDB 정리 (모델 테스트만)
      [
        Mongodb::MongoTask,
        Mongodb::MongoSprint, 
        Mongodb::MongoPomodoroSession
      ].each do |model_class|
        model_class.delete_all rescue nil
      end
    end
  end
end