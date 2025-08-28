# 프로젝트 구조 완성 작업

## 🎯 Epic: Project Structure Completion

### 목표

Creatia 프로젝트 구조를 문서(`docs/project_hierarchy_structure.md`)와 100% 일치시키고, 달력 통합 기능을 추가합니다.

### 현재 상태

- ✅ 구현 완료: Organization, Service, Sprint, Task, Team
- ❌ 미구현: Milestone, Epic Label, Label 시스템, Task ID 체계

---

## 📋 필수 구현 작업

### STRUCT-001: Milestone 모델 구현

**Priority**: High  
**Assignee**: Backend  
**Status**: Pending  
**Story Points**: 5

#### User Story

```
As a project manager
I want to set milestones for important releases
So that I can track long-term project progress
```

#### Technical Tasks

```bash
# 1. 모델 생성
bin/rails generate model Milestone \
  service:references \
  name:string \
  description:text \
  target_date:date \
  status:integer \
  progress:integer

# 2. 마이그레이션 추가
add_index :milestones, [:service_id, :target_date]
```

#### 구현 코드

```ruby
# app/models/milestone.rb
class Milestone < ApplicationRecord
  # Multi-tenancy
  acts_as_tenant :organization

  # Associations
  belongs_to :service
  belongs_to :organization
  has_many :milestone_epics, dependent: :destroy
  has_many :epics, through: :milestone_epics
  has_many :tasks

  # Enums
  enum :status, {
    planning: 0,
    in_progress: 1,
    completed: 2,
    delayed: 3,
    cancelled: 4
  }, default: :planning

  # Validations
  validates :name, presence: true
  validates :target_date, presence: true
  validate :target_date_must_be_future, on: :create

  # Scopes
  scope :upcoming, -> { where('target_date > ?', Date.current).order(:target_date) }
  scope :overdue, -> { where('target_date < ? AND status != ?', Date.current, statuses[:completed]) }

  # Methods
  def calculate_progress
    return 0 if tasks.none?
    completed_tasks = tasks.where(status: 'done').count
    total_tasks = tasks.count
    (completed_tasks.to_f / total_tasks * 100).round
  end

  def days_remaining
    return 0 if target_date < Date.current
    (target_date - Date.current).to_i
  end

  def is_at_risk?
    days_remaining < 14 && progress < 70
  end
end
```

---

### STRUCT-002: Epic & Label 시스템 구현

**Priority**: High  
**Assignee**: Backend  
**Status**: Pending  
**Story Points**: 8

#### User Story

```
As a team lead
I want to group related tasks into epics
So that I can track feature-level progress
```

#### Technical Tasks

```bash
# 1. Label 모델 생성 (다형성)
bin/rails generate model Label \
  name:string \
  color:string \
  label_type:integer \
  description:text \
  organization:references

# 2. Epic 라벨 타입 추가
bin/rails generate model Epic \
  label:references \
  service:references \
  milestone:references \
  progress:integer \
  status:integer

# 3. Task-Label 연결 테이블
bin/rails generate model TaskLabel \
  task:references \
  label:references
```

#### 구현 코드

```ruby
# app/models/label.rb
class Label < ApplicationRecord
  # Multi-tenancy
  acts_as_tenant :organization

  # Associations
  belongs_to :organization
  has_many :task_labels, dependent: :destroy
  has_many :tasks, through: :task_labels
  has_one :epic, dependent: :destroy

  # Enums
  enum :label_type, {
    epic: 0,        # 에픽 (큰 기능)
    category: 1,    # 카테고리 (frontend, backend)
    priority: 2,    # 우선순위 (urgent, high)
    status: 3,      # 상태 (blocked, review)
    custom: 4       # 커스텀
  }, default: :custom

  # Validations
  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :color, format: { with: /\A#[0-9A-F]{6}\z/i }, allow_blank: true

  # Scopes
  scope :epics, -> { where(label_type: :epic) }
  scope :categories, -> { where(label_type: :category) }

  # Methods
  def epic?
    label_type == 'epic'
  end

  def task_count
    tasks.count
  end

  def completed_task_count
    tasks.where(status: 'done').count
  end

  def progress_percentage
    return 0 if task_count == 0
    (completed_task_count.to_f / task_count * 100).round
  end
end

# app/models/epic.rb
class Epic < ApplicationRecord
  # Associations
  belongs_to :label
  belongs_to :service
  belongs_to :milestone, optional: true
  has_many :tasks, through: :label

  # Delegations
  delegate :name, :color, :description, to: :label
  delegate :organization, to: :service

  # Enums
  enum :status, {
    backlog: 0,
    planned: 1,
    in_progress: 2,
    completed: 3
  }, default: :backlog

  # Validations
  validates :label, uniqueness: true
  validate :label_must_be_epic_type

  # Callbacks
  before_validation :ensure_epic_label

  # Methods
  def story_points_total
    tasks.sum(:story_points)
  end

  def story_points_completed
    tasks.where(status: 'done').sum(:story_points)
  end

  def velocity
    story_points_completed
  end

  def burndown_data
    # Groupdate를 활용한 번다운 데이터
    tasks.group_by_day(:completed_at).count
  end

  private

  def ensure_epic_label
    label.label_type = 'epic' if label
  end

  def label_must_be_epic_type
    errors.add(:label, "must be epic type") unless label&.epic?
  end
end
```

---

### STRUCT-003: Task ID 자동 생성 시스템

**Priority**: High  
**Assignee**: Backend  
**Status**: Pending  
**Story Points**: 3

#### User Story

```
As a developer
I want tasks to have unique IDs like SHOP-142
So that I can easily reference them in commits and communications
```

#### Technical Tasks

```bash
# 1. Task 모델에 필드 추가
bin/rails generate migration AddTaskIdToTasks \
  task_id:string:index \
  sequence_number:integer

# 2. Service에 시퀀스 카운터 추가
bin/rails generate migration AddTaskCounterToServices \
  task_counter:integer
```

#### 구현 코드

```ruby
# app/models/task.rb
class Task < ApplicationRecord
  # 기존 코드...

  # Callbacks
  before_create :generate_task_id

  # Validations
  validates :task_id, presence: true, uniqueness: true

  private

  def generate_task_id
    return if task_id.present?

    self.sequence_number = service.increment_task_counter!
    self.task_id = "#{service.key}-#{sequence_number.to_s.rjust(3, '0')}"
  end
end

# app/models/service.rb
class Service < ApplicationRecord
  # 기존 코드...

  def increment_task_counter!
    with_lock do
      self.task_counter ||= 0
      self.task_counter += 1
      save!
      task_counter
    end
  end

  def next_task_id_preview
    "#{key}-#{(task_counter || 0) + 1}"
  end
end
```

---

### STRUCT-004: GitHub 저장소 연결 (Octokit 활용)

**Priority**: High  
**Assignee**: Backend  
**Status**: Pending  
**Story Points**: 8

#### User Story

```
As a developer
I want to connect GitHub repositories to services using Octokit gem
So that tasks can be synchronized with GitHub issues, PRs, and commits
```

#### Acceptance Criteria
- [ ] Service에 GitHub repository URL 필드 추가
- [ ] Task와 GitHub issue 연동 (Octokit gem 사용)
- [ ] Commit과 Task 자동 연결 (Git gem 사용)
- [ ] PR과 Task 연동 (Webhook 처리)
- [ ] JWT 인증 지원 (GitHub Apps)

#### Technical Implementation

```ruby
# Migration: Add GitHub fields to Service
class AddGitHubFieldsToService < ActiveRecord::Migration[8.0]
  def change
    add_column :services, :github_repo_url, :string
    add_column :services, :github_token_encrypted, :string
    add_column :services, :github_app_id, :integer
    add_column :services, :github_app_installation_id, :integer
    add_column :services, :github_private_key_encrypted, :text
    add_index :services, :github_repo_url
    add_index :services, :github_app_installation_id
  end
end

# Migration: Add GitHub fields to Task
class AddGitHubFieldsToTask < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :github_issue_number, :integer
    add_column :tasks, :github_issue_url, :string
    add_column :tasks, :github_pr_number, :integer
    add_column :tasks, :github_pr_url, :string
    add_column :tasks, :github_branch_name, :string
    add_index :tasks, :github_issue_number
    add_index :tasks, :github_pr_number
  end
end

# app/models/service.rb
class Service < ApplicationRecord
  acts_as_tenant :organization
  
  # GitHub integration
  encrypts :github_token
  encrypts :github_private_key
  
  validates :github_repo_url, format: { 
    with: %r{\Ahttps?://github\.com/[\w-]+/[\w-]+\z},
    message: "must be a valid GitHub repository URL"
  }, allow_blank: true
  
  def github_repo_name
    return nil unless github_repo_url.present?
    github_repo_url.match(%r{github\.com/([^/]+/[^/]+)})&.[](1)
  end
  
  def github_client
    @github_client ||= if github_app_configured?
      # GitHub App 인증 (JWT 사용)
      jwt_client = GitHubAppAuthenticator.new(
        app_id: github_app_id,
        private_key: github_private_key
      )
      jwt_client.installation_client(github_app_installation_id)
    elsif github_token.present?
      # Personal Access Token 인증
      Octokit::Client.new(access_token: github_token)
    end
  end
  
  def sync_with_github
    return unless github_configured?
    GitHubSyncJob.perform_later(self)
  end
  
  def github_configured?
    github_repo_url.present? && (github_token.present? || github_app_configured?)
  end
  
  def github_app_configured?
    github_app_id.present? && github_app_installation_id.present? && github_private_key.present?
  end
end

# app/services/github_app_authenticator.rb
require 'jwt'
require 'octokit'

class GitHubAppAuthenticator
  def initialize(app_id:, private_key:)
    @app_id = app_id
    @private_key = OpenSSL::PKey::RSA.new(private_key)
  end
  
  def generate_jwt
    payload = {
      iat: Time.now.to_i,
      exp: Time.now.to_i + (10 * 60), # JWT expires in 10 minutes
      iss: @app_id
    }
    
    JWT.encode(payload, @private_key, 'RS256')
  end
  
  def app_client
    Octokit::Client.new(bearer_token: generate_jwt)
  end
  
  def installation_client(installation_id)
    response = app_client.create_app_installation_access_token(installation_id)
    Octokit::Client.new(access_token: response.token)
  end
end

# app/jobs/github_sync_job.rb
class GitHubSyncJob < ApplicationJob
  queue_as :default
  retry_on Octokit::Error, wait: :polynomially_longer, attempts: 3
  
  def perform(service)
    return unless service.github_configured?
    
    client = service.github_client
    repo = service.github_repo_name
    
    sync_issues(client, repo, service)
    sync_pull_requests(client, repo, service)
    sync_commits(repo, service)
  rescue Octokit::Unauthorized => e
    Rails.logger.error("GitHub auth failed for service #{service.id}: #{e.message}")
    service.update(github_sync_error: e.message, github_synced_at: nil)
  rescue Octokit::NotFound => e
    Rails.logger.error("GitHub repo not found for service #{service.id}: #{e.message}")
    service.update(github_sync_error: e.message, github_synced_at: nil)
  end
  
  private
  
  def sync_issues(client, repo, service)
    # Paginate through all issues
    client.auto_paginate = true
    issues = client.issues(repo, state: 'all')
    
    issues.each do |issue|
      next if issue.pull_request # Skip PRs (they appear as issues too)
      
      task = service.tasks.find_or_initialize_by(github_issue_number: issue.number)
      
      # Map GitHub labels to Epic labels
      epic_label = issue.labels.find { |l| l.name.start_with?('epic:') }
      
      task.assign_attributes(
        title: issue.title,
        description: issue.body,
        status: map_issue_state(issue.state),
        github_issue_url: issue.html_url,
        assignee: find_or_create_user(issue.assignee),
        epic_label: epic_label&.name&.gsub('epic:', ''),
        due_date: extract_due_date(issue),
        priority: extract_priority(issue.labels)
      )
      
      task.save!
      
      # Sync comments
      sync_issue_comments(client, repo, issue.number, task)
    end
    
    service.update(github_synced_at: Time.current)
  end
  
  def sync_pull_requests(client, repo, service)
    pulls = client.pull_requests(repo, state: 'all')
    
    pulls.each do |pr|
      # Find associated task by branch name or PR body reference
      task = find_task_for_pr(service, pr)
      next unless task
      
      task.update!(
        github_pr_number: pr.number,
        github_pr_url: pr.html_url,
        github_branch_name: pr.head.ref,
        status: map_pr_state(pr)
      )
      
      # Update PR status checks
      sync_pr_status(client, repo, pr, task)
    end
  end
  
  def sync_commits(repo_path, service)
    # Clone or pull repository using Git gem
    local_path = Rails.root.join('tmp', 'repos', service.github_repo_name.gsub('/', '-'))
    
    git = if File.exist?(local_path)
      g = Git.open(local_path)
      g.pull
      g
    else
      Git.clone("https://github.com/#{service.github_repo_name}.git", local_path)
    end
    
    # Get recent commits
    commits = git.log(100)
    
    commits.each do |commit|
      # Look for task references in commit message (e.g., SHOP-123)
      task_refs = commit.message.scan(/#{service.key}-(\d+)/i)
      
      task_refs.each do |ref|
        task_number = ref.first.to_i
        task = service.tasks.find_by(sequence_number: task_number)
        
        next unless task
        
        # Create commit activity
        task.activities.create!(
          action: 'commit',
          user: find_or_create_user_by_email(commit.author.email),
          metadata: {
            sha: commit.sha,
            message: commit.message,
            author: commit.author.name,
            committed_at: commit.date
          }
        )
      end
    end
  end
  
  def sync_issue_comments(client, repo, issue_number, task)
    comments = client.issue_comments(repo, issue_number)
    
    comments.each do |comment|
      task.comments.find_or_create_by(
        github_comment_id: comment.id
      ) do |c|
        c.content = comment.body
        c.user = find_or_create_user(comment.user)
        c.created_at = comment.created_at
      end
    end
  end
  
  def sync_pr_status(client, repo, pr, task)
    # Get combined status
    status = client.combined_status(repo, pr.head.sha)
    
    task.update!(
      ci_status: status.state,
      ci_checks: status.statuses.map { |s| 
        { context: s.context, state: s.state, description: s.description }
      }
    )
  end
  
  def find_task_for_pr(service, pr)
    # Check branch name for task reference
    if pr.head.ref =~ /#{service.key}-(\d+)/i
      task_number = $1.to_i
      return service.tasks.find_by(sequence_number: task_number)
    end
    
    # Check PR body for task reference
    if pr.body =~ /(?:fixes|closes|resolves)\s+#?#{service.key}-(\d+)/i
      task_number = $1.to_i
      return service.tasks.find_by(sequence_number: task_number)
    end
    
    nil
  end
  
  def find_or_create_user(github_user)
    return nil unless github_user
    
    User.find_or_create_by(github_username: github_user.login) do |user|
      user.email = github_user.email || "#{github_user.login}@users.noreply.github.com"
      user.name = github_user.name || github_user.login
      user.avatar_url = github_user.avatar_url
    end
  end
  
  def find_or_create_user_by_email(email)
    User.find_or_create_by(email: email) do |user|
      user.name = email.split('@').first.humanize
    end
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
  
  def extract_due_date(issue)
    # Look for due date in issue body or labels
    if issue.body =~ /due:\s*(\d{4}-\d{2}-\d{2})/i
      Date.parse($1)
    elsif due_label = issue.labels.find { |l| l.name.start_with?('due:') }
      Date.parse(due_label.name.gsub('due:', ''))
    end
  end
  
  def extract_priority(labels)
    if labels.any? { |l| l.name.include?('urgent') || l.name.include?('critical') }
      'critical'
    elsif labels.any? { |l| l.name.include?('high') }
      'high'
    elsif labels.any? { |l| l.name.include?('low') }
      'low'
    else
      'medium'
    end
  end
end

# app/controllers/github_webhooks_controller.rb
class GitHubWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_github_signature
  
  def create
    event = request.headers['X-GitHub-Event']
    payload = JSON.parse(request.body.read)
    
    case event
    when 'issues'
      handle_issue_event(payload)
    when 'pull_request'
      handle_pr_event(payload)
    when 'push'
      handle_push_event(payload)
    when 'issue_comment'
      handle_comment_event(payload)
    when 'installation', 'installation_repositories'
      handle_app_event(payload)
    end
    
    head :ok
  end
  
  private
  
  def verify_github_signature
    signature = 'sha256=' + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha256'),
      webhook_secret,
      request.body.read
    )
    
    unless Rack::Utils.secure_compare(signature, request.headers['X-Hub-Signature-256'])
      head :unauthorized
    end
    
    request.body.rewind
  end
  
  def webhook_secret
    Rails.application.credentials.github[:webhook_secret]
  end
  
  def handle_issue_event(payload)
    service = find_service_by_repo(payload['repository']['full_name'])
    return unless service
    
    GitHubWebhookJob.perform_later(service, 'issue', payload)
  end
  
  def handle_pr_event(payload)
    service = find_service_by_repo(payload['repository']['full_name'])
    return unless service
    
    GitHubWebhookJob.perform_later(service, 'pull_request', payload)
  end
  
  def handle_push_event(payload)
    service = find_service_by_repo(payload['repository']['full_name'])
    return unless service
    
    GitHubWebhookJob.perform_later(service, 'push', payload)
  end
  
  def handle_comment_event(payload)
    service = find_service_by_repo(payload['repository']['full_name'])
    return unless service
    
    GitHubWebhookJob.perform_later(service, 'comment', payload)
  end
  
  def handle_app_event(payload)
    # Handle GitHub App installation events
    installation_id = payload['installation']['id']
    
    if payload['action'] == 'created'
      # New installation - save installation ID
      # Create services for repositories
      payload['repositories']&.each do |repo|
        create_service_for_repo(repo, installation_id)
      end
    elsif payload['action'] == 'deleted'
      # Remove installation
      Service.where(github_app_installation_id: installation_id)
             .update_all(github_app_installation_id: nil)
    end
  end
  
  def create_service_for_repo(repo, installation_id)
    org = Organization.find_by(github_org: repo['full_name'].split('/').first)
    return unless org
    
    service = org.services.find_or_create_by(github_repo_url: repo['html_url']) do |s|
      s.name = repo['name'].humanize
      s.key = repo['name'].upcase.gsub(/[^A-Z0-9]/, '').first(4)
      s.github_app_installation_id = installation_id
    end
  end
  
  def find_service_by_repo(full_name)
    Service.find_by("github_repo_url LIKE ?", "%#{full_name}%")
  end
end

# config/routes.rb
Rails.application.routes.draw do
  # GitHub webhook endpoint
  post 'github/webhooks', to: 'github_webhooks#create'
  
  # GitHub OAuth callback
  get 'github/callback', to: 'github_oauth#callback'
  
  # ... existing routes ...
end

# config/initializers/octokit.rb
# Configure Octokit with Faraday middleware for retries and better error handling
Octokit.configure do |c|
  c.connection_options = {
    request: {
      open_timeout: 5,
      timeout: 10
    }
  }
  
  # Use Faraday middleware for retries
  c.middleware = Faraday::RackBuilder.new do |builder|
    builder.use Faraday::Retry::Middleware,
                max: 3,
                interval: 0.5,
                interval_randomness: 0.5,
                backoff_factor: 2,
                exceptions: [
                  Faraday::TimeoutError,
                  Faraday::ConnectionFailed,
                  Octokit::ServerError
                ]
    
    builder.use Faraday::Response::RaiseError
    builder.adapter Faraday.default_adapter
  end
  
  # Auto-paginate results
  c.auto_paginate = true
  c.per_page = 100
end

# spec/jobs/github_sync_job_spec.rb
require 'rails_helper'

RSpec.describe GitHubSyncJob, type: :job do
  let(:service) { create(:service, :with_github) }
  let(:job) { described_class.new }
  
  describe '#perform' do
    context 'with valid GitHub configuration' do
      before do
        allow(service).to receive(:github_client).and_return(mock_client)
      end
      
      it 'syncs issues from GitHub' do
        expect(job).to receive(:sync_issues)
        job.perform(service)
      end
      
      it 'syncs pull requests from GitHub' do
        expect(job).to receive(:sync_pull_requests)
        job.perform(service)
      end
      
      it 'syncs commits from GitHub' do
        expect(job).to receive(:sync_commits)
        job.perform(service)
      end
    end
    
    context 'with GitHub authentication error' do
      before do
        allow(service).to receive(:github_client).and_raise(Octokit::Unauthorized)
      end
      
      it 'logs error and updates service' do
        job.perform(service)
        expect(service.github_sync_error).to be_present
      end
    end
  end
end
```

---

## 📅 달력 통합 기능

### CAL-001: ICS 달력 생성 서비스

**Priority**: Medium  
**Assignee**: Backend  
**Status**: Pending  
**Story Points**: 5

#### User Story

```
As a user
I want to subscribe to my tasks in my calendar app
So that I can see all deadlines in one place
```

#### Technical Tasks

```bash
# 1. Gem 추가
echo "gem 'icalendar'" >> Gemfile
echo "gem 'icalendar-recurrence'" >> Gemfile
bundle install

# 2. 서비스 생성
bin/rails generate service TaskCalendarService
```

#### 구현 코드

```ruby
# app/services/task_calendar_service.rb
class TaskCalendarService
  def initialize(user, organization, filters = {})
    @user = user
    @organization = organization
    @filters = filters
  end

  def generate_ics
    cal = Icalendar::Calendar.new
    setup_calendar_metadata(cal)
    add_tasks_to_calendar(cal)
    add_sprints_to_calendar(cal)
    add_milestones_to_calendar(cal)
    cal.to_ical
  end

  private

  def setup_calendar_metadata(cal)
    cal.append_custom_property("X-WR-CALNAME", calendar_name)
    cal.append_custom_property("X-WR-TIMEZONE", "Asia/Seoul")
    cal.append_custom_property("X-WR-CALDESC", calendar_description)
  end

  def add_tasks_to_calendar(cal)
    tasks_scope.find_each do |task|
      cal.event do |e|
        e.dtstart     = task.start_time || task.created_at
        e.dtend       = task.deadline || task.start_time + 1.hour
        e.summary     = "#{task.task_id}: #{task.title}"
        e.description = task_description(task)
        e.location    = "Creatia - #{@organization.name}"
        e.uid         = "task-#{task.id}@creatia.io"
        e.url         = task_url(task)

        # 카테고리 설정
        e.categories = task_categories(task)

        # 우선순위별 색상
        e.append_custom_property("X-APPLE-UNIVERSAL-ID", task.id.to_s)
        e.append_custom_property("COLOR", urgency_color(task))

        # 알림 설정
        add_alarms(e, task)
      end
    end
  end

  def add_sprints_to_calendar(cal)
    Sprint.current.each do |sprint|
      # 스프린트 시작
      cal.event do |e|
        e.dtstart = sprint.sprint_start_datetime
        e.dtend   = sprint.sprint_start_datetime + 2.hours
        e.summary = "🚀 Sprint Start: #{sprint.name}"
        e.description = "Sprint Goal: #{sprint.goal}"
      end

      # 데일리 스탠드업
      if sprint.daily_standup_time
        schedule = IceCube::Schedule.new(sprint.start_date) do |s|
          s.add_recurrence_rule(
            IceCube::Rule.daily
              .hour_of_day(sprint.daily_standup_time.hour)
              .minute_of_hour(sprint.daily_standup_time.min)
              .until(sprint.end_date)
          )
        end

        schedule.all_occurrences.each do |occurrence|
          cal.event do |e|
            e.dtstart = occurrence
            e.dtend   = occurrence + 15.minutes
            e.summary = "📊 Daily Standup"
          end
        end
      end

      # 스프린트 리뷰
      if sprint.review_meeting_time
        cal.event do |e|
          e.dtstart = sprint.review_meeting_time
          e.dtend   = sprint.review_meeting_time + 2.hours
          e.summary = "📝 Sprint Review: #{sprint.name}"
        end
      end
    end
  end

  def add_milestones_to_calendar(cal)
    Milestone.upcoming.each do |milestone|
      cal.event do |e|
        e.dtstart = milestone.target_date
        e.dtend   = milestone.target_date
        e.summary = "🎯 Milestone: #{milestone.name}"
        e.description = "Progress: #{milestone.progress}%\n#{milestone.description}"
        e.categories = ["milestone", milestone.status]
      end
    end
  end

  def task_categories(task)
    categories = []
    categories << task.sprint&.name
    categories << task.epic&.name
    categories << task.priority
    categories.compact
  end

  def urgency_color(task)
    case task.urgency_level
    when :critical then "#FF0000"
    when :high then "#FFA500"
    when :medium then "#FFFF00"
    when :low then "#00FF00"
    else "#0099FF"
    end
  end

  def add_alarms(event, task)
    if task.deadline
      # 1시간 전 알림
      event.alarm do |a|
        a.action = "DISPLAY"
        a.summary = "Task deadline in 1 hour"
        a.trigger = "-PT1H"
      end

      # 하루 전 알림 (긴급도 높은 경우)
      if [:critical, :high].include?(task.urgency_level)
        event.alarm do |a|
          a.action = "DISPLAY"
          a.summary = "Task deadline tomorrow"
          a.trigger = "-PT24H"
        end
      end
    end
  end

  def tasks_scope
    scope = @user.assigned_tasks.includes(:sprint, :epic, :service)
    scope = scope.where(sprint_id: @filters[:sprint_id]) if @filters[:sprint_id]
    scope = scope.where(service_id: @filters[:service_id]) if @filters[:service_id]
    scope
  end

  def task_url(task)
    Rails.application.routes.url_helpers.organization_service_task_url(
      @organization,
      task.service,
      task,
      host: ENV['APP_HOST']
    )
  end

  def calendar_name
    if @filters[:sprint_id]
      "Sprint Calendar - #{Sprint.find(@filters[:sprint_id]).name}"
    elsif @filters[:service_id]
      "Service Calendar - #{Service.find(@filters[:service_id]).name}"
    else
      "#{@user.name} - Creatia Tasks"
    end
  end

  def calendar_description
    "Automatically synced from Creatia project management"
  end

  def task_description(task)
    <<~DESC
      Task: #{task.task_id}
      Status: #{task.status}
      Priority: #{task.priority}
      Sprint: #{task.sprint&.name}
      Epic: #{task.epic&.name}
      Assignee: #{task.assignee&.name}

      #{task.description}

      ---
      View in Creatia: #{task_url(task)}
    DESC
  end
end
```

---

### CAL-002: 달력 컨트롤러 및 라우트

**Priority**: Medium  
**Assignee**: Backend  
**Status**: Pending  
**Story Points**: 3

#### 구현 코드

```ruby
# app/controllers/calendars_controller.rb
class CalendarsController < ApplicationController
  before_action :authenticate_user!, except: [:show]
  before_action :validate_token, only: [:show]

  def show
    respond_to do |format|
      format.ics do
        render plain: calendar_service.generate_ics,
               content_type: 'text/calendar'
      end
      format.html { render :subscription_info }
    end
  end

  def my_tasks
    render_calendar(user: current_user)
  end

  def team_tasks
    team = current_organization.teams.find(params[:team_id])
    render_calendar(team: team)
  end

  def sprint_calendar
    sprint = current_organization.sprints.find(params[:sprint_id])
    render_calendar(sprint_id: sprint.id)
  end

  private

  def render_calendar(filters = {})
    service = TaskCalendarService.new(
      current_user,
      current_organization,
      filters
    )

    respond_to do |format|
      format.ics do
        render plain: service.generate_ics,
               content_type: 'text/calendar'
      end
    end
  end

  def validate_token
    return true if user_signed_in?

    token = params[:token]
    @user = User.find_by(calendar_token: token)

    unless @user
      render plain: "Invalid token", status: :unauthorized
    end
  end

  def calendar_service
    @calendar_service ||= TaskCalendarService.new(
      @user || current_user,
      @user&.organization || current_organization,
      filter_params
    )
  end

  def filter_params
    params.permit(:sprint_id, :service_id, :team_id, :epic_id)
  end
end

# config/routes.rb
Rails.application.routes.draw do
  resources :organizations do
    resources :calendars, only: [:show] do
      collection do
        get :my_tasks
        get :team_tasks
        get :sprint_calendar
      end
    end

    # 달력 구독 URL (토큰 기반)
    get 'calendar/:token', to: 'calendars#show',
        defaults: { format: 'ics' },
        as: :calendar_subscription
  end
end
```

---

### CAL-003: Google Calendar 동기화

**Priority**: Low  
**Assignee**: Backend  
**Status**: Pending  
**Story Points**: 8

#### Technical Tasks

```bash
# Gem 추가
echo "gem 'google-apis-calendar_v3'" >> Gemfile
echo "gem 'googleauth'" >> Gemfile
bundle install
```

#### 구현 코드

```ruby
# app/services/google_calendar_sync_service.rb
class GoogleCalendarSyncService
  def initialize(user)
    @user = user
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.authorization = user_credentials
  end

  def sync_task(task)
    event = build_event_from_task(task)

    if task.google_event_id.present?
      update_event(task, event)
    else
      create_event(task, event)
    end
  end

  def sync_all_tasks
    @user.assigned_tasks.find_each do |task|
      sync_task(task)
    rescue => e
      Rails.logger.error "Failed to sync task #{task.id}: #{e.message}"
    end
  end

  private

  def build_event_from_task(task)
    Google::Apis::CalendarV3::Event.new(
      summary: "#{task.task_id}: #{task.title}",
      description: task.description,
      start: event_datetime(task.start_time || task.created_at),
      end: event_datetime(task.deadline || task.start_time + 1.hour),
      location: "Creatia",
      color_id: color_for_priority(task.priority),
      reminders: {
        use_default: false,
        overrides: [
          { method: 'popup', minutes: 60 },
          { method: 'email', minutes: 1440 }
        ]
      },
      extended_properties: {
        private: {
          'creatia_task_id' => task.id.to_s,
          'creatia_org' => task.organization.subdomain
        }
      }
    )
  end

  def create_event(task, event)
    result = @service.insert_event('primary', event)
    task.update(google_event_id: result.id)
  end

  def update_event(task, event)
    @service.update_event('primary', task.google_event_id, event)
  end

  def event_datetime(time)
    Google::Apis::CalendarV3::EventDateTime.new(
      date_time: time.iso8601,
      time_zone: 'Asia/Seoul'
    )
  end

  def color_for_priority(priority)
    case priority
    when 'urgent' then '11'  # Red
    when 'high' then '5'     # Yellow
    when 'medium' then '7'   # Cyan
    when 'low' then '10'     # Green
    else '9'                 # Blue
    end
  end

  def user_credentials
    # OAuth2 인증 구현
    # ...
  end
end
```

---

## 🔄 구현 순서

### Phase 1: 기본 구조 완성 (1주)

1. STRUCT-001: Milestone 모델
2. STRUCT-002: Epic & Label 시스템
3. STRUCT-003: Task ID 자동 생성

### Phase 2: 통합 기능 (1주)

4. STRUCT-004: GitHub 연결
5. CAL-001: ICS 달력 생성
6. CAL-002: 달력 컨트롤러

### Phase 3: 고급 기능 (선택)

7. CAL-003: Google Calendar 동기화

---

## 📊 Progress Tracking

| Task ID    | Story Points | Status     | Progress |
| ---------- | ------------ | ---------- | -------- |
| STRUCT-001 | 5            | 📋 Pending | 0%       |
| STRUCT-002 | 8            | 📋 Pending | 0%       |
| STRUCT-003 | 3            | 📋 Pending | 0%       |
| STRUCT-004 | 5            | 📋 Pending | 0%       |
| CAL-001    | 5            | 📋 Pending | 0%       |
| CAL-002    | 3            | 📋 Pending | 0%       |
| CAL-003    | 8            | 📋 Pending | 0%       |

**Total Story Points**: 37  
**Completed**: 0  
**Velocity**: TBD

---

## 🚀 Definition of Done

- [ ] 모든 모델과 마이그레이션 생성
- [ ] 테스트 작성 (RSpec)
- [ ] 문서 업데이트
- [ ] 프로젝트 구조 문서와 100% 일치
- [ ] 달력 구독 기능 동작 확인
