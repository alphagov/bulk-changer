require "octokit"
require "open-uri"

Octokit.auto_paginate = true
Octokit.access_token = ENV["GITHUB_TOKEN"]

def fetch_govuk_repos
  JSON.parse(
    URI.open("https://docs.publishing.service.gov.uk/repos.json").read
  ).map do |repo|
    "alphagov/#{repo["app_name"]}"
  end
end

def create_branch!(repo, branch_name)
  main_branch = Octokit.ref(repo.full_name, "heads/#{repo.default_branch}")
  Octokit.create_ref(repo.full_name, "refs/heads/#{branch_name}", main_branch.object.sha)
end

def commit_file!(repo, src_path:, dst_path:, commit_title:, branch:)
  Octokit.create_contents(
    repo.full_name,
    dst_path,
    commit_title,
    File.read(src_path),
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
  begin
    Octokit.contents(repo_name, path: path)
    true
  rescue Octokit::NotFound
    false
  end
end

def repo_has_branch?(repo_name, branch_name)
  Octokit.refs(repo_name).map(&:ref).include? "refs/heads/#{branch_name}"
end
