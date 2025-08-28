# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

class GitHubSyncService
  include Dry::Monads[:result, :do]
  
  pattr_initialize [:service!]
  memo_wise :github_client
  
  def call
    yield validate_configuration
    client = yield get_github_client
    yield sync_issues(client)
    yield sync_pull_requests(client)
    yield sync_commits
    
    Success(service.reload)
  rescue => e
    Failure([:sync_error, e.message])
  end
  
  private
  
  def validate_configuration
    return Failure([:invalid_config, "GitHub not configured"]) unless service.github_configured?
    return Failure([:invalid_repo, "Repository URL invalid"]) unless service.github_repo_name
    
    Success()
  end
  
  def get_github_client
    client = service.github_client
    return Failure([:auth_error, "Unable to create GitHub client"]) unless client
    
    Success(client)
  end
  
  def sync_issues(client)
    issues = client.issues(service.github_repo_name, state: 'all')
    
    issues.each do |issue|
      next if issue.pull_request
      
      task = service.tasks.find_or_initialize_by(github_issue_number: issue.number)
      task.assign_attributes(
        title: issue.title,
        description: issue.body,
        status: map_issue_state(issue.state),
        github_issue_url: issue.html_url
      )
      
      return Failure([:sync_error, "Failed to save task #{issue.number}"]) unless task.save
    end
    
    Success(issues.count)
  rescue Octokit::Error => e
    Failure([:github_error, e.message])
  end
  
  def sync_pull_requests(client)
    pulls = client.pull_requests(service.github_repo_name, state: 'all')
    
    pulls.each do |pr|
      task = find_task_for_pr(pr)
      next unless task
      
      task.update!(
        github_pr_number: pr.number,
        github_pr_url: pr.html_url,
        github_branch_name: pr.head.ref
      )
    end
    
    Success(pulls.count)
  rescue Octokit::Error => e
    Failure([:github_error, e.message])
  end
  
  def sync_commits
    GitCommitSyncService.new(service: service).call
  end
  
  memo_wise
  def github_client
    service.github_client
  end
  
  def find_task_for_pr(pr)
    return nil unless pr.head.ref =~ /#{service.key}-(\d+)/i
    
    task_number = $1.to_i
    service.tasks.find_by(sequence_number: task_number)
  end
  
  def map_issue_state(state)
    case state
    when 'open' then 'open'
    when 'closed' then 'completed'
    else 'open'
    end
  end
end

# 사용 예시:
# result = GitHubSyncService.new(service: service).call
# case result
# in Success(service)
#   puts "Sync successful for #{service.name}"
# in Failure[:invalid_config, message]
#   puts "Configuration error: #{message}"
# in Failure[:github_error, message]
#   puts "GitHub API error: #{message}"
# end