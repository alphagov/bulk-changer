require "octokit"
require "open-uri"

class PrRaiser
  BRANCH_NAME = "sync-dependabot-prs"
  COMMIT_TITLE = "Create workflow to copy PR template onto Dependabot PRs"
  PR_DESCRIPTION = "This PR has been automatically raised by a script. For more details, please visit ..."

  def raise_prs!
    repos.each do |repo|
      print "Raising PR for #{repo.name}..."
      create_sync_branch! repo
      commit_sync_workflow! repo
      create_sync_pr! repo
      puts " ✅"
    end
  end

  def client
    @client ||= Octokit::Client.new auto_paginate: true, access_token: ENV["GITHUB_TOKEN"]
  end


  def create_sync_branch!(repo)
    main_branch = client.ref(repo.full_name, "heads/#{repo.default_branch}")
    client.create_ref(repo.full_name, "refs/heads/#{BRANCH_NAME}", main_branch.object.sha)
  end

  def commit_sync_workflow!(repo)
    client.create_contents(
      repo.full_name,
      ".github/workflows/copy-pr-template-to-dependabot-prs.yaml",
      COMMIT_TITLE,
      File.read("copy-pr-template-to-dependabot-prs.yaml"),
      branch: BRANCH_NAME
    )
  end

  def create_sync_pr!(repo)
    client.create_pull_request(
      repo.full_name,
      repo.default_branch,
      BRANCH_NAME,
      COMMIT_TITLE,
      PR_DESCRIPTION
    )
  end

  def has_pr_template?(repo_name)
    begin
      client.contents(repo_name, path: ".github/pull_request_template.md")
      true
    rescue Octokit::NotFound
      false
    end
  end

  def has_sync_workflow?(repo_name)
    begin
      client.contents(repo_name, path: ".github/workflows/copy-pr-template-to-dependabot-prs.yaml")
      true
    rescue Octokit::NotFound
      false
    end
  end

  def has_sync_branch?(repo_name)
    client.refs(repo_name).map(&:ref).include? "refs/heads/#{BRANCH_NAME}"
  end

  def repos
    JSON.parse(
      URI.open("https://docs.publishing.service.gov.uk/repos.json").read
    ).
      lazy.
      map { |repo| "alphagov/#{repo["app_name"]}" }.
      filter { |repo_name| has_pr_template?(repo_name) && !has_sync_branch?(repo_name) && !has_sync_workflow?(repo_name) }.
      map { |repo_name| client.repo(repo_name) }
  end
end
