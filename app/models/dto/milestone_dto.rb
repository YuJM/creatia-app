# frozen_string_literal: true

module Dto
  # Milestone 데이터 전송 객체 (MongoDB 모델 기반)
  class MilestoneDto < BaseDto

    # Core identifiers
    attribute :id, Types::String
    attribute :title, Types::String
    attribute? :description, Types::String.optional

    # References
    attribute :organization_id, Types::String
    attribute? :service_id, Types::String.optional.default(nil)

    # Milestone definition
    attribute :status, Types::String.default("planning")  # planning, active, completed, cancelled
    attribute :milestone_type, Types::String.default("release")  # release, feature, business

    # Timeline
    attribute? :planned_start, Types::Date.optional
    attribute? :planned_end, Types::Date.optional
    attribute? :actual_start, Types::Date.optional
    attribute? :actual_end, Types::Date.optional

    # Progress tracking
    attribute? :total_sprints, Types::Integer.default(0)
    attribute? :completed_sprints, Types::Integer.default(0)
    attribute? :total_tasks, Types::Integer.default(0)
    attribute? :completed_tasks, Types::Integer.default(0)
    attribute? :progress_percentage, Types::Float.default(0.0)

    # User Snapshots (간소화된 버전)
    attribute? :owner, Types::Hash.optional
    # { user_id, name, email, avatar_url }
    
    attribute? :created_by, Types::Hash.optional
    
    attribute? :stakeholders, Types::Array.default { [] }
    # [{ user_id, name, email, role }]

    # Objectives & Key Results (간소화)
    attribute? :objectives_count, Types::Integer.default(0)
    attribute? :key_results_count, Types::Integer.default(0)
    attribute? :key_results_achieved, Types::Integer.default(0)

    # Risk & Dependencies (요약)
    attribute? :high_risks_count, Types::Integer.default(0)
    attribute? :open_blockers_count, Types::Integer.default(0)
    attribute? :pending_dependencies_count, Types::Integer.default(0)

    # Health Status
    attribute? :health_status, Types::String.default("on_track")

    # Timestamps
    attribute? :created_at, Types::DateTime.optional
    attribute? :updated_at, Types::DateTime.optional

    def self.from_model(milestone)
      return nil unless milestone

      # Count metrics with safe access
      objectives_count = safe_count(milestone.objectives)
      key_results_count = safe_key_results_count(milestone.objectives)
      key_results_achieved = safe_key_results_achieved_count(milestone.objectives)
      
      high_risks_count = safe_high_risks_count(milestone.risks)
      open_blockers_count = safe_open_blockers_count(milestone.blockers)
      pending_dependencies_count = safe_pending_dependencies_count(milestone.dependencies)

      new(
        id: milestone.id.to_s,
        title: milestone.title || "Untitled Milestone",
        description: milestone.description,
        organization_id: milestone.organization_id.to_s,
        service_id: milestone.service_id,
        status: milestone.status || "planning",
        milestone_type: milestone.milestone_type || "release",
        planned_start: milestone.planned_start,
        planned_end: milestone.planned_end,
        actual_start: milestone.actual_start,
        actual_end: milestone.actual_end,
        total_sprints: milestone.total_sprints || 0,
        completed_sprints: milestone.completed_sprints || 0,
        total_tasks: milestone.total_tasks || 0,
        completed_tasks: milestone.completed_tasks || 0,
        progress_percentage: milestone.progress_percentage || 0.0,
        owner: simplify_user_snapshot(milestone.respond_to?(:owner_snapshot) ? milestone.owner_snapshot : nil),
        created_by: simplify_user_snapshot(milestone.respond_to?(:created_by_snapshot) ? milestone.created_by_snapshot : nil),
        stakeholders: safe_stakeholders_array(milestone.respond_to?(:stakeholder_snapshots) ? milestone.stakeholder_snapshots : []),
        objectives_count: objectives_count,
        key_results_count: key_results_count,
        key_results_achieved: key_results_achieved,
        high_risks_count: high_risks_count,
        open_blockers_count: open_blockers_count,
        pending_dependencies_count: pending_dependencies_count,
        health_status: safe_health_status(milestone),
        created_at: milestone.created_at,
        updated_at: milestone.updated_at
      )
    rescue => e
      Rails.logger.error "Error creating MilestoneDto: #{e.message}"
      # Return minimal DTO with error indication
      new(
        id: milestone&.id&.to_s || "unknown",
        title: milestone&.title || "Error Loading Milestone",
        description: "Error occurred while loading milestone data",
        organization_id: milestone&.organization_id&.to_s || "unknown",
        status: "error",
        created_at: milestone&.created_at || DateTime.current,
        updated_at: milestone&.updated_at || DateTime.current
      )
    end
    
    def self.simplify_user_snapshot(snapshot)
      return nil if snapshot.blank?
      
      {
        user_id: snapshot['user_id'] || snapshot[:user_id],
        name: snapshot['name'] || snapshot[:name] || 'Unknown User',
        email: snapshot['email'] || snapshot[:email] || '',
        avatar_url: snapshot['avatar_url'] || snapshot[:avatar_url]
      }
    rescue => e
      Rails.logger.warn "Error simplifying user snapshot: #{e.message}"
      { user_id: 'unknown', name: 'Unknown User', email: '', avatar_url: nil }
    end
    
    def self.simplify_stakeholder(stakeholder)
      return nil unless stakeholder
      
      {
        user_id: stakeholder['user_id'] || stakeholder[:user_id],
        name: stakeholder['name'] || stakeholder[:name] || 'Unknown User',
        email: stakeholder['email'] || stakeholder[:email] || '',
        role: stakeholder['role'] || stakeholder[:role] || 'Stakeholder'
      }
    rescue => e
      Rails.logger.warn "Error simplifying stakeholder: #{e.message}"
      { user_id: 'unknown', name: 'Unknown User', email: '', role: 'Stakeholder' }
    end

    def self.calculate_progress(milestone)
      # 이미 progress_percentage가 있으면 그것을 사용
      return milestone.progress_percentage if milestone.respond_to?(:progress_percentage) && milestone.progress_percentage

      # 없으면 계산
      total = milestone.total_tasks || 0
      return 0 if total.zero?

      completed = milestone.completed_tasks || 0
      ((completed.to_f / total) * 100).round
    end

    # Instance methods
    def overdue?
      planned_end && planned_end < Date.current && status != "completed"
    end

    def days_remaining
      return nil unless planned_end
      (planned_end - Date.current).to_i
    end

    def sprint_progress
      return 0 if total_sprints.zero?
      ((completed_sprints.to_f / total_sprints) * 100).round
    end

    def task_progress
      return 0 if total_tasks.zero?
      ((completed_tasks.to_f / total_tasks) * 100).round
    end

    def is_active?
      status == "active"
    end

    def is_completed?
      status == "completed"
    end

    def status_color
      case status
      when "completed" then "green"
      when "active" then "blue"
      when "planning" then "gray"
      when "error" then "red"
      else "yellow"
      end
    end

    # 안전한 Owner ID 추출
    def owner_id
      owner&.dig(:user_id) || owner&.dig('user_id')
    end

    # 안전한 Owner 이름 추출
    def owner_name
      owner&.dig(:name) || owner&.dig('name') || 'Unassigned'
    end

    private

    def self.safe_count(collection)
      collection&.count || 0
    rescue
      0
    end

    def self.safe_key_results_count(objectives)
      return 0 unless objectives

      objectives.sum do |obj|
        obj['key_results']&.count || 0
      end
    rescue
      0
    end

    def self.safe_key_results_achieved_count(objectives)
      return 0 unless objectives

      objectives.sum do |obj|
        next 0 unless obj['key_results']
        
        obj['key_results'].count do |kr|
          kr['current'] && kr['target'] && kr['current'] >= kr['target']
        end
      end
    rescue
      0
    end

    def self.safe_high_risks_count(risks)
      return 0 unless risks

      risks.count do |r|
        ['high', 'critical'].include?(r['severity'])
      end
    rescue
      0
    end

    def self.safe_open_blockers_count(blockers)
      return 0 unless blockers

      blockers.count do |b|
        b['status'] != 'resolved'
      end
    rescue
      0
    end

    def self.safe_pending_dependencies_count(dependencies)
      return 0 unless dependencies

      dependencies.count do |d|
        d['status'] == 'pending'
      end
    rescue
      0
    end

    def self.safe_health_status(milestone)
      return "on_track" unless milestone.respond_to?(:health_status)
      
      milestone.health_status || "on_track"
    rescue
      "unknown"
    end

    def self.safe_stakeholders_array(stakeholder_snapshots)
      return [] unless stakeholder_snapshots

      stakeholder_snapshots.map { |s| simplify_stakeholder(s) }.compact
    rescue
      []
    end
  end
end