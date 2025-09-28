# frozen_string_literal: true

require 'dry-validation'

class SprintPlanningContract < ApplicationContract
  params do
    required(:start_date).filled(:date)
    required(:end_date).filled(:date)
    required(:tasks_count).filled(:integer)
    required(:team_size).filled(:integer)
  end
  
  rule(:end_date, :start_date) do
    if values[:end_date] && values[:start_date] && values[:end_date] <= values[:start_date]
      key(:end_date).failure('종료일은 시작일 이후여야 합니다')
    end
  end
  
  rule(:tasks_count) do
    if value == 0
      key.failure('스프린트에 최소 1개 이상의 태스크가 필요합니다')
    end
  end
  
  rule(:team_size) do
    if value == 0
      key.failure('스프린트에 최소 1명 이상의 팀원이 필요합니다')
    end
  end
end