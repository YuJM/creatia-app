# app/models/concerns/dual_write.rb
module DualWrite
  extend ActiveSupport::Concern
  
  included do
    after_create :sync_to_mongodb
    after_update :sync_to_mongodb
    after_destroy :remove_from_mongodb
  end
  
  private
  
  def sync_to_mongodb
    return unless dual_write_enabled?
    
    # 비동기로 MongoDB 동기화
    MongoSyncJob.perform_later(
      model: self.class.name,
      action: 'sync',
      id: self.id,
      attributes: mongodb_attributes
    )
  rescue => e
    Rails.logger.error "DualWrite sync failed: #{e.message}"
    # 실패해도 PostgreSQL 작업은 계속 진행
  end
  
  def remove_from_mongodb
    return unless dual_write_enabled?
    
    MongoSyncJob.perform_later(
      model: self.class.name,
      action: 'remove',
      id: self.id
    )
  rescue => e
    Rails.logger.error "DualWrite removal failed: #{e.message}"
  end
  
  def dual_write_enabled?
    Rails.cache.read('mongodb:dual_write:enabled') == true
  end
  
  def mongodb_attributes
    # 서브클래스에서 오버라이드 가능
    attributes.except('created_at', 'updated_at')
  end
end