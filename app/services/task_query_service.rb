# frozen_string_literal: true

# TaskQueryService - Task 조회와 User 데이터 통합을 담당하는 서비스
# Service Layer에서 복잡한 Cross-database 로직을 처리하고
# DTO는 순수한 데이터 표현만 담당하도록 분리
class TaskQueryService
  include Dry::Monads[:result, :maybe]

  def initialize(organization)
    @organization = organization
    @user_resolver = UserDataResolver.new
    @stats = {
      total_queries: 0,
      average_response_time: 0.0,
      cache_efficiency: 0.0
    }
  end

  # 조직의 Task 목록 조회 (User 데이터 포함)
  def list_with_users(filters = {})
    measure_performance("list_with_users") do
      @stats[:total_queries] += 1
      

      # MongoDB Aggregation을 사용한 최적화된 조회 시도
      if use_mongodb_aggregation?(filters)
        aggregation_result = fetch_tasks_with_lookup(filters)
        return aggregation_result if aggregation_result.success?
      end

      # Fallback: 기존 방식
      # 1. Task 기본 조회
      tasks_result = fetch_tasks(filters)

      case tasks_result
      when Success
        tasks = tasks_result.value!

        # 2. User 데이터 해결
        user_data_result = @user_resolver.resolve_for_tasks(tasks)

        case user_data_result
        when Success
          enriched_data = user_data_result.value!

          # 3. DTO 변환
          dtos = build_simple_task_dtos(enriched_data)

          Success({
            tasks: dtos,
            metadata: build_metadata(tasks, enriched_data),
            stats: resolver_stats
          })
        when Failure
          user_data_result
        end
      when Failure
        tasks_result
      end
    end
  end

  # 단일 Task 조회 (User 데이터 포함)
  def find_with_user(task_id)
    measure_performance("find_with_user") do
      # Task 조회
      task = Task.find_by(id: task_id)
      return Failure(:task_not_found) unless task

      # User 데이터 해결
      assignee = @user_resolver.resolve_user_for_task(task, :assignee)
      reviewer = @user_resolver.resolve_user_for_task(task, :reviewer)

      # Sprint/Milestone 정보 추가
      sprint_data = resolve_sprint_data(task)
      milestone_data = resolve_milestone_data(task)

      # DTO 생성
      dto = build_task_dto_with_relations(task, assignee, reviewer, sprint_data, milestone_data)

      Success(dto)
    end
  end

  # Sprint의 모든 Task 조회 (백로그/보드뷰용)
  def list_for_sprint(sprint_id, include_completed = false)
    measure_performance("list_for_sprint") do
      filters = { sprint_id: sprint_id }
      filters[:status] = { "$ne" => "done" } unless include_completed

      list_with_users(filters)
    end
  end

  # 사용자별 할당된 Task 조회
  def list_for_assignee(user_id, filters = {})
    measure_performance("list_for_assignee") do
      assignee_filters = filters.merge(assignee_id: user_id.to_s)
      list_with_users(assignee_filters)
    end
  end

  # 대시보드용 요약 정보
  def dashboard_summary
    measure_performance("dashboard_summary") do
      # 모든 Task 조회 (메모리에서 그룹 처리)
      all_tasks = Task.where(organization_id: @organization.id.to_s).to_a

      # Ruby 메서드로 통계 계산 (MongoDB group 이슈 회피)
      by_status = all_tasks.group_by(&:status).transform_values(&:count)
      by_priority = all_tasks.group_by(&:priority).transform_values(&:count)

      # 활성 Sprint의 Task 진행률
      active_sprints = Sprint.where(
        organization_id: @organization.id.to_s,
        status: "active"
      ).to_a

      sprint_progress = active_sprints.map do |sprint|
        sprint_tasks = all_tasks.select { |task| task.sprint_id == sprint.id.to_s }
        completed_count = sprint_tasks.count { |task| task.status == "done" }

        {
          sprint_id: sprint.id.to_s,
          sprint_name: sprint.name,
          total: sprint_tasks.size,
          completed: completed_count,
          progress_percentage: sprint_tasks.empty? ? 0 : (completed_count.to_f / sprint_tasks.size * 100).round(1)
        }
      end

      Success({
        total_tasks: all_tasks.size,
        by_status: by_status,
        by_priority: by_priority,
        active_sprints: sprint_progress,
        performance_stats: @stats
      })
    end
  end

  # MongoDB Aggregation을 사용한 Task + UserSnapshot 조인 조회
  def fetch_tasks_with_lookup(filters = {})
    begin
      # MongoDB Aggregation Pipeline 구성
      pipeline = build_aggregation_pipeline(filters)

      # Aggregation 실행
      aggregated_results = Task.collection.aggregate(pipeline).to_a

      # 결과를 DTO로 변환
      dtos = aggregated_results.map do |result|
        task_data = result.except("assignee_snapshot", "reviewer_snapshot")
        task = Task.new(task_data)

        # UserSnapshot에서 UserDto 생성
        assignee_dto = build_user_dto_from_snapshot(result["assignee_snapshot"]&.first)
        reviewer_dto = build_user_dto_from_snapshot(result["reviewer_snapshot"]&.first)

        Dto::TaskDto.from_enriched_data(
          task_to_hash(task),
          {
            assignee: assignee_dto,
            reviewer: reviewer_dto
          }
        )
      end

      Success({
        tasks: dtos,
        metadata: build_metadata_from_aggregation(aggregated_results),
        stats: { aggregation_used: true }
      })

    rescue => e
      Rails.logger.error "[TaskQueryService] Aggregation 조회 실패: #{e.message}"
      Failure(:aggregation_query_failed)
    end
  end

  private

  # Task 기본 조회
  def fetch_tasks(filters)
    begin
      scope = Task.where(organization_id: @organization.id.to_s)

      # 필터 적용
      scope = apply_filters(scope, filters)

      # 정렬 적용
      scope = apply_sorting(scope, filters[:sort])

      # 페이지네이션
      scope = apply_pagination(scope, filters[:page], filters[:per_page])

      Success(scope.to_a)
    rescue => e
      Rails.logger.error "[TaskQueryService] Task 조회 실패: #{e.message}"
      Failure(:task_query_failed)
    end
  end

  # DTO 생성
  def build_simple_task_dtos(enriched_data)
    enriched_data.map do |item|
      task = item[:task]

      Dto::TaskDto.from_enriched_data(
        task_to_hash(task),
        {
          assignee: item[:assignee],
          reviewer: item[:reviewer]
        }
      )
    end
  end

  # Task를 Hash로 변환
  def task_to_hash(task)
    {
      id: task.id.to_s,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      organization_id: task.organization_id,
      due_date: task.due_date,
      start_date: task.start_date,
      completed_at: task.completed_at,
      estimated_hours: task.estimated_hours,
      actual_hours: task.actual_hours,
      remaining_hours: task.remaining_hours,
      completion_percentage: 0,
      tags: task.tags,
      labels: task.labels,
      task_id: task.task_id,
      position: task.position,
      created_at: task.created_at,
      updated_at: task.updated_at,
      sprint: resolve_sprint_data(task),
      milestone: resolve_milestone_data(task)
    }
  end

  # Sprint 데이터 해결
  def resolve_sprint_data(task)
    return nil unless task.sprint_id.present?

    sprint = Sprint.find_by(id: task.sprint_id)
    return nil unless sprint

    {
      id: sprint.id.to_s,
      name: sprint.name,
      status: sprint.status
    }
  end

  # Milestone 데이터 해결
  def resolve_milestone_data(task)
    return nil unless task.milestone_id.present?

    milestone = Milestone.find_by(id: task.milestone_id)
    return nil unless milestone

    {
      id: milestone.id.to_s,
      name: milestone.name,
      due_date: milestone.due_date
    }
  end

  # 개별 Task DTO 생성 (관계 포함)
  def build_task_dto_with_relations(task, assignee, reviewer, sprint_data, milestone_data)
    Dto::TaskDto.from_enriched_data(
      task_to_hash(task).merge(
        sprint: sprint_data,
        milestone: milestone_data
      ),
      {
        assignee: assignee,
        reviewer: reviewer
      }
    )
  end

  # 필터 적용
  def apply_filters(scope, filters)
    return scope if filters.blank?

    scope = scope.where(status: filters[:status]) if filters[:status].present?
    scope = scope.where(priority: filters[:priority]) if filters[:priority].present?
    scope = scope.where(assignee_id: filters[:assignee_id]) if filters[:assignee_id].present?
    scope = scope.where(sprint_id: filters[:sprint_id]) if filters[:sprint_id].present?
    scope = scope.where(milestone_id: filters[:milestone_id]) if filters[:milestone_id].present?

    # 날짜 필터
    if filters[:due_before].present?
      scope = scope.where(due_date: { "$lte" => filters[:due_before] })
    end

    if filters[:due_after].present?
      scope = scope.where(due_date: { "$gte" => filters[:due_after] })
    end

    # 텍스트 검색
    if filters[:search].present?
      search_term = filters[:search]
      scope = scope.where(
        "$or" => [
          { title: { "$regex" => search_term, "$options" => "i" } },
          { description: { "$regex" => search_term, "$options" => "i" } },
          { task_id: { "$regex" => search_term, "$options" => "i" } }
        ]
      )
    end

    scope
  end

  # 정렬 적용
  def apply_sorting(scope, sort_option)
    case sort_option
    when "due_date_asc"
      scope.asc(:due_date)
    when "due_date_desc"
      scope.desc(:due_date)
    when "priority"
      # 우선순위 순서: urgent > high > medium > low
      scope.desc(:priority)
    when "status"
      scope.asc(:status)
    when "title"
      scope.asc(:title)
    else
      # 기본 정렬: position, created_at
      scope.asc(:position).desc(:created_at)
    end
  end

  # 페이지네이션
  def apply_pagination(scope, page, per_page)
    page = (page || 1).to_i
    per_page = (per_page || 50).to_i
    per_page = [ per_page, 100 ].min # 최대 100개로 제한

    scope.skip((page - 1) * per_page).limit(per_page)
  end

  # 메타데이터 생성
  def build_metadata(tasks, enriched_data)
    {
      total_count: tasks.size,
      by_status: tasks.group_by(&:status).transform_values(&:count),
      by_priority: tasks.group_by(&:priority).transform_values(&:count),
      assigned_count: enriched_data.count { |item| item[:assignee].present? },
      unassigned_count: enriched_data.count { |item| item[:assignee].nil? },
      overdue_count: tasks.count { |task| task.due_date && task.due_date < Date.current && task.status != "done" }
    }
  end

  # Sprint 진행률 계산
  def calculate_progress_percentage(tasks)
    return 0 if tasks.empty?

    completed = tasks.count { |task| task.status == "done" }
    (completed.to_f / tasks.count * 100).round(1)
  end

  # Resolver 통계 조회
  def resolver_stats
    {
      user_resolver: @user_resolver.stats,
      query_service: @stats
    }
  end

  # MongoDB Aggregation 사용 조건
  def use_mongodb_aggregation?(filters)
    # 복잡한 필터나 대량 조회시 Aggregation 사용
    filters.size > 2 ||
    filters[:search].present? ||
    !filters[:per_page] || filters[:per_page].to_i > 20
  end

  # MongoDB Aggregation Pipeline 구성
  def build_aggregation_pipeline(filters)
    pipeline = []

    # 1. Match 단계 - Task 필터링
    match_conditions = { organization_id: @organization.id.to_s }
    match_conditions.merge!(build_match_filters(filters))
    pipeline << { "$match" => match_conditions }

    # 2. Lookup 단계 - UserSnapshot 조인
    pipeline << {
      "$lookup" => {
        from: "user_snapshots",
        localField: "assignee_id",
        foreignField: "user_id",
        as: "assignee_snapshot"
      }
    }

    pipeline << {
      "$lookup" => {
        from: "user_snapshots",
        localField: "reviewer_id",
        foreignField: "user_id",
        as: "reviewer_snapshot"
      }
    }

    # 3. Sort 단계
    if filters[:sort].present?
      pipeline << { "$sort" => build_sort_pipeline(filters[:sort]) }
    end

    # 4. Pagination 단계
    if filters[:page] || filters[:per_page]
      page = (filters[:page] || 1).to_i
      per_page = (filters[:per_page] || 50).to_i
      skip = (page - 1) * per_page

      pipeline << { "$skip" => skip }
      pipeline << { "$limit" => per_page }
    end

    pipeline
  end

  # Aggregation용 필터 조건 구성
  def build_match_filters(filters)
    conditions = {}

    conditions["status"] = filters[:status] if filters[:status].present?
    conditions["priority"] = filters[:priority] if filters[:priority].present?
    conditions["assignee_id"] = filters[:assignee_id] if filters[:assignee_id].present?
    conditions["sprint_id"] = filters[:sprint_id] if filters[:sprint_id].present?
    conditions["milestone_id"] = filters[:milestone_id] if filters[:milestone_id].present?

    # 날짜 필터
    if filters[:due_before].present?
      conditions["due_date"] = { "$lte" => filters[:due_before] }
    end

    if filters[:due_after].present?
      due_filter = conditions["due_date"] || {}
      due_filter["$gte"] = filters[:due_after]
      conditions["due_date"] = due_filter
    end

    # 텍스트 검색
    if filters[:search].present?
      search_term = filters[:search]
      conditions["$or"] = [
        { "title" => { "$regex" => search_term, "$options" => "i" } },
        { "description" => { "$regex" => search_term, "$options" => "i" } },
        { "task_id" => { "$regex" => search_term, "$options" => "i" } }
      ]
    end

    conditions
  end

  # Aggregation용 정렬 조건 구성
  def build_sort_pipeline(sort_option)
    case sort_option
    when "due_date_asc"
      { "due_date" => 1 }
    when "due_date_desc"
      { "due_date" => -1 }
    when "priority"
      { "priority" => -1 }
    when "status"
      { "status" => 1 }
    when "title"
      { "title" => 1 }
    else
      { "position" => 1, "created_at" => -1 }
    end
  end

  # UserSnapshot에서 UserDto 생성
  def build_user_dto_from_snapshot(snapshot_data)
    return nil unless snapshot_data

    Dto::UserDto.new(
      id: snapshot_data["user_id"],
      name: snapshot_data["name"],
      email: snapshot_data["email"],
      avatar_url: snapshot_data["avatar_url"],
      role: snapshot_data["role"],
      department: snapshot_data["department"],
      position: snapshot_data["position"]
    )
  end

  # Aggregation 결과에서 메타데이터 생성
  def build_metadata_from_aggregation(results)
    {
      total_count: results.size,
      by_status: results.group_by { |r| r["status"] }.transform_values(&:count),
      by_priority: results.group_by { |r| r["priority"] }.transform_values(&:count),
      assigned_count: results.count { |r| r["assignee_id"].present? || (r["assignee_snapshot"] && r["assignee_snapshot"].any?) },
      unassigned_count: results.count { |r| r["assignee_id"].nil? || (r["assignee_snapshot"] && r["assignee_snapshot"].empty?) },
      aggregation_used: true
    }
  end

  # 성능 측정
  def measure_performance(operation_name)
    start_time = Time.current

    result = yield

    elapsed_time = Time.current - start_time

    # 평균 응답시간 업데이트
    @stats[:average_response_time] = (
      (@stats[:average_response_time] * (@stats[:total_queries] - 1) + elapsed_time) /
      @stats[:total_queries]
    ).round(4)

    if elapsed_time > 0.1 # 100ms 이상
      Rails.logger.warn "[TaskQueryService] #{operation_name} took #{(elapsed_time * 1000).round(2)}ms"
    end

    result
  end
end
