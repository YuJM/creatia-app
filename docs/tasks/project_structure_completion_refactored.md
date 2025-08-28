# 프로젝트 구조 완성 작업 (Gem 최적화 버전)

## 🎯 Epic: Project Structure Completion with Modern Rails Patterns

### 목표
Creatia 프로젝트를 현대적인 Rails 패턴과 설치된 모든 Gem을 활용하여 구현합니다.

### 핵심 기술 스택
- **Service Objects**: dry-monads + attr_extras + memo_wise
- **Validation**: dry-validation
- **View Components**: ViewComponent + Stimulus
- **Serialization**: Alba
- **Authorization**: Pundit
- **Testing**: RSpec (BDD)
- **GitHub Integration**: Octokit + JWT
- **Calendar**: icalendar

---

## 📦 필수 Gem 추가

```ruby
# Gemfile 추가 필요
group :production, :development, :test do
  # Calendar 기능
  gem 'icalendar', '~> 2.10'
  gem 'icalendar-recurrence', '~> 1.2'
  
  # GitHub API 통합  
  gem 'jwt', '~> 2.9'
  gem 'faraday', '~> 2.13'
  gem 'faraday-retry', '~> 2.2'
  gem 'octokit', '~> 9.2'
  gem 'git', '~> 2.3'
  
  # Google Calendar 통합
  gem 'google-apis-calendar_v3', '~> 0.40'
  gem 'googleauth', '~> 1.11'
end
```

---

## 📋 필수 구현 작업

### STRUCT-001: Milestone 모델 구현 (dry-validation + ViewComponent)

**Priority**: High  
**Story Points**: 5

#### BDD Spec First

```ruby
# spec/models/milestone_spec.rb
require 'rails_helper'

RSpec.describe Milestone, type: :model do
  describe 'validations' do
    let(:validator) { MilestoneValidator.new }
    
    context 'with valid attributes' do
      let(:params) do
        {
          name: 'Beta Release',
          target_date: 3.months.from_now.to_date,
          service_id: 1,
          organization_id: 1
        }
      end
      
      it 'passes validation' do
        result = validator.call(params)
        expect(result).to be_success
      end
    end
    
    context 'with past target date' do
      let(:params) do
        {
          name: 'Old Release',
          target_date: 1.month.ago.to_date,
          service_id: 1,
          organization_id: 1
        }
      end
      
      it 'fails validation' do
        result = validator.call(params)
        expect(result).to be_failure
        expect(result.errors[:target_date]).to include('must be in the future')
      end
    end
  end
  
  describe '#calculate_progress' do
    let(:milestone) { create(:milestone) }
    
    before do
      create_list(:task, 3, milestone: milestone, status: 'done')
      create_list(:task, 2, milestone: milestone, status: 'in_progress')
    end
    
    it 'calculates progress percentage' do
      expect(milestone.calculate_progress).to eq(60)
    end
  end
  
  describe '#is_at_risk?' do
    let(:milestone) { build(:milestone, target_date: 10.days.from_now) }
    
    context 'when deadline is near with low progress' do
      before { allow(milestone).to receive(:progress).and_return(30) }
      
      it 'returns true' do
        expect(milestone).to be_at_risk
      end
    end
    
    context 'when deadline is near with high progress' do
      before { allow(milestone).to receive(:progress).and_return(80) }
      
      it 'returns false' do
        expect(milestone).not_to be_at_risk
      end
    end
  end
end
```

#### Model Implementation with dry-validation

```ruby
# app/validators/milestone_validator.rb
require 'dry/validation'

class MilestoneValidator < Dry::Validation::Contract
  params do
    required(:name).filled(:string)
    required(:target_date).filled(:date)
    required(:service_id).filled(:integer)
    required(:organization_id).filled(:integer)
    optional(:description).maybe(:string)
    optional(:status).maybe(:string)
  end
  
  rule(:target_date) do
    if value && value < Date.current
      key.failure('must be in the future')
    end
  end
  
  rule(:status) do
    valid_statuses = %w[planning in_progress completed delayed cancelled]
    if value && !valid_statuses.include?(value.to_s)
      key.failure("must be one of: #{valid_statuses.join(', ')}")
    end
  end
end

# app/models/milestone.rb
class Milestone < ApplicationRecord
  acts_as_tenant :organization
  
  belongs_to :service
  belongs_to :organization
  has_many :milestone_epics, dependent: :destroy
  has_many :epics, through: :milestone_epics
  has_many :tasks
  
  enum :status, {
    planning: 0,
    in_progress: 1,
    completed: 2,
    delayed: 3,
    cancelled: 4
  }, default: :planning
  
  scope :upcoming, -> { where('target_date > ?', Date.current).order(:target_date) }
  scope :overdue, -> { where('target_date < ? AND status != ?', Date.current, statuses[:completed]) }
  
  before_validation :validate_with_contract
  
  def calculate_progress
    return 0 if tasks.none?
    completed_tasks = tasks.where(status: 'done').count
    total_tasks = tasks.count
    (completed_tasks.to_f / total_tasks * 100).round
  end
  
  def days_remaining
    (target_date - Date.current).to_i
  end
  
  def is_at_risk?
    days_remaining < 14 && progress < 70
  end
  
  def progress
    @progress ||= calculate_progress
  end
  
  private
  
  def validate_with_contract
    validator = MilestoneValidator.new
    result = validator.call(
      name: name,
      target_date: target_date,
      service_id: service_id,
      organization_id: organization_id,
      description: description,
      status: status
    )
    
    if result.failure?
      result.errors.to_h.each do |field, messages|
        errors.add(field, messages.join(', '))
      end
    end
  end
end
```

#### ViewComponent for Milestone Progress

```ruby
# spec/components/milestone_progress_component_spec.rb
require 'rails_helper'

RSpec.describe MilestoneProgressComponent, type: :component do
  let(:milestone) { build(:milestone, progress: 75, days_remaining: 5) }
  let(:component) { described_class.new(milestone: milestone) }
  
  describe 'rendering' do
    it 'displays progress percentage' do
      render_inline(component)
      expect(page).to have_text('75%')
    end
    
    it 'shows risk indicator when at risk' do
      allow(milestone).to receive(:is_at_risk?).and_return(true)
      render_inline(component)
      expect(page).to have_text('At Risk')
    end
    
    it 'shows days remaining' do
      render_inline(component)
      expect(page).to have_text('5 days remaining')
    end
  end
end

# app/components/milestone_progress_component.rb
class MilestoneProgressComponent < ViewComponent::Base
  attr_reader :milestone
  
  def initialize(milestone:)
    @milestone = milestone
  end
  
  def render?
    milestone.present?
  end
  
  def call
    tag.div(class: "milestone-progress", data: stimulus_data) do
      safe_join([
        status_badge,
        progress_bar,
        deadline_info,
        risk_indicator
      ])
    end
  end
  
  private
  
  def status_badge
    tag.span(milestone.status.humanize, class: status_classes)
  end
  
  def status_classes
    class_names(
      "px-2 py-1 text-sm font-medium rounded",
      {
        "bg-gray-100 text-gray-800" => milestone.planning?,
        "bg-blue-100 text-blue-800" => milestone.in_progress?,
        "bg-green-100 text-green-800" => milestone.completed?,
        "bg-yellow-100 text-yellow-800" => milestone.delayed?,
        "bg-red-100 text-red-800" => milestone.cancelled?
      }
    )
  end
  
  def progress_bar
    tag.div(class: "mt-2") do
      safe_join([
        tag.div(class: "flex justify-between mb-1") do
          safe_join([
            tag.span("Progress", class: "text-sm font-medium text-gray-700"),
            tag.span("#{milestone.progress}%", class: "text-sm font-medium text-gray-700")
          ])
        end,
        tag.div(class: "w-full bg-gray-200 rounded-full h-2.5") do
          tag.div(class: progress_bar_classes, style: "width: #{milestone.progress}%")
        end
      ])
    end
  end
  
  def progress_bar_classes
    if milestone.is_at_risk?
      "bg-red-600 h-2.5 rounded-full"
    elsif milestone.progress >= 70
      "bg-green-600 h-2.5 rounded-full"
    else
      "bg-blue-600 h-2.5 rounded-full"
    end
  end
  
  def deadline_info
    tag.div(class: "mt-2 text-sm text-gray-600") do
      if milestone.days_remaining > 0
        "#{milestone.days_remaining} days remaining"
      elsif milestone.days_remaining == 0
        tag.span("Due today", class: "text-orange-600 font-semibold")
      else
        tag.span("#{milestone.days_remaining.abs} days overdue", class: "text-red-600 font-semibold")
      end
    end
  end
  
  def risk_indicator
    return unless milestone.is_at_risk?
    
    tag.div(class: "mt-2 p-2 bg-red-50 border border-red-200 rounded") do
      safe_join([
        tag.span("⚠️", class: "mr-1"),
        tag.span("At Risk: ", class: "font-semibold text-red-800"),
        tag.span("Less than 14 days with low progress", class: "text-red-600 text-sm")
      ])
    end
  end
  
  def stimulus_data
    {
      controller: "milestone-progress",
      milestone_progress_id_value: milestone.id,
      milestone_progress_url_value: Rails.application.routes.url_helpers.milestone_path(milestone)
    }
  end
end
```

#### Alba Serializer

```ruby
# spec/serializers/milestone_serializer_spec.rb
require 'rails_helper'

RSpec.describe MilestoneSerializer do
  let(:milestone) { create(:milestone) }
  let(:serializer) { described_class.new(milestone) }
  
  describe 'serialization' do
    let(:json) { JSON.parse(serializer.serialize) }
    
    it 'includes required attributes' do
      expect(json).to include(
        'id' => milestone.id,
        'name' => milestone.name,
        'progress' => milestone.progress,
        'is_at_risk' => milestone.is_at_risk?
      )
    end
    
    it 'includes nested tasks when requested' do
      create_list(:task, 2, milestone: milestone)
      serializer = described_class.new(milestone, params: { include: ['tasks'] })
      json = JSON.parse(serializer.serialize)
      
      expect(json['tasks']).to have(2).items
    end
  end
end

# app/serializers/milestone_serializer.rb
class MilestoneSerializer
  include Alba::Resource
  
  root_key :milestone
  
  attributes :id, :name, :description, :target_date, :status
  
  attribute :progress do |milestone|
    milestone.calculate_progress
  end
  
  attribute :days_remaining do |milestone|
    milestone.days_remaining
  end
  
  attribute :is_at_risk do |milestone|
    milestone.is_at_risk?
  end
  
  has_many :tasks, resource: TaskSerializer, if: proc { |_, params|
    params[:include]&.include?('tasks')
  }
  
  has_many :epics, resource: EpicSerializer, if: proc { |_, params|
    params[:include]&.include?('epics')
  }
end
```

---

### STRUCT-002: Epic & Label System with Service Objects

#### BDD Spec

```ruby
# spec/services/epic_creation_service_spec.rb
require 'rails_helper'

RSpec.describe EpicCreationService do
  let(:organization) { create(:organization) }
  let(:service) { create(:service, organization: organization) }
  let(:params) do
    {
      name: 'Shopping Cart',
      color: '#FF5733',
      description: 'E-commerce shopping cart feature',
      service_id: service.id
    }
  end
  
  subject(:epic_service) do
    described_class.new(organization: organization, params: params)
  end
  
  describe '#call' do
    context 'with valid params' do
      it 'returns Success with epic' do
        result = epic_service.call
        
        expect(result).to be_success
        expect(result.value!).to be_a(Epic)
        expect(result.value!.name).to eq('Shopping Cart')
      end
      
      it 'creates label with epic type' do
        result = epic_service.call
        label = result.value!.label
        
        expect(label).to be_epic
        expect(label.color).to eq('#FF5733')
      end
    end
    
    context 'with invalid color' do
      let(:params) { super().merge(color: 'invalid') }
      
      it 'returns Failure' do
        result = epic_service.call
        
        expect(result).to be_failure
        expect(result.failure).to include(:validation_error)
      end
    end
    
    context 'with duplicate name' do
      before do
        create(:label, name: 'Shopping Cart', organization: organization)
      end
      
      it 'returns Failure' do
        result = epic_service.call
        
        expect(result).to be_failure
        expect(result.failure).to include(:duplicate_name)
      end
    end
  end
end
```

#### Service Object Implementation

```ruby
# app/services/epic_creation_service.rb
require 'dry/monads'
require 'dry/monads/do'

class EpicCreationService
  include Dry::Monads[:result, :do]
  
  pattr_initialize [:organization!, :params!]
  memo_wise :label_validator
  memo_wise :epic_validator
  
  def call
    validated_label = yield validate_label
    validated_epic = yield validate_epic
    label = yield create_label(validated_label)
    epic = yield create_epic(label, validated_epic)
    
    Success(epic)
  rescue ActiveRecord::RecordInvalid => e
    Failure([:record_invalid, e.message])
  rescue => e
    Failure([:unexpected_error, e.message])
  end
  
  private
  
  memo_wise
  def label_validator
    LabelValidator.new
  end
  
  memo_wise
  def epic_validator
    EpicValidator.new
  end
  
  def validate_label
    result = label_validator.call(
      name: params[:name],
      color: params[:color],
      description: params[:description],
      organization_id: organization.id,
      label_type: 'epic'
    )
    
    if result.success?
      Success(result.to_h)
    else
      Failure([:validation_error, result.errors.to_h])
    end
  end
  
  def validate_epic
    result = epic_validator.call(
      service_id: params[:service_id],
      milestone_id: params[:milestone_id]
    )
    
    if result.success?
      Success(result.to_h)
    else
      Failure([:validation_error, result.errors.to_h])
    end
  end
  
  def create_label(validated_data)
    label = organization.labels.build(validated_data)
    
    if label.save
      Success(label)
    else
      Failure([:label_creation_failed, label.errors.full_messages])
    end
  end
  
  def create_epic(label, validated_data)
    epic = Epic.new(validated_data.merge(label: label))
    
    if epic.save
      Success(epic)
    else
      Failure([:epic_creation_failed, epic.errors.full_messages])
    end
  end
end

# app/validators/epic_validator.rb
require 'dry/validation'

class EpicValidator < Dry::Validation::Contract
  params do
    required(:service_id).filled(:integer)
    optional(:milestone_id).maybe(:integer)
    optional(:status).maybe(:string)
  end
  
  rule(:service_id) do
    unless Service.exists?(id: value)
      key.failure('service does not exist')
    end
  end
  
  rule(:milestone_id) do
    if value && !Milestone.exists?(id: value)
      key.failure('milestone does not exist')
    end
  end
end

# app/validators/label_validator.rb
require 'dry/validation'

class LabelValidator < Dry::Validation::Contract
  params do
    required(:name).filled(:string)
    required(:organization_id).filled(:integer)
    required(:label_type).filled(:string)
    optional(:color).maybe(:string)
    optional(:description).maybe(:string)
  end
  
  rule(:color) do
    if value && !value.match?(/\A#[0-9A-F]{6}\z/i)
      key.failure('must be a valid hex color code (e.g., #FF5733)')
    end
  end
  
  rule(:label_type) do
    valid_types = %w[epic category priority status custom]
    unless valid_types.include?(value)
      key.failure("must be one of: #{valid_types.join(', ')}")
    end
  end
  
  rule(:name, :organization_id) do
    if Label.exists?(name: values[:name], organization_id: values[:organization_id])
      key(:name).failure('has already been taken for this organization')
    end
  end
end
```

---

### STRUCT-003: Task ID Generation Service

#### BDD Spec

```ruby
# spec/services/task_id_generator_service_spec.rb
require 'rails_helper'

RSpec.describe TaskIdGeneratorService do
  let(:service) { create(:service, key: 'SHOP', task_counter: 141) }
  let(:task) { build(:task, service: service) }
  
  subject(:generator) { described_class.new(task: task) }
  
  describe '#call' do
    context 'when task has no ID' do
      it 'generates sequential task ID' do
        result = generator.call
        
        expect(result).to be_success
        expect(result.value!).to eq('SHOP-142')
      end
      
      it 'increments service counter' do
        expect { generator.call }.to change { service.reload.task_counter }.from(141).to(142)
      end
    end
    
    context 'when task already has ID' do
      before { task.task_id = 'CUSTOM-001' }
      
      it 'keeps existing ID' do
        result = generator.call
        
        expect(result).to be_success
        expect(result.value!).to eq('CUSTOM-001')
      end
      
      it 'does not increment counter' do
        expect { generator.call }.not_to change { service.reload.task_counter }
      end
    end
    
    context 'when concurrent generation occurs' do
      it 'handles race condition safely' do
        results = []
        threads = []
        
        5.times do
          threads << Thread.new do
            new_task = build(:task, service: service)
            result = described_class.new(task: new_task).call
            results << result.value!
          end
        end
        
        threads.each(&:join)
        
        expect(results.uniq.size).to eq(5)
        expect(results).to include('SHOP-142', 'SHOP-143', 'SHOP-144', 'SHOP-145', 'SHOP-146')
      end
    end
  end
end
```

#### Service Implementation

```ruby
# app/services/task_id_generator_service.rb
require 'dry/monads'
require 'dry/monads/do'

class TaskIdGeneratorService
  include Dry::Monads[:result, :do]
  
  pattr_initialize [:task!]
  
  def call
    return Success(task.task_id) if task.task_id.present?
    
    sequence_number = yield increment_counter
    task_id = yield generate_id(sequence_number)
    yield assign_to_task(task_id, sequence_number)
    
    Success(task_id)
  rescue ActiveRecord::RecordNotUnique => e
    retry_count ||= 0
    retry_count += 1
    retry if retry_count < 3
    Failure([:generation_failed, e.message])
  rescue => e
    Failure([:unexpected_error, e.message])
  end
  
  private
  
  def increment_counter
    service = task.service
    
    service.with_lock do
      service.task_counter ||= 0
      service.task_counter += 1
      service.save!
      Success(service.task_counter)
    end
  rescue ActiveRecord::RecordInvalid => e
    Failure([:counter_increment_failed, e.message])
  end
  
  def generate_id(sequence_number)
    prefix = task.service.key.presence || 'TASK'
    padded_number = sequence_number.to_s.rjust(3, '0')
    Success("#{prefix}-#{padded_number}")
  end
  
  def assign_to_task(task_id, sequence_number)
    task.task_id = task_id
    task.sequence_number = sequence_number
    Success(task)
  end
end

# app/models/task.rb with callback
class Task < ApplicationRecord
  acts_as_tenant :organization
  
  before_create :generate_task_id
  
  private
  
  def generate_task_id
    return if task_id.present?
    
    result = TaskIdGeneratorService.new(task: self).call
    
    if result.failure?
      errors.add(:task_id, "generation failed: #{result.failure}")
      throw :abort
    end
  end
end
```

---

### STRUCT-004: GitHub Integration Service with Octokit & JWT

#### BDD Spec

```ruby
# spec/services/github_integration_service_spec.rb
require 'rails_helper'

RSpec.describe GitHubIntegrationService do
  let(:service) { create(:service, :with_github_app) }
  
  subject(:github_service) do
    described_class.new(service: service)
  end
  
  describe '#sync_issues' do
    let(:mock_issues) do
      [
        double(
          number: 42,
          title: 'Fix bug in checkout',
          body: 'Description here',
          state: 'open',
          html_url: 'https://github.com/org/repo/issues/42',
          labels: [double(name: 'bug'), double(name: 'epic:shopping-cart')],
          assignee: double(login: 'developer', email: 'dev@example.com')
        )
      ]
    end
    
    before do
      allow_any_instance_of(Octokit::Client).to receive(:issues).and_return(mock_issues)
    end
    
    it 'creates tasks from GitHub issues' do
      result = github_service.sync_issues
      
      expect(result).to be_success
      expect(Task.count).to eq(1)
      
      task = Task.first
      expect(task.github_issue_number).to eq(42)
      expect(task.title).to eq('Fix bug in checkout')
    end
    
    it 'maps GitHub labels to epic labels' do
      result = github_service.sync_issues
      
      task = Task.first
      expect(task.labels.map(&:name)).to include('shopping-cart')
    end
  end
  
  describe '#create_github_issue' do
    let(:task) { create(:task, service: service) }
    
    before do
      stub_request(:post, /api.github.com\/repos\/.*\/issues/)
        .to_return(
          status: 201,
          body: { number: 123, html_url: 'https://github.com/org/repo/issues/123' }.to_json
        )
    end
    
    it 'creates issue on GitHub' do
      result = github_service.create_github_issue(task)
      
      expect(result).to be_success
      expect(task.reload.github_issue_number).to eq(123)
    end
  end
  
  describe 'JWT authentication' do
    it 'generates valid JWT token' do
      authenticator = GitHubAppAuthenticator.new(
        app_id: service.github_app_id,
        private_key: service.github_private_key
      )
      
      jwt = authenticator.generate_jwt
      decoded = JWT.decode(jwt, service.github_private_key_public, true, algorithm: 'RS256')
      
      expect(decoded.first['iss']).to eq(service.github_app_id.to_s)
    end
  end
end
```

#### Service Implementation with dry-monads

```ruby
# app/services/github_integration_service.rb
require 'dry/monads'
require 'dry/monads/do'

class GitHubIntegrationService
  include Dry::Monads[:result, :do]
  
  pattr_initialize [:service!]
  memo_wise :github_client
  memo_wise :repository_name
  
  def sync_issues
    client = yield get_github_client
    issues = yield fetch_issues(client)
    tasks = yield process_issues(issues)
    
    Success(tasks)
  rescue Octokit::Error => e
    Failure([:github_error, e.message])
  rescue => e
    Failure([:unexpected_error, e.message])
  end
  
  def sync_pull_requests
    client = yield get_github_client
    pulls = yield fetch_pull_requests(client)
    tasks = yield process_pull_requests(pulls)
    
    Success(tasks)
  rescue Octokit::Error => e
    Failure([:github_error, e.message])
  end
  
  def create_github_issue(task)
    client = yield get_github_client
    issue = yield create_issue(client, task)
    yield update_task_with_issue(task, issue)
    
    Success(task)
  rescue Octokit::Error => e
    Failure([:github_error, e.message])
  end
  
  private
  
  memo_wise
  def github_client
    @github_client ||= if service.github_app_configured?
      authenticator = GitHubAppAuthenticator.new(
        app_id: service.github_app_id,
        private_key: service.github_private_key
      )
      authenticator.installation_client(service.github_app_installation_id)
    elsif service.github_token.present?
      Octokit::Client.new(access_token: service.github_token)
    end
  end
  
  memo_wise
  def repository_name
    service.github_repo_url&.match(%r{github\.com/([^/]+/[^/]+)})&.[](1)
  end
  
  def get_github_client
    if github_client
      Success(github_client)
    else
      Failure([:not_configured, 'GitHub integration not configured'])
    end
  end
  
  def fetch_issues(client)
    issues = client.issues(repository_name, state: 'all')
    Success(issues.reject(&:pull_request))
  rescue => e
    Failure([:fetch_failed, e.message])
  end
  
  def process_issues(issues)
    tasks = issues.map do |issue|
      process_single_issue(issue)
    end
    
    Success(tasks.compact)
  end
  
  def process_single_issue(issue)
    task = service.tasks.find_or_initialize_by(github_issue_number: issue.number)
    
    epic_label = issue.labels.find { |l| l.name.start_with?('epic:') }
    epic_name = epic_label&.name&.gsub('epic:', '') if epic_label
    
    task.assign_attributes(
      title: issue.title,
      description: issue.body,
      github_issue_url: issue.html_url,
      status: map_issue_state(issue.state)
    )
    
    if epic_name
      epic = find_or_create_epic(epic_name)
      task.labels << epic.label unless task.labels.include?(epic.label)
    end
    
    task.save!
    task
  rescue => e
    Rails.logger.error("Failed to process issue ##{issue.number}: #{e.message}")
    nil
  end
  
  def fetch_pull_requests(client)
    pulls = client.pull_requests(repository_name, state: 'all')
    Success(pulls)
  rescue => e
    Failure([:fetch_failed, e.message])
  end
  
  def process_pull_requests(pulls)
    tasks = pulls.map do |pr|
      process_single_pr(pr)
    end
    
    Success(tasks.compact)
  end
  
  def process_single_pr(pr)
    task = find_task_for_pr(pr)
    return nil unless task
    
    task.update!(
      github_pr_number: pr.number,
      github_pr_url: pr.html_url,
      github_branch_name: pr.head.ref,
      status: map_pr_state(pr)
    )
    
    task
  rescue => e
    Rails.logger.error("Failed to process PR ##{pr.number}: #{e.message}")
    nil
  end
  
  def create_issue(client, task)
    issue = client.create_issue(
      repository_name,
      "#{task.task_id}: #{task.title}",
      task.description,
      labels: task_labels(task)
    )
    
    Success(issue)
  rescue => e
    Failure([:creation_failed, e.message])
  end
  
  def update_task_with_issue(task, issue)
    task.update!(
      github_issue_number: issue.number,
      github_issue_url: issue.html_url
    )
    
    Success(task)
  rescue => e
    Failure([:update_failed, e.message])
  end
  
  def find_task_for_pr(pr)
    if pr.head.ref =~ /#{service.key}-(\d+)/i
      task_number = $1.to_i
      service.tasks.find_by(sequence_number: task_number)
    elsif pr.body =~ /(?:fixes|closes|resolves)\s+#?#{service.key}-(\d+)/i
      task_number = $1.to_i
      service.tasks.find_by(sequence_number: task_number)
    end
  end
  
  def find_or_create_epic(name)
    label = service.organization.labels.epics.find_or_create_by(name: name) do |l|
      l.label_type = 'epic'
      l.color = generate_color_for_epic(name)
    end
    
    Epic.find_or_create_by(label: label, service: service)
  end
  
  def task_labels(task)
    labels = []
    labels << "priority:#{task.priority}" if task.priority.present?
    labels << "status:#{task.status}" if task.status.present?
    
    task.labels.each do |label|
      if label.epic?
        labels << "epic:#{label.name}"
      else
        labels << label.name
      end
    end
    
    labels
  end
  
  def map_issue_state(state)
    case state
    when 'open' then 'open'
    when 'closed' then 'completed'
    else 'open'
    end
  end
  
  def map_pr_state(pr)
    if pr.merged
      'completed'
    elsif pr.state == 'closed'
      'cancelled'
    elsif pr.draft
      'in_progress'
    else
      'review'
    end
  end
  
  def generate_color_for_epic(name)
    colors = ['#FF5733', '#33FF57', '#3357FF', '#F333FF', '#33FFF3']
    colors[name.hash % colors.length]
  end
end

# app/services/github_app_authenticator.rb
require 'jwt'
require 'octokit'

class GitHubAppAuthenticator
  pattr_initialize [:app_id!, :private_key!]
  memo_wise :rsa_key
  
  def generate_jwt
    payload = {
      iat: Time.now.to_i,
      exp: Time.now.to_i + (10 * 60),
      iss: app_id.to_s
    }
    
    JWT.encode(payload, rsa_key, 'RS256')
  end
  
  def app_client
    Octokit::Client.new(bearer_token: generate_jwt)
  end
  
  def installation_client(installation_id)
    response = app_client.create_app_installation_access_token(installation_id)
    Octokit::Client.new(access_token: response.token)
  end
  
  private
  
  memo_wise
  def rsa_key
    OpenSSL::PKey::RSA.new(private_key)
  end
end
```

---

### CAL-001: Calendar Service with dry-monads & icalendar

#### BDD Spec

```ruby
# spec/services/task_calendar_service_spec.rb
require 'rails_helper'

RSpec.describe TaskCalendarService do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:sprint) { create(:sprint, organization: organization) }
  let(:filters) { { sprint_id: sprint.id } }
  
  subject(:calendar_service) do
    described_class.new(
      user: user,
      organization: organization,
      filters: filters
    )
  end
  
  describe '#call' do
    context 'with valid data' do
      before do
        create_list(:task, 3, sprint: sprint, assignee: user)
        create_list(:milestone, 2, service: sprint.service)
      end
      
      it 'generates valid iCalendar' do
        result = calendar_service.call
        
        expect(result).to be_success
        
        ics = result.value!
        expect(ics).to include('BEGIN:VCALENDAR')
        expect(ics).to include('BEGIN:VEVENT')
        expect(ics).to include('END:VCALENDAR')
      end
      
      it 'includes tasks in calendar' do
        result = calendar_service.call
        ics = result.value!
        
        Task.all.each do |task|
          expect(ics).to include(task.task_id)
        end
      end
      
      it 'includes sprint events' do
        result = calendar_service.call
        ics = result.value!
        
        expect(ics).to include("Sprint Start: #{sprint.name}")
      end
    end
    
    context 'with error' do
      before do
        allow_any_instance_of(Icalendar::Calendar).to receive(:to_ical).and_raise(StandardError)
      end
      
      it 'returns Failure' do
        result = calendar_service.call
        
        expect(result).to be_failure
        expect(result.failure).to include(:calendar_error)
      end
    end
  end
end
```

#### Service Implementation

```ruby
# app/services/task_calendar_service.rb
require 'dry/monads'
require 'dry/monads/do'

class TaskCalendarService
  include Dry::Monads[:result, :do]
  
  pattr_initialize [:user!, :organization!, :filters]
  memo_wise :tasks_scope
  
  def call
    calendar = yield create_calendar
    yield add_tasks(calendar)
    yield add_sprints(calendar) 
    yield add_milestones(calendar)
    
    Success(calendar.to_ical)
  rescue => e
    Failure([:calendar_error, e.message])
  end
  
  private
  
  def create_calendar
    cal = Icalendar::Calendar.new
    cal.append_custom_property("X-WR-CALNAME", calendar_name)
    cal.append_custom_property("X-WR-TIMEZONE", "Asia/Seoul")
    cal.append_custom_property("X-WR-CALDESC", "Creatia Project Management")
    
    Success(cal)
  rescue => e
    Failure([:setup_error, e.message])
  end
  
  def add_tasks(calendar)
    tasks_scope.find_each do |task|
      event = build_task_event(task)
      calendar.add_event(event)
    end
    
    Success(calendar)
  rescue => e
    Failure([:task_error, e.message])
  end
  
  def add_sprints(calendar)
    Sprint.current.find_each do |sprint|
      add_sprint_events(calendar, sprint)
    end
    
    Success(calendar)
  rescue => e
    Failure([:sprint_error, e.message])
  end
  
  def add_milestones(calendar)
    Milestone.upcoming.find_each do |milestone|
      event = build_milestone_event(milestone)
      calendar.add_event(event)
    end
    
    Success(calendar)
  rescue => e
    Failure([:milestone_error, e.message])
  end
  
  memo_wise
  def tasks_scope
    scope = user.assigned_tasks.includes(:sprint, :epic, :service)
    scope = scope.where(sprint_id: filters[:sprint_id]) if filters&.dig(:sprint_id)
    scope = scope.where(service_id: filters[:service_id]) if filters&.dig(:service_id)
    scope
  end
  
  def calendar_name
    if filters&.dig(:sprint_id)
      "Sprint Calendar - #{Sprint.find(filters[:sprint_id]).name}"
    elsif filters&.dig(:service_id)
      "Service Calendar - #{Service.find(filters[:service_id]).name}"
    else
      "#{user.name} - Creatia Tasks"
    end
  end
  
  def build_task_event(task)
    Icalendar::Event.new.tap do |e|
      e.dtstart = Icalendar::Values::DateTime.new(task.start_time || task.created_at)
      e.dtend = Icalendar::Values::DateTime.new(task.deadline || task.start_time + 1.hour)
      e.summary = "#{task.task_id}: #{task.title}"
      e.description = task.description
      e.uid = "task-#{task.id}@creatia.io"
      
      # 우선순위별 색상
      e.append_custom_property("COLOR", urgency_color(task))
      
      # 알림 추가
      add_alarms(e, task) if task.deadline
    end
  end
  
  def build_milestone_event(milestone)
    Icalendar::Event.new.tap do |e|
      e.dtstart = Icalendar::Values::Date.new(milestone.target_date)
      e.dtend = Icalendar::Values::Date.new(milestone.target_date)
      e.summary = "🎯 Milestone: #{milestone.name}"
      e.description = "Progress: #{milestone.progress}%\n#{milestone.description}"
      e.categories = ["milestone", milestone.status]
    end
  end
  
  def add_sprint_events(calendar, sprint)
    # Sprint 시작 이벤트
    calendar.event do |e|
      e.dtstart = sprint.start_date
      e.summary = "🚀 Sprint Start: #{sprint.name}"
      e.description = "Sprint Goal: #{sprint.goal}"
    end
    
    # Daily Standup 반복 이벤트
    add_recurring_standup(calendar, sprint) if sprint.daily_standup_time
    
    # Sprint Review 이벤트
    add_sprint_review(calendar, sprint) if sprint.review_meeting_time
  end
  
  def add_recurring_standup(calendar, sprint)
    schedule = IceCube::Schedule.new(sprint.start_date) do |s|
      s.add_recurrence_rule(
        IceCube::Rule.daily
          .hour_of_day(sprint.daily_standup_time.hour)
          .minute_of_hour(sprint.daily_standup_time.min)
          .until(sprint.end_date)
      )
    end
    
    schedule.all_occurrences.each do |occurrence|
      calendar.event do |e|
        e.dtstart = occurrence
        e.dtend = occurrence + 15.minutes
        e.summary = "📊 Daily Standup"
      end
    end
  end
  
  def add_sprint_review(calendar, sprint)
    calendar.event do |e|
      e.dtstart = sprint.review_meeting_time
      e.dtend = sprint.review_meeting_time + 2.hours
      e.summary = "📝 Sprint Review: #{sprint.name}"
    end
  end
  
  def urgency_color(task)
    {
      critical: "#FF0000",
      high: "#FFA500", 
      medium: "#FFFF00",
      low: "#00FF00"
    }[task.urgency_level] || "#0099FF"
  end
  
  def add_alarms(event, task)
    # 1시간 전 알림
    event.alarm do |a|
      a.action = "DISPLAY"
      a.summary = "Task deadline in 1 hour"
      a.trigger = "-PT1H"
    end
    
    # 긴급 작업은 하루 전 알림 추가
    if [:critical, :high].include?(task.urgency_level)
      event.alarm do |a|
        a.action = "DISPLAY"
        a.summary = "Task deadline tomorrow"
        a.trigger = "-PT24H"
      end
    end
  end
end
```

---

### Authorization with Pundit

#### BDD Spec

```ruby
# spec/policies/task_policy_spec.rb
require 'rails_helper'

RSpec.describe TaskPolicy do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:task) { create(:task, organization: organization) }
  
  subject { described_class.new(user, task) }
  
  describe 'permissions' do
    context 'for organization member' do
      it { is_expected.to permit_action(:show) }
      it { is_expected.to permit_action(:create) }
    end
    
    context 'for task assignee' do
      let(:task) { create(:task, assignee: user, organization: organization) }
      
      it { is_expected.to permit_action(:update) }
      it { is_expected.to permit_action(:complete) }
    end
    
    context 'for admin' do
      let(:user) { create(:user, :admin, organization: organization) }
      
      it { is_expected.to permit_action(:destroy) }
      it { is_expected.to permit_action(:reassign) }
    end
    
    context 'for outsider' do
      let(:other_org) { create(:organization) }
      let(:user) { create(:user, organization: other_org) }
      
      it { is_expected.not_to permit_action(:show) }
      it { is_expected.not_to permit_action(:update) }
    end
  end
  
  describe 'scopes' do
    let!(:assigned_task) { create(:task, assignee: user, organization: organization) }
    let!(:team_task) { create(:task, organization: organization) }
    let!(:other_org_task) { create(:task) }
    
    it 'returns organization tasks' do
      policy_scope = Pundit.policy_scope(user, Task)
      
      expect(policy_scope).to include(assigned_task, team_task)
      expect(policy_scope).not_to include(other_org_task)
    end
  end
end
```

#### Policy Implementation

```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :user, :record
  
  def initialize(user, record)
    @user = user
    @record = record
  end
  
  def index?
    false
  end
  
  def show?
    false
  end
  
  def create?
    false
  end
  
  def new?
    create?
  end
  
  def update?
    false
  end
  
  def edit?
    update?
  end
  
  def destroy?
    false
  end
  
  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end
    
    def resolve
      raise NotImplementedError
    end
    
    private
    
    attr_reader :user, :scope
  end
end

# app/policies/task_policy.rb
class TaskPolicy < ApplicationPolicy
  def show?
    user.organization_id == record.organization_id
  end
  
  def create?
    user.organization_id == record.organization_id
  end
  
  def update?
    user.organization_id == record.organization_id &&
      (user == record.assignee || user.admin? || user.team_lead?)
  end
  
  def destroy?
    user.organization_id == record.organization_id && user.admin?
  end
  
  def complete?
    user == record.assignee
  end
  
  def reassign?
    user.organization_id == record.organization_id &&
      (user.admin? || user.team_lead?)
  end
  
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization_id: user.organization_id)
    end
  end
end

# app/policies/milestone_policy.rb
class MilestonePolicy < ApplicationPolicy
  def show?
    user.organization_id == record.organization_id
  end
  
  def create?
    user.organization_id == record.organization_id &&
      (user.admin? || user.project_manager?)
  end
  
  def update?
    user.organization_id == record.organization_id &&
      (user.admin? || user.project_manager?)
  end
  
  def destroy?
    user.organization_id == record.organization_id && user.admin?
  end
  
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization_id: user.organization_id)
    end
  end
end
```

---

## 🔄 구현 순서 (BDD Approach)

### Phase 1: 기본 구조 완성 (1주)

1. **Gem 설치 및 설정**
   - 누락된 gem 추가
   - RSpec 설정
   
2. **STRUCT-001: Milestone**
   - RSpec 테스트 작성
   - dry-validation validator 구현
   - ViewComponent 구현
   - Alba serializer 구현
   
3. **STRUCT-002: Epic & Label**
   - RSpec 테스트 작성
   - Service object (dry-monads) 구현
   - dry-validation 적용
   
4. **STRUCT-003: Task ID**
   - RSpec 테스트 작성
   - Service object 구현

### Phase 2: 통합 기능 (1주)

5. **STRUCT-004: GitHub 연결**
   - RSpec 테스트 작성
   - Octokit + JWT 통합
   - Service object 구현
   
6. **CAL-001: ICS 달력**
   - RSpec 테스트 작성
   - icalendar gem 활용
   - dry-monads service 구현
   
7. **Authorization**
   - Pundit policies 구현
   - Policy specs 작성

### Phase 3: 고급 기능 (선택)

8. **CAL-003: Google Calendar**
   - OAuth 통합
   - 동기화 service 구현

---

## 📊 테스트 커버리지 목표

| Component | Coverage Target | Test Types |
|-----------|----------------|------------|
| Models | 100% | Unit (RSpec) |
| Services | 100% | Unit + Integration |
| Validators | 100% | Unit |
| ViewComponents | 95% | Component tests |
| Serializers | 95% | Unit |
| Policies | 100% | Unit |
| Controllers | 90% | Request specs |
| System | 80% | E2E (Playwright) |

---

## 🚀 Definition of Done

- [ ] RSpec 테스트 작성 완료 (BDD)
- [ ] 모든 Service object에 dry-monads 적용
- [ ] dry-validation으로 validation 구현
- [ ] ViewComponent로 UI 컴포넌트 구현
- [ ] Alba로 JSON serialization
- [ ] Pundit으로 authorization
- [ ] 테스트 커버리지 목표 달성
- [ ] 문서 업데이트