# frozen_string_literal: true

module Sprints
  class SprintBoardComponent < ViewComponent::Base
    include Turbo::FramesHelper

    def initialize(sprint:, tasks: [], current_user:)
      @sprint = sprint
      @tasks = tasks
      @current_user = current_user
      @tasks_by_status = group_tasks_by_status
    end

    private

    attr_reader :sprint, :tasks, :current_user, :tasks_by_status

    def group_tasks_by_status
      {
        'backlog' => tasks.select { |t| t.status == 'backlog' },
        'todo' => tasks.select { |t| t.status == 'todo' },
        'in_progress' => tasks.select { |t| t.status == 'in_progress' },
        'review' => tasks.select { |t| t.status == 'review' },
        'done' => tasks.select { |t| t.status == 'done' }
      }
    end

    def status_columns
      [
        { key: 'backlog', label: 'Backlog', color: 'gray' },
        { key: 'todo', label: 'To Do', color: 'blue' },
        { key: 'in_progress', label: 'In Progress', color: 'yellow' },
        { key: 'review', label: 'Review', color: 'purple' },
        { key: 'done', label: 'Done', color: 'green' }
      ]
    end

    def column_header_class(color)
      case color
      when 'gray'
        'bg-gray-100 text-gray-700'
      when 'blue'
        'bg-blue-100 text-blue-700'
      when 'yellow'
        'bg-yellow-100 text-yellow-700'
      when 'purple'
        'bg-purple-100 text-purple-700'
      when 'green'
        'bg-green-100 text-green-700'
      else
        'bg-gray-100 text-gray-700'
      end
    end

    def priority_color(priority)
      case priority
      when 'urgent'
        'text-red-600'
      when 'high'
        'text-orange-600'
      when 'medium'
        'text-yellow-600'
      when 'low'
        'text-green-600'
      else
        'text-gray-600'
      end
    end

    def priority_icon(priority)
      case priority
      when 'urgent'
        '🔴'
      when 'high'
        '🟠'
      when 'medium'
        '🟡'
      when 'low'
        '🟢'
      else
        '⚪'
      end
    end

    def task_type_icon(task_type)
      case task_type
      when 'feature'
        '✨'
      when 'bug'
        '🐛'
      when 'improvement'
        '💡'
      when 'task'
        '📋'
      else
        '📌'
      end
    end

    def format_points(points)
      return '-' unless points
      points.to_s
    end

    def sprint_progress_percentage
      return 0 if sprint.committed_points.to_f.zero?
      ((sprint.completed_points.to_f / sprint.committed_points) * 100).round
    end

    def days_remaining
      return 0 unless sprint.end_date
      (sprint.end_date - Date.current).to_i
    end

    def velocity_trend
      return 'stable' unless sprint.planned_velocity && sprint.actual_velocity
      
      if sprint.actual_velocity > sprint.planned_velocity * 1.1
        'up'
      elsif sprint.actual_velocity < sprint.planned_velocity * 0.9
        'down'
      else
        'stable'
      end
    end

    def velocity_trend_icon
      case velocity_trend
      when 'up'
        '📈'
      when 'down'
        '📉'
      else
        '➡️'
      end
    end
  end
end