# frozen_string_literal: true

require 'dry-schema'

module API
  module V1
    # API 파라미터 검증을 위한 스키마
    class TaskParamsSchema
      # Task 생성용 스키마
      CreateSchema = Dry::Schema.Params do
        required(:task).hash do
          required(:title).filled(:string, min_size?: 1, max_size?: 200)
          optional(:description).maybe(:string, max_size?: 2000)
          required(:priority).filled(:string, included_in?: %w[low medium high urgent])
          optional(:due_date).maybe(:date)
          optional(:assignee_id).maybe(:string)
          optional(:sprint_id).maybe(:string)
          optional(:estimated_hours).maybe(:float, gteq?: 0.0, lteq?: 999.0)
          optional(:tags).maybe(:array).each(:string)
          optional(:epic_label_id).maybe(:string)
        end
      end

      # Task 업데이트용 스키마
      UpdateSchema = Dry::Schema.Params do
        required(:task).hash do
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
          optional(:epic_label_id).maybe(:string)
          optional(:position).maybe(:integer, gt?: 0)
        end
      end

      # Task 목록 필터용 스키마
      IndexSchema = Dry::Schema.Params do
        optional(:status).maybe(:string, included_in?: %w[todo in_progress review done archived])
        optional(:priority).maybe(:string, included_in?: %w[low medium high urgent])
        optional(:assignee_id).maybe(:string)
        optional(:sprint_id).maybe(:string)
        optional(:epic_label_id).maybe(:string)
        optional(:unassigned).maybe(:bool)
        optional(:overdue).maybe(:bool)
        optional(:due_soon).maybe(:bool)
        optional(:tags).maybe(:array).each(:string)
        optional(:sort_by).maybe(:string, included_in?: %w[priority due_date created updated position])
        optional(:sort_direction).maybe(:string, included_in?: %w[asc desc])
        optional(:page).maybe(:integer, gt?: 0)
        optional(:per_page).maybe(:integer, gteq?: 1, lteq?: 100)
        optional(:search).maybe(:string, min_size?: 1, max_size?: 100)
      end

      # Task 벌크 액션용 스키마
      BulkActionSchema = Dry::Schema.Params do
        required(:task_ids).filled(:array, min_size?: 1).each(:string)
        required(:action).filled(:string, included_in?: %w[update_status assign move_to_sprint archive])
        
        # 액션별 파라미터
        case_sensitive false
        optional(:status).maybe(:string, included_in?: %w[todo in_progress review done archived])
        optional(:assignee_id).maybe(:string)
        optional(:sprint_id).maybe(:string)
      end

      # Task 이동/정렬용 스키마
      ReorderSchema = Dry::Schema.Params do
        required(:position).filled(:integer, gt?: 0)
        optional(:status).maybe(:string, included_in?: %w[todo in_progress review done archived])
        optional(:before_task_id).maybe(:string)
        optional(:after_task_id).maybe(:string)
      end

      # GitHub 동기화용 스키마
      GitHubSyncSchema = Dry::Schema.Params do
        optional(:create_issue).maybe(:bool)
        optional(:create_branch).maybe(:bool)
        optional(:branch_name_template).maybe(:string)
        optional(:issue_labels).maybe(:array).each(:string)
        optional(:milestone).maybe(:string)
      end

      # 시간 추적용 스키마
      TimeTrackingSchema = Dry::Schema.Params do
        required(:action).filled(:string, included_in?: %w[start stop log])
        optional(:hours).maybe(:float, gteq?: 0.0, lteq?: 24.0)
        optional(:description).maybe(:string, max_size?: 500)
        optional(:started_at).maybe(:date_time)
        optional(:ended_at).maybe(:date_time)
      end

      # 댓글/활동 로그용 스키마  
      ActivitySchema = Dry::Schema.Params do
        required(:type).filled(:string, included_in?: %w[comment status_change assignment priority_change])
        required(:content).filled(:string, min_size?: 1, max_size?: 1000)
        optional(:mentioned_user_ids).maybe(:array).each(:string)
        optional(:attachments).maybe(:array).each(:string)
      end

      class << self
        def validate_create(params)
          CreateSchema.call(params)
        end

        def validate_update(params)
          UpdateSchema.call(params)
        end

        def validate_index(params)
          IndexSchema.call(params)
        end

        def validate_bulk_action(params)
          BulkActionSchema.call(params)
        end

        def validate_reorder(params)
          ReorderSchema.call(params)
        end

        def validate_github_sync(params)
          GitHubSyncSchema.call(params)
        end

        def validate_time_tracking(params)
          TimeTrackingSchema.call(params)
        end

        def validate_activity(params)
          ActivitySchema.call(params)
        end
      end
    end
  end
end