# frozen_string_literal: true

module Tasks
  class TaskDetailComponent < ViewComponent::Base
    include Turbo::FramesHelper
    include Turbo::StreamsHelper

    def initialize(task_dto:, current_user:)
      @task = task_dto
      @current_user = current_user
    end

    private

    attr_reader :task, :current_user

    def status_badge_class
      base = "px-3 py-1 inline-flex text-xs leading-5 font-semibold rounded-full"
      
      case task.status
      when "done"
        "#{base} bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400"
      when "in_progress"
        "#{base} bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400"
      when "review"
        "#{base} bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400"
      when "blocked"
        "#{base} bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400"
      when "cancelled"
        "#{base} bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400"
      else
        "#{base} bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400"
      end
    end

    def priority_badge_class
      base = "px-3 py-1 inline-flex text-xs leading-5 font-semibold rounded-full"
      
      case task.priority
      when "urgent"
        "#{base} bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400"
      when "high"
        "#{base} bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-400"
      when "medium"
        "#{base} bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400"
      when "low"
        "#{base} bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400"
      else
        "#{base} bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400"
      end
    end

    def format_date(date)
      return "설정 안됨" unless date
      
      if date.is_a?(String)
        Date.parse(date).strftime("%Y년 %m월 %d일")
      else
        date.strftime("%Y년 %m월 %d일")
      end
    rescue
      "설정 안됨"
    end

    def format_datetime(datetime)
      return nil unless datetime
      
      if datetime.is_a?(String)
        DateTime.parse(datetime).strftime("%Y-%m-%d %H:%M")
      else
        datetime.strftime("%Y-%m-%d %H:%M")
      end
    rescue
      nil
    end

    def assignee_avatar
      if task.assignee
        content_tag(:div, class: "flex items-center gap-2") do
          concat(content_tag(:div, class: "h-8 w-8 rounded-full bg-indigo-500 flex items-center justify-center text-white text-sm font-medium") do
            task.assignee.name.first.upcase
          end)
          concat(content_tag(:span, task.assignee.name, class: "text-sm text-gray-900 dark:text-gray-100"))
        end
      else
        content_tag(:span, "미할당", class: "text-sm text-gray-500 dark:text-gray-400")
      end
    end

    def progress_percentage
      task.completion_percentage || 0
    end

    def progress_bar_color
      if progress_percentage >= 100
        "bg-green-500"
      elsif progress_percentage >= 70
        "bg-blue-500"
      elsif progress_percentage >= 30
        "bg-yellow-500"
      else
        "bg-gray-400"
      end
    end
  end
end