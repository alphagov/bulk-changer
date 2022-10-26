require "octokit"
require "open-uri"

def govuk_repos
  @govuk_repos ||= JSON.parse(
    URI.open("https://docs.publishing.service.gov.uk/repos.json").read
  ).map do |repo|
    "alphagov/#{repo["app_name"]}"
  end
end

def create_branch!(repo, branch_name)
  main_branch = Octokit.ref(repo.full_name, "heads/#{repo.default_branch}")
  Octokit.create_ref(repo.full_name, "refs/heads/#{branch_name}", main_branch.object.sha)
end

def commit_file!(repo, path:, content:, commit_title:, branch:)
  Octokit.create_contents(
    repo.full_name,
    path,
    commit_title,
    content,
    branch: branch
  )
end

def create_pr!(repo, branch:, title:, description:)
  Octokit.create_pull_request(
    repo.full_name,
    repo.default_branch,
    branch,
    title,
    description
  )
end

def repo_contains_file?(repo_name, path)
  Octokit.contents(repo_name, path: path)
  true
rescue Octokit::NotFound
  false
end

def repo_has_branch?(repo_name, branch_name)
  Octokit.ref(repo_name, "heads/#{branch_name}")
  true
rescue Octokit::NotFound
  false
end
