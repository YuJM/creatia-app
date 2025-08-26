class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  
  # UUID 생성을 위한 concern
  self.implicit_order_column = "created_at"
  
  # 모든 모델에서 UUID를 primary key로 사용
  self.abstract_class = true
end
