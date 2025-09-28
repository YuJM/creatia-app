# frozen_string_literal: true

require 'dry-validation'

module Contracts
  # Task 생성 검증 Contract
  class TaskCreateContract < Dry::Validation::Contract
    params do
      required(:title).filled(:string, min_size?: 1, max_size?: 200)
      optional(:description).maybe(:string, max_size?: 2000)
      required(:priority).filled(:string, included_in?: %w[low medium high urgent])
      optional(:due_date).maybe(:date)
      optional(:assignee_id).maybe(:string)
      optional(:sprint_id).maybe(:string)
      optional(:service_id).maybe(:string)
      optional(:estimated_hours).maybe(:float, gteq?: 0.0, lteq?: 999.0)
      optional(:tags).maybe(:array).each(:string)
      optional(:labels).maybe(:array).each(:string)
      optional(:epic_label_id).maybe(:string)
      optional(:create_github_issue).maybe(:bool)
    end

    rule(:due_date) do
      if value && value < Date.current
        key.failure('과거 날짜는 설정할 수 없습니다')
      end
    end

    rule(:estimated_hours) do
      if value && value <= 0
        key.failure('예상 시간은 0보다 커야 합니다')
      end
    end

    rule(:tags) do
      if value && value.size > 10
        key.failure('태그는 최대 10개까지 설정 가능합니다')
      end
    end

    rule(:sprint_id, :due_date) do
      if values[:sprint_id] && !values[:due_date]
        key(:due_date).failure('스프린트가 설정된 경우 마감일이 필요합니다')
      end
    end
  end
end