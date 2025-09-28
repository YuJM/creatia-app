# frozen_string_literal: true

require 'hashie'

class GithubPayload < Hashie::Dash
  include Hashie::Extensions::IndifferentAccess
  include Hashie::Extensions::MethodAccess
  include Hashie::Extensions::Coercion
  
  property :ref, required: true
  property :before
  property :after
  property :repository, required: true
  property :pusher
  property :sender
  property :created
  property :deleted
  property :forced
  property :commits, default: []
  property :head_commit
  
  # Coercions
  coerce_key :repository, Hashie::Mash
  coerce_key :pusher, Hashie::Mash
  coerce_key :sender, Hashie::Mash
  coerce_key :head_commit, Hashie::Mash
  
  def task_id
    # 브랜치명 또는 커밋 메시지에서 Task ID 추출
    # Task ID는 PREFIX-NUMBER 또는 PREFIX-UUID 형식일 수 있음
    branch_match = ref.match(/([A-Z]+-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}|[A-Z]+-\d+)/)
    return branch_match[1] if branch_match
    
    # 커밋 메시지에서 찾기
    commits.each do |commit|
      message = commit.is_a?(Hash) ? commit['message'] : commit.message
      message_match = message&.match(/\[?([A-Z]+-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}|[A-Z]+-\d+)\]?/)
      return message_match[1] if message_match
    end
    
    nil
  end
  
  def branch_name
    ref.gsub('refs/heads/', '')
  end
  
  def repository_full_name
    repository['full_name'] || repository.full_name
  end
  
  def repository_name
    repository['name'] || repository.name
  end
  
  def author_email
    if pusher && (pusher['email'] || pusher.email)
      pusher['email'] || pusher.email
    elsif sender && (sender['email'] || sender.email)
      sender['email'] || sender.email
    else
      nil
    end
  end
  
  def author_name
    if pusher && (pusher['name'] || pusher.name)
      pusher['name'] || pusher.name
    elsif sender && (sender['login'] || sender.login)
      sender['login'] || sender.login
    else
      'Unknown'
    end
  end
  
  def is_branch_creation?
    created == true
  end
  
  def is_branch_deletion?
    deleted == true
  end
  
  def is_force_push?
    forced == true
  end
  
  def commit_count
    commits.size
  end
  
  def latest_commit_message
    if head_commit
      head_commit['message'] || head_commit.message
    elsif commits.any?
      first_commit = commits.first
      first_commit.is_a?(Hash) ? first_commit['message'] : first_commit.message
    end
  end
  
  def commit_authors
    commits.map do |commit|
      if commit.is_a?(Hash)
        commit.dig('author', 'name') || commit.dig('author', 'username')
      else
        commit.author&.name || commit.author&.username
      end
    end.compact.uniq
  end
  
  def to_activity_data
    {
      ref: ref,
      branch: branch_name,
      repository: repository_full_name,
      author: author_name,
      email: author_email,
      task_id: task_id,
      commits_count: commit_count,
      latest_message: latest_commit_message,
      is_new_branch: is_branch_creation?,
      is_deleted: is_branch_deletion?,
      is_force_push: is_force_push?
    }
  end
end