# frozen_string_literal: true

module Tasks
  class TaskFormComponent < ViewComponent::Base
    include Turbo::FramesHelper
    include Turbo::StreamsHelper

    def initialize(task_dto:, available_sprints: [], available_assignees: [], form_url: nil, method: :post)
      @task = task_dto
      @available_sprints = available_sprints
      @available_assignees = available_assignees
      @form_url = form_url
      @method = method
    end

    private

    attr_reader :task, :available_sprints, :available_assignees, :form_url, :method

    def form_action_url
      form_url || (task.id.present? ? task_path(task.id) : tasks_path)
    end

    def form_method
      task.id.present? ? :patch : :post
    end

    def submit_button_text
      task.id.present? ? "태스크 수정" : "태스크 생성"
    end

    def status_options
      [
        ["대기중", "todo"],
        ["진행중", "in_progress"],
        ["검토중", "review"],
        ["완료", "done"],
        ["차단됨", "blocked"],
        ["취소됨", "cancelled"]
      ]
    end

    def priority_options
      [
        ["긴급", "urgent"],
        ["높음", "high"],
        ["중간", "medium"],
        ["낮음", "low"]
      ]
    end

    def assignee_options
      options = [["미할당", ""]]
      
      available_assignees.each do |assignee|
        if assignee.respond_to?(:name) && assignee.respond_to?(:id)
          options << [assignee.name, assignee.id]
        elsif assignee.is_a?(Hash)
          options << [assignee[:name] || assignee["name"], assignee[:id] || assignee["id"]]
        end
      end
      
      options
    end

    def sprint_options
      options = [["스프린트 없음", ""]]
      
      available_sprints.each do |sprint|
        if sprint.respond_to?(:name) && sprint.respond_to?(:id)
          options << [sprint.name, sprint.id]
        elsif sprint.is_a?(Hash)
          options << [sprint[:name] || sprint["name"], sprint[:id] || sprint["id"]]
        end
      end
      
      options
    end

    def tags_value
      if task.tags.is_a?(Array)
        task.tags.join(", ")
      else
        task.tags.to_s
      end
    end

    def labels_value
      if task.labels.is_a?(Array)
        task.labels.join(", ")
      else
        task.labels.to_s
      end
    end
  end
end