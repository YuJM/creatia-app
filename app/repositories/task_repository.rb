# frozen_string_literal: true

require_relative "base_repository"

# Task 도메인 Repository
class TaskRepository < BaseRepository
  def find_by_organization(organization_id, filters = {})
    filters[:organization_id] = organization_id
    all(filters)
  end

  def find_by_sprint(sprint_id, filters = {})
    filters[:sprint_id] = sprint_id
    all(filters)
  end

  def find_by_assignee(assignee_id, filters = {})
    filters[:assignee_id] = assignee_id
    all(filters)
  end

  def find_overdue(organization_id)
    filters = {
      organization_id: organization_id,
      due_date: { "$lt" => Date.current },
      status: { "$ne" => "done" }
    }
    all(filters)
  end

  def find_due_soon(organization_id, days = 7)
    filters = {
      organization_id: organization_id,
      due_date: { "$gte" => Date.current, "$lte" => days.days.from_now.to_date },
      status: { "$ne" => "done" }
    }
    all(filters)
  end

  def status_statistics(organization_id)
    Try do
      model_class.where(organization_id: organization_id)
                 .group(:status)
                 .count
    end.to_result
  rescue StandardError => e
    Failure([ :database_error, e.message ])
  end

  def priority_statistics(organization_id)
    Try do
      model_class.where(organization_id: organization_id)
                 .group(:priority)
                 .count
    end.to_result
  rescue StandardError => e
    Failure([ :database_error, e.message ])
  end

  def bulk_update_status(task_ids, new_status, organization_id)
    Try do
      tasks = model_class.where(
        id: task_ids,
        organization_id: organization_id
      )

      tasks.update_all(
        status: new_status,
        updated_at: Time.current
      )

      tasks.to_a
    end.to_result
  rescue StandardError => e
    Failure([ :database_error, e.message ])
  end

  def reorder(task_id, new_position, status = nil)
    find(task_id).bind do |task|
      Try do
        updates = { position: new_position }
        updates[:status] = status if status

        task.update!(updates)
        task
      end.to_result
    end
  rescue StandardError => e
    Failure([ :database_error, e.message ])
  end

  # Result 모나드 래핑 헬퍼
  def wrap_result
    yield
  rescue Mongoid::Errors::DocumentNotFound => e
    Failure([:not_found, e.message])
  rescue Mongoid::Errors::Validations => e
    Failure([:validation_error, e.record.errors.to_h])
  rescue StandardError => e
    Failure([:database_error, e.message])
  end

  # 배치 User ID 추출 (TaskQueryService용)
  def extract_user_ids_from_tasks(tasks)
    user_ids = []

    tasks.each do |task|
      user_ids << task.assignee_id if task.assignee_id.present?
      user_ids << task.reviewer_id if task.reviewer_id.present?
    end

    user_ids.uniq
  end

  # 스냅샷 동기화가 필요한 Task 조회 (별도 컬렉션 기반)
  def find_tasks_needing_snapshot_sync(organization_id, ttl = 1.hour)
    Try do
      # 1. 조직의 모든 Task 조회
      tasks = model_class.where(organization_id: organization_id).to_a

      # 2. Ruby에서 스냅샷 신선도 확인
      tasks.reject(&:snapshots_fresh?)
    end.to_result
  rescue StandardError => e
    Failure([ :database_error, e.message ])
  end

  # 대량 스냅샷 업데이트 (백그라운드 Job용) - 별도 컬렉션 사용
  def bulk_update_snapshots(user_ids)
    Try do
      # UserSnapshot 컬렉션에서 직접 배치 처리
      users = User.where(id: user_ids).index_by { |u| u.id.to_s }

      updated_count = 0
      user_ids.each do |user_id|
        user = users[user_id.to_s]
        next unless user

        snapshot = UserSnapshot.where(user_id: user_id.to_s).first

        if snapshot.present?
          snapshot.sync_from_user!(user)
        else
          snapshot = UserSnapshot.from_user(user)
          snapshot.save!
        end

        updated_count += 1
      end

      updated_count
    end.to_result
  rescue StandardError => e
    Failure([ :database_error, e.message ])
  end

  # 성능 최적화를 위한 배치 조회
  def find_with_preloaded_snapshots(filters)
    Try do
      scope = build_filtered_scope(filters)

      # 스냅샷을 포함한 조회로 N+1 방지
      scope.includes(:assignee_snapshot, :reviewer_snapshot)
    end.to_result
  rescue StandardError => e
    Failure([ :database_error, e.message ])
  end

  # Task 스냅샷 통계 (관리용)
  def snapshot_sync_statistics(organization_id)
    Try do
      total_tasks = model_class.where(organization_id: organization_id).count

      with_assignee = model_class.where(
        organization_id: organization_id,
        assignee_id: { "$exists" => true, "$ne" => nil }
      ).count

      fresh_assignee_snapshots = model_class.where(
        organization_id: organization_id,
        assignee_id: { "$exists" => true, "$ne" => nil },
        "assignee_snapshot.synced_at" => { "$gte" => 1.hour.ago }
      ).count

      with_reviewer = model_class.where(
        organization_id: organization_id,
        reviewer_id: { "$exists" => true, "$ne" => nil }
      ).count

      fresh_reviewer_snapshots = model_class.where(
        organization_id: organization_id,
        reviewer_id: { "$exists" => true, "$ne" => nil },
        "reviewer_snapshot.synced_at" => { "$gte" => 1.hour.ago }
      ).count

      {
        total_tasks: total_tasks,
        with_assignee: with_assignee,
        with_reviewer: with_reviewer,
        assignee_snapshot_freshness: fresh_assignee_snapshots.to_f / with_assignee * 100,
        reviewer_snapshot_freshness: fresh_reviewer_snapshots.to_f / with_reviewer * 100,
        stale_snapshots_count: (with_assignee - fresh_assignee_snapshots) + (with_reviewer - fresh_reviewer_snapshots)
      }
    end.to_result
  rescue StandardError => e
    Failure([ :database_error, e.message ])
  end

  protected

  def model_class
    Task
  end

  # 필터를 적용한 스코프 빌더 (재사용)
  def build_filtered_scope(filters)
    scope = model_class.where(organization_id: filters[:organization_id]) if filters[:organization_id]
    scope ||= model_class.all

    scope = scope.where(status: filters[:status]) if filters[:status].present?
    scope = scope.where(priority: filters[:priority]) if filters[:priority].present?
    scope = scope.where(assignee_id: filters[:assignee_id]) if filters[:assignee_id].present?
    scope = scope.where(sprint_id: filters[:sprint_id]) if filters[:sprint_id].present?
    scope = scope.where(milestone_id: filters[:milestone_id]) if filters[:milestone_id].present?

    scope
  end
end
