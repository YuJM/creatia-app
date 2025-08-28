# frozen_string_literal: true

require 'dry/validation'

class LabelValidator < Dry::Validation::Contract
  params do
    required(:name).filled(:string)
    required(:organization_id).filled(:integer)
    required(:label_type).filled(:string)
    optional(:color).maybe(:string)
    optional(:description).maybe(:string)
  end
  
  rule(:color) do
    if value && !value.match?(/\A#[0-9A-F]{6}\z/i)
      key.failure('must be a valid hex color code (e.g., #FF5733)')
    end
  end
  
  rule(:label_type) do
    valid_types = %w[epic category priority status custom]
    unless valid_types.include?(value)
      key.failure("must be one of: #{valid_types.join(', ')}")
    end
  end
  
  rule(:name, :organization_id) do
    if Label.exists?(name: values[:name], organization_id: values[:organization_id])
      key(:name).failure('has already been taken for this organization')
    end
  end
end

# 사용 예시:
# validator = LabelValidator.new
# result = validator.call(name: "Bug", organization_id: 1, label_type: "category")
# if result.success?
#   Label.create!(result.to_h)
# else
#   render json: { errors: result.errors.to_h }, status: :unprocessable_entity
# end