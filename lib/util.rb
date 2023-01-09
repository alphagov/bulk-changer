require "octokit"
require "open-uri"

def govuk_repos
  @govuk_repos ||= JSON.parse(
    URI.open("https://docs.publishing.service.gov.uk/repos.json").read,
  ).map do |repo|
    "alphagov/#{repo['app_name']}"
  end
end

def create_branch!(repo, branch_name)
  sleep 1
  main_branch = Octokit.ref(repo.full_name, "heads/#{repo.default_branch}")
  Octokit.create_ref(repo.full_name, "refs/heads/#{branch_name}", main_branch.object.sha)
end

def commit_file!(repo, path:, content:, commit_title:, branch:, sha: nil)
  sleep 1
  Octokit.create_contents(
    repo.full_name,
    path,
    commit_title,
    content,
    { branch: }.merge(sha.nil? ? {} : { sha: }),
  )
end

def create_pr!(repo, branch:, title:, description:)
  sleep 1
  Octokit.create_pull_request(
    repo.full_name,
    repo.default_branch,
    branch,
    title,
    description,
  )
end

def get_file_contents(repo_name, path, branch_name = nil)
  # TODO: use branch name if set
  Octokit.contents(repo_name, path:)
rescue Octokit::NotFound
  nil
end

def repo_contains_file?(repo_name, path)
  !get_file_contents(repo_name, path).nil?
end

def repo_has_branch?(repo_name, branch_name)
  Octokit.ref(repo_name, "heads/#{branch_name}")
  true
rescue Octokit::NotFound
  false
end

def repo_has_pr_for_branch?(repo_name, branch_name)
  org_name = repo_name.split("/").first
  Octokit.pull_requests(repo_name, head: "#{org_name}:#{branch_name}").count > 0
end
