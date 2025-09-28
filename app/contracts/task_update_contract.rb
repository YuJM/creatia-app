# frozen_string_literal: true

require 'dry-validation'

module Contracts
  # Task 업데이트 검증 Contract
  class TaskUpdateContract < Dry::Validation::Contract
    params do
      optional(:title).filled(:string, min_size?: 1, max_size?: 200)
      optional(:description).maybe(:string, max_size?: 2000)
      optional(:status).filled(:string, included_in?: %w[todo in_progress review done archived])
      optional(:priority).filled(:string, included_in?: %w[low medium high urgent])
      optional(:due_date).maybe(:date)
      optional(:assignee_id).maybe(:string)
      optional(:sprint_id).maybe(:string)
      optional(:estimated_hours).maybe(:float, gteq?: 0.0, lteq?: 999.0)
      optional(:actual_hours).maybe(:float, gteq?: 0.0, lteq?: 999.0)
      optional(:completion_percentage).maybe(:integer, gteq?: 0, lteq?: 100)
      optional(:tags).maybe(:array).each(:string)
      optional(:labels).maybe(:array).each(:string)
      optional(:epic_label_id).maybe(:string)
      optional(:position).maybe(:integer, gt?: 0)
    end

    rule(:estimated_hours) do
      if value && value <= 0
        key.failure('예상 시간은 0보다 커야 합니다')
      end
    end

    rule(:actual_hours) do
      if value && value < 0
        key.failure('실제 시간은 0 이상이어야 합니다')
      end
    end

    rule(:actual_hours, :estimated_hours) do
      if values[:actual_hours] && values[:estimated_hours]
        if values[:actual_hours] > values[:estimated_hours] * 3
          key(:actual_hours).failure('실제 시간이 예상 시간의 3배를 초과합니다. 확인이 필요합니다.')
        end
      end
    end

    rule(:completion_percentage, :status) do
      if values[:completion_percentage] == 100 && values[:status] && values[:status] != 'done'
        key(:status).failure('완료율이 100%인 경우 상태는 done이어야 합니다')
      end
    end

    rule(:tags) do
      if value && value.size > 10
        key.failure('태그는 최대 10개까지 설정 가능합니다')
      end
    end
  end
end