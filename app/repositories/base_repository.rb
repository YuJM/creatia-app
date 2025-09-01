# frozen_string_literal: true

require 'dry-monads'

# Repository 베이스 클래스
class BaseRepository
  include Dry::Monads[:result, :maybe]

  # MongoDB와 ActiveRecord 모두 지원하는 추상화 레이어
  def find(id)
    Try do
      model_class.find(id)
    end.to_result
  rescue Mongoid::Errors::DocumentNotFound, ActiveRecord::RecordNotFound => e
    Failure([:not_found, e.message])
  rescue StandardError => e
    Failure([:database_error, e.message])
  end

  def all(filters = {})
    Try do
      apply_filters(model_class.all, filters)
    end.to_result
  rescue StandardError => e
    Failure([:database_error, e.message])
  end

  def create(attributes)
    Try do
      record = model_class.new(attributes)
      record.save!
      record
    end.to_result
  rescue Mongoid::Errors::Validations, ActiveRecord::RecordInvalid => e
    Failure([:validation_error, e.record.errors.to_h])
  rescue StandardError => e
    Failure([:database_error, e.message])
  end

  def update(id, attributes)
    find(id).bind do |record|
      Try do
        record.update!(attributes)
        record
      end.to_result
    end
  rescue Mongoid::Errors::Validations, ActiveRecord::RecordInvalid => e
    Failure([:validation_error, e.record.errors.to_h])
  rescue StandardError => e
    Failure([:database_error, e.message])
  end

  def delete(id)
    find(id).bind do |record|
      Try do
        record.destroy!
        true
      end.to_result
    end
  rescue StandardError => e
    Failure([:database_error, e.message])
  end

  def count(filters = {})
    Try do
      apply_filters(model_class.all, filters).count
    end.to_result
  rescue StandardError => e
    Failure([:database_error, e.message])
  end

  def exists?(filters = {})
    Try do
      apply_filters(model_class.all, filters).exists?
    end.to_result
  rescue StandardError => e
    Failure([:database_error, e.message])
  end

  protected

  def model_class
    raise NotImplementedError, "Subclasses must define model_class"
  end

  def apply_filters(scope, filters)
    filters.each do |key, value|
      scope = case value
              when Hash
                # MongoDB 스타일 쿼리 지원
                apply_complex_filter(scope, key, value)
              when Array
                scope.where(key => value)
              else
                scope.where(key => value)
              end
    end
    scope
  end

  def apply_complex_filter(scope, key, conditions)
    conditions.each do |operator, value|
      scope = case operator.to_s
              when '$lt', 'lt'
                if scope.respond_to?(:lt)
                  scope.where(key.to_sym.lt => value)
                else
                  scope.where("#{key} < ?", value)
                end
              when '$lte', 'lte'
                if scope.respond_to?(:lte)
                  scope.where(key.to_sym.lte => value)
                else
                  scope.where("#{key} <= ?", value)
                end
              when '$gt', 'gt'
                if scope.respond_to?(:gt)
                  scope.where(key.to_sym.gt => value)
                else
                  scope.where("#{key} > ?", value)
                end
              when '$gte', 'gte'
                if scope.respond_to?(:gte)
                  scope.where(key.to_sym.gte => value)
                else
                  scope.where("#{key} >= ?", value)
                end
              when '$ne', 'ne'
                if scope.respond_to?(:ne)
                  scope.where(key.to_sym.ne => value)
                else
                  scope.where.not(key => value)
                end
              when '$in', 'in'
                if scope.respond_to?(:in)
                  scope.where(key.to_sym.in => value)
                else
                  scope.where(key => value)
                end
              else
                scope
              end
    end
    scope
  end
end