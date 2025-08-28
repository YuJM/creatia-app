# frozen_string_literal: true

require 'hashie'

class GithubPayload < Hashie::Dash
  include Hashie::Extensions::IndifferentAccess
  include Hashie::Extensions::MethodAccess
  
  property :ref, required: true
  property :before
  property :after
  property :repository, required: true
  property :pusher
  property :sender
  property :commits, default: []
  property :head_commit
  property :compare
  property :forced, default: false
  property :deleted, default: false
  property :created, default: false
  
  # 편의 메서드들
  def branch_name
    ref.sub('refs/heads/', '') if ref&.start_with?('refs/heads/')
  end
  
  def repository_name
    repository&.dig('name')
  end
  
  def repository_full_name  
    repository&.dig('full_name')
  end
  
  def pusher_name
    pusher&.dig('name')
  end
  
  def pusher_email
    pusher&.dig('email')
  end
  
  def commit_messages
    commits&.map { |commit| commit['message'] } || []
  end
  
  def has_task_id_in_branch?
    branch_name&.match?(/[A-Z]+-\d+/)
  end
  
  def extract_task_id
    branch_name&.match(/([A-Z]+-\d+)/)&.captures&.first
  end
  
  def commits_with_task_ids
    commit_messages.select { |msg| msg.match?(/\[?[A-Z]+-\d+\]?/) }
  end
  
  def is_main_branch?
    branch_name.in?(%w[main master develop])
  end
  
  def is_feature_branch?
    branch_name&.start_with?('feature/')
  end
  
  def is_hotfix_branch?
    branch_name&.start_with?('hotfix/')
  end
  
  def is_release_branch?
    branch_name&.start_with?('release/')
  end
end