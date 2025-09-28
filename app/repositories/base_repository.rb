# frozen_string_literal: true

require 'dry-monads'

# Repository 베이스 클래스
class BaseRepository
  include Dry::Monads[:result, :maybe, :try]

  # MongoDB와 ActiveRecord 모두 지원하는 추상화 레이어
  def find(id)
    return Failure([:invalid_id, "ID cannot be blank"]) if id.blank?
    
    Try do
      model_class.find(id)
    end.to_result
  rescue Mongoid::Errors::DocumentNotFound, ActiveRecord::RecordNotFound
    Failure(:not_found)
  rescue Mongoid::Errors::InvalidFind, BSON::ObjectId::Invalid, ArgumentError => e
    Failure([:invalid_id, "Invalid ID format: #{e.message}"])
  rescue StandardError => e
    Rails.logger.error "[#{self.class.name}] Find error: #{e.message}"
    Failure([:database_error, e.message])
  end

  def all(filters = {})
    Try do
      apply_filters(model_class.all, filters)
    end.to_result
  rescue StandardError => e
    Rails.logger.error "[#{self.class.name}] Query error: #{e.message}"
    Failure([:database_error, e.message])
  end

  def create(attributes)
    return Failure([:invalid_attributes, "Attributes cannot be nil"]) if attributes.nil?
    
    Try do
      # 중복 생성 방지를 위한 트랜잭션
      if model_class.respond_to?(:transaction)
        model_class.transaction do
          record = model_class.new(attributes)
          record.save!
          record
        end
      else
        record = model_class.new(attributes)
        record.save!
        record
      end
    end.to_result
  rescue Mongoid::Errors::Validations, ActiveRecord::RecordInvalid => e
    Rails.logger.warn "[#{self.class.name}] Validation error: #{e.record.errors.full_messages.join(', ')}"
    Failure([:validation_error, e.record.errors.to_h])
  rescue Mongoid::Errors::DocumentNotUnique, ActiveRecord::RecordNotUnique => e
    Rails.logger.warn "[#{self.class.name}] Duplicate record: #{e.message}"
    Failure([:duplicate_error, "Record already exists"])
  rescue StandardError => e
    Rails.logger.error "[#{self.class.name}] Create error: #{e.message}"
    Failure([:database_error, e.message])
  end

  def update(id, attributes)
    return Failure([:invalid_attributes, "Attributes cannot be nil"]) if attributes.nil?
    return Failure([:invalid_id, "ID cannot be blank"]) if id.blank?
    
    find(id).bind do |record|
      Try do
        # 동시성 제어를 위한 optimistic locking 지원
        if record.respond_to?(:updated_at) && attributes[:updated_at]
          if record.updated_at > attributes[:updated_at]
            return Failure([:stale_object_error, "Record was modified by another process"])
          end
          attributes = attributes.except(:updated_at)
        end
        
        record.update!(attributes)
        record
      end.to_result
    end
  rescue Mongoid::Errors::Validations, ActiveRecord::RecordInvalid => e
    Rails.logger.warn "[#{self.class.name}] Update validation error: #{e.record.errors.full_messages.join(', ')}"
    Failure([:validation_error, e.record.errors.to_h])
  rescue StandardError => e
    Rails.logger.error "[#{self.class.name}] Update error: #{e.message}"
    Failure([:database_error, e.message])
  end

  def delete(id)
    return Failure([:invalid_id, "ID cannot be blank"]) if id.blank?
    
    find(id).bind do |record|
      Try do
        if record.respond_to?(:archive!) && !force_delete?
          # 소프트 삭제 우선 사용
          record.archive!
        else
          record.destroy!
        end
        true
      end.to_result
    end
  rescue StandardError => e
    Rails.logger.error "[#{self.class.name}] Delete error: #{e.message}"
    Failure([:database_error, e.message])
  end

  def count(filters = {})
    Try do
      apply_filters(model_class.all, filters).count
    end.to_result
  rescue StandardError => e
    Rails.logger.error "[#{self.class.name}] Count error: #{e.message}"
    Failure([:database_error, e.message])
  end

  def exists?(filters = {})
    Try do
      apply_filters(model_class.all, filters).exists?
    end.to_result
  rescue StandardError => e
    Rails.logger.error "[#{self.class.name}] Exists error: #{e.message}"
    Failure([:database_error, e.message])
  end

  # Kaminari를 사용한 페이지네이션
  def paginate(query, options = {})
    page = (options[:page] || 1).to_i
    per_page = [(options[:per_page] || 20).to_i, 100].min # 최대 100개로 제한
    
    # Kaminari 사용 (MongoDB와 ActiveRecord 모두 지원)
    paginated = query.page(page).per(per_page)
    
    if options[:include_total]
      {
        data: paginated.to_a,
        metadata: {
          page: paginated.current_page,
          per_page: paginated.limit_value,
          total_count: paginated.total_count,
          total_pages: paginated.total_pages
        }
      }
    else
      paginated
    end
  end

  protected

  def model_class
    raise NotImplementedError, "Subclasses must define model_class"
  end

  # 강제 삭제 여부 (기본값: false, 서브클래스에서 오버라이드 가능)
  def force_delete?
    false
  end

  def apply_filters(scope, filters)
    return scope if filters.blank?
    
    # SQL Injection 방지를 위한 허용된 필터 키만 처리
    allowed_filters = allowed_filter_keys
    
    filters.each do |key, value|
      next unless allowed_filters.include?(key.to_s) || allowed_filters.include?(key.to_sym)
      next if value.blank? && !value.is_a?(FalseClass) # false 값 허용
      
      scope = case value
              when Hash
                # MongoDB 스타일 쿼리 지원
                apply_complex_filter(scope, key, value)
              when Array
                # IN 절 쿼리
                scope.where(key => value)
              else
                scope.where(key => value)
              end
    end
    scope
  end

  # 서브클래스에서 오버라이드하여 허용된 필터 키 정의
  def allowed_filter_keys
    []
  end

  def apply_complex_filter(scope, key, conditions)
    conditions.each do |operator, value|
      scope = case operator.to_s
              when '$lt', 'lt'
                apply_comparison_filter(scope, key, :<, value)
              when '$lte', 'lte'
                apply_comparison_filter(scope, key, :<=, value)
              when '$gt', 'gt'
                apply_comparison_filter(scope, key, :>, value)
              when '$gte', 'gte'
                apply_comparison_filter(scope, key, :>=, value)
              when '$ne', 'ne'
                apply_not_equal_filter(scope, key, value)
              when '$in', 'in'
                scope.where(key => value)
              when '$regex', 'regex'
                apply_regex_filter(scope, key, value)
              else
                Rails.logger.warn "[#{self.class.name}] Unknown filter operator: #{operator}"
                scope
              end
    end
    scope
  end

  private

  def apply_comparison_filter(scope, key, operator, value)
    if scope.respond_to?(operator)
      # MongoDB 스타일
      scope.where(key.to_sym.send(operator) => value)
    else
      # ActiveRecord 스타일
      scope.where("#{sanitize_column_name(key)} #{comparison_sql_operator(operator)} ?", value)
    end
  end

  def apply_not_equal_filter(scope, key, value)
    if scope.respond_to?(:ne)
      scope.where(key.to_sym.ne => value)
    else
      scope.where.not(key => value)
    end
  end

  def apply_regex_filter(scope, key, pattern)
    if scope.respond_to?(:regex)
      scope.where(key.to_sym => /#{pattern}/i)
    else
      # PostgreSQL의 경우
      scope.where("#{sanitize_column_name(key)} ~* ?", pattern)
    end
  end

  def sanitize_column_name(column)
    # SQL Injection 방지를 위한 컬럼명 검증
    column.to_s.gsub(/[^a-zA-Z0-9_.]/, '')
  end

  def comparison_sql_operator(symbol)
    case symbol
    when :< then '<'
    when :<= then '<='
    when :> then '>'
    when :>= then '>='
    else '='
    end
  end
end