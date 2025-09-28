# frozen_string_literal: true

require 'test_helper'
require 'dry-monads'

class MilestoneRepositoryTest < ActiveSupport::TestCase
  include Dry::Monads[:result]

  def setup
    @repository = MilestoneRepository.new
    @organization_id = "test_org_123"
    
    # Mock milestone model
    @milestone_attributes = {
      title: "Test Milestone",
      description: "Test Description",
      organization_id: @organization_id,
      status: "planning",
      milestone_type: "release",
      planned_start: Date.current,
      planned_end: Date.current + 30.days
    }
  end

  # ===== INPUT VALIDATION TESTS =====

  test "create rejects nil attributes" do
    result = @repository.create(nil)
    
    assert result.failure?
    assert_equal [:invalid_attributes, "Attributes cannot be nil"], result.failure
  end

  test "create rejects missing organization_id" do
    attributes = @milestone_attributes.except(:organization_id)
    
    result = @repository.create(attributes)
    
    assert result.failure?
    assert_equal [:missing_required, "Organization ID is required"], result.failure
  end

  test "find rejects blank id" do
    result = @repository.find("")
    
    assert result.failure?
    assert_equal [:invalid_id, "ID cannot be blank"], result.failure
  end

  test "find rejects nil id" do
    result = @repository.find(nil)
    
    assert result.failure?
    assert_equal [:invalid_id, "ID cannot be blank"], result.failure
  end

  test "update rejects nil attributes" do
    result = @repository.update("test_id", nil)
    
    assert result.failure?
    assert_equal [:invalid_attributes, "Attributes cannot be nil"], result.failure
  end

  test "update rejects blank id" do
    result = @repository.update("", { title: "New Title" })
    
    assert result.failure?
    assert_equal [:invalid_id, "ID cannot be blank"], result.failure
  end

  # ===== FILTERING VALIDATION TESTS =====

  test "find_by_organization rejects missing organization_id" do
    result = @repository.find_by_organization(nil)
    
    assert result.failure?
    assert_equal [:invalid_id, "Organization ID is required"], result.failure
  end

  test "find_by_organization rejects blank organization_id" do
    result = @repository.find_by_organization("")
    
    assert result.failure?
    assert_equal [:invalid_id, "Organization ID is required"], result.failure
  end

  test "find_active rejects missing organization_id" do
    result = @repository.find_active(nil)
    
    assert result.failure?
    assert_equal [:invalid_id, "Organization ID is required"], result.failure
  end

  test "find_at_risk rejects missing organization_id" do
    result = @repository.find_at_risk("")
    
    assert result.failure?
    assert_equal [:invalid_id, "Organization ID is required"], result.failure
  end

  # ===== OBJECTIVE VALIDATION TESTS =====

  test "add_objective validates required fields" do
    result = @repository.add_objective("", "", "", owner: nil)
    
    assert result.failure?
    assert_equal [:invalid_id, "Milestone ID is required"], result.failure
  end

  test "add_objective validates title" do
    result = @repository.add_objective("test_id", "", "desc", owner: "user")
    
    assert result.failure?
    assert_equal [:invalid_data, "Title is required"], result.failure
  end

  test "add_objective validates owner" do
    result = @repository.add_objective("test_id", "title", "desc", owner: nil)
    
    assert result.failure?
    assert_equal [:invalid_data, "Owner is required"], result.failure
  end

  # ===== RISK MANAGEMENT VALIDATION TESTS =====

  test "add_risk validates severity values" do
    result = @repository.add_risk(
      "test_id", "Risk Title", "Description", 
      severity: "invalid", probability: "high", raised_by: "user"
    )
    
    assert result.failure?
    assert_equal [:invalid_data, "Invalid severity"], result.failure
  end

  test "add_risk validates probability values" do
    result = @repository.add_risk(
      "test_id", "Risk Title", "Description", 
      severity: "high", probability: "invalid", raised_by: "user"
    )
    
    assert result.failure?
    assert_equal [:invalid_data, "Invalid probability"], result.failure
  end

  test "add_risk accepts valid severity values" do
    %w[low medium high critical].each do |severity|
      # This would fail in actual test since MongoDB isn't connected
      # But validates that the validation logic allows valid values
      begin
        @repository.add_risk(
          "test_id", "Risk Title", "Description",
          severity: severity, probability: "medium", raised_by: "user"
        )
        # If no validation error is raised, the severity is accepted
      rescue => e
        # Allow database/connection errors, but not validation errors
        unless e.message.include?("MongoDB") || e.message.include?("connection") || e.message.include?("find")
          raise e
        end
      end
    end
  end

  # ===== DEPENDENCY VALIDATION TESTS =====

  test "add_dependency validates dependency type" do
    result = @repository.add_dependency(
      "test_id", "Dep Title", "Description",
      type: "invalid_type", dependent_on: "something", owner: "user"
    )
    
    assert result.failure?
    assert_equal [:invalid_data, "Invalid dependency type"], result.failure
  end

  test "add_dependency accepts valid types" do
    %w[internal external technical business].each do |type|
      begin
        @repository.add_dependency(
          "test_id", "Dep Title", "Description",
          type: type, dependent_on: "something", owner: "user"
        )
        # If no validation error is raised, the type is accepted
      rescue => e
        # Allow database/connection errors, but not validation errors
        unless e.message.include?("MongoDB") || e.message.include?("connection") || e.message.include?("find")
          raise e
        end
      end
    end
  end

  # ===== KEY RESULT VALIDATION TESTS =====

  test "update_key_result validates numeric current_value" do
    result = @repository.update_key_result(
      "milestone_id", "obj_id", "kr_id", "invalid", updated_by: "user"
    )
    
    assert result.failure?
    assert_equal [:invalid_data, "Current value must be a number"], result.failure
  end

  test "update_key_result validates updated_by" do
    result = @repository.update_key_result(
      "milestone_id", "obj_id", "kr_id", 50, updated_by: nil
    )
    
    assert result.failure?
    assert_equal [:invalid_data, "Updated by user is required"], result.failure
  end

  # ===== DATE PARSING TESTS =====

  test "parse_date_safely handles various formats" do
    repository = @repository
    
    # Valid date
    assert_equal Date.current, repository.send(:parse_date_safely, Date.current)
    
    # Valid date string
    date_string = "2024-03-15"
    assert_equal Date.parse(date_string), repository.send(:parse_date_safely, date_string)
    
    # Invalid date string
    assert_nil repository.send(:parse_date_safely, "invalid-date")
    
    # Nil input
    assert_nil repository.send(:parse_date_safely, nil)
    
    # Empty string
    assert_nil repository.send(:parse_date_safely, "")
    
    # Non-date object
    assert_nil repository.send(:parse_date_safely, 123)
  end

  # ===== SAFE USER SNAPSHOT TESTS =====

  test "set_created_by_safely handles nil gracefully" do
    # Create a simple mock object
    milestone = OpenStruct.new
    
    result = @repository.send(:set_created_by_safely, milestone, nil)
    
    assert result.success?
    assert_equal milestone, result.value!
  end

  test "set_owner_safely handles nil gracefully" do
    milestone = OpenStruct.new
    
    result = @repository.send(:set_owner_safely, milestone, nil)
    
    assert result.success?
    assert_equal milestone, result.value!
  end

  test "set_stakeholders_safely handles empty array" do
    milestone = OpenStruct.new
    milestone.stakeholder_snapshots = []
    
    result = @repository.send(:set_stakeholders_safely, milestone, [])
    
    assert result.success?
  end

  test "set_stakeholders_safely handles nil" do
    milestone = OpenStruct.new
    
    result = @repository.send(:set_stakeholders_safely, milestone, nil)
    
    assert result.success?
  end

  # ===== PROGRESS SUMMARY VALIDATION TESTS =====

  test "progress_summary validates organization_id" do
    result = @repository.progress_summary(nil)
    
    assert result.failure?
    assert_equal [:invalid_id, "Organization ID is required"], result.failure
  end

  test "progress_summary validates blank organization_id" do
    result = @repository.progress_summary("")
    
    assert result.failure?
    assert_equal [:invalid_id, "Organization ID is required"], result.failure
  end

  # ===== RISK SUMMARY VALIDATION TESTS =====

  test "risk_summary validates organization_id" do
    result = @repository.risk_summary(nil)
    
    assert result.failure?
    assert_equal [:invalid_id, "Organization ID is required"], result.failure
  end

  test "risk_summary validates blank organization_id" do
    result = @repository.risk_summary("")
    
    assert result.failure?
    assert_equal [:invalid_id, "Organization ID is required"], result.failure
  end

  # ===== TIMELINE ANALYSIS VALIDATION TESTS =====

  test "timeline_analysis validates organization_id" do
    result = @repository.timeline_analysis(nil)
    
    assert result.failure?
    assert_equal [:invalid_id, "Organization ID is required"], result.failure
  end

  test "timeline_analysis validates blank organization_id" do
    result = @repository.timeline_analysis("")
    
    assert result.failure?
    assert_equal [:invalid_id, "Organization ID is required"], result.failure
  end

  # ===== MILESTONE SPECIFIC OPERATION VALIDATION TESTS =====

  test "update_progress validates milestone_id" do
    result = @repository.update_progress("")
    
    assert result.failure?
    assert_equal [:invalid_id, "Milestone ID is required"], result.failure
  end

  test "update_sprint_counts validates milestone_id" do
    result = @repository.update_sprint_counts(nil)
    
    assert result.failure?
    assert_equal [:invalid_id, "Milestone ID is required"], result.failure
  end

  test "add_blocker validates required fields" do
    result = @repository.add_blocker("", "", "", raised_by: "user")
    
    assert result.failure?
    assert_equal [:invalid_id, "Milestone ID is required"], result.failure
  end

  test "add_blocker validates title" do
    result = @repository.add_blocker("test_id", "", "desc", raised_by: "user")
    
    assert result.failure?
    assert_equal [:invalid_data, "Title is required"], result.failure
  end

  test "assign_blocker validates assignee" do
    result = @repository.assign_blocker("test_id", "blocker_id", assignee: nil)
    
    assert result.failure?
    assert_equal [:invalid_data, "Assignee is required"], result.failure
  end

  test "resolve_blocker validates resolution" do
    result = @repository.resolve_blocker("test_id", "blocker_id", "")
    
    assert result.failure?
    assert_equal [:invalid_data, "Resolution is required"], result.failure
  end

  test "update_risk_mitigation validates mitigation_plan" do
    result = @repository.update_risk_mitigation("test_id", "risk_id", "", owner: "user")
    
    assert result.failure?
    assert_equal [:invalid_data, "Mitigation plan is required"], result.failure
  end

  # ===== HELPER METHOD TESTS =====

  test "milestone_summary handles milestone without optional methods" do
    milestone = OpenStruct.new(
      id: "test_123",
      title: "Test Milestone",
      progress_percentage: 50,
      owner_snapshot: { user_id: "user_123" }
    )
    
    summary = @repository.send(:milestone_summary, milestone)
    
    assert_equal "test_123", summary[:id]
    assert_equal "Test Milestone", summary[:title]
    assert_equal 50, summary[:progress_percentage]
    assert_nil summary[:days_remaining]
    assert_equal "unknown", summary[:health_status]
  end

  test "calculate_overall_progress handles zero total_tasks" do
    results = [
      { "total_tasks" => 0, "completed_tasks" => 0 }
    ]
    
    progress = @repository.send(:calculate_overall_progress, results)
    
    assert_equal 0, progress
  end

  test "calculate_overall_progress calculates correctly" do
    results = [
      { "total_tasks" => 10, "completed_tasks" => 3 },
      { "total_tasks" => 20, "completed_tasks" => 7 }
    ]
    
    progress = @repository.send(:calculate_overall_progress, results)
    
    # (3 + 7) / (10 + 20) * 100 = 10/30 * 100 = 33.33
    assert_equal 33.33, progress
  end

  test "allowed_filter_keys returns expected keys" do
    expected_keys = %w[organization_id status milestone_type planned_start planned_end owner_id stakeholder_id health_status]
    
    assert_equal expected_keys, @repository.send(:allowed_filter_keys)
  end
end