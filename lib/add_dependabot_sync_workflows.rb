require "util"

BRANCH = "sync-dependabot-prs"
TITLE = "Create workflow to copy PR template onto Dependabot PRs"
DESCRIPTION = <<~EOF
  This repo contains a pull request template. However, PRs raised by Dependabot will not use this template. This could mean that PR reviewers might miss crucial information about the test suite, or about any manual steps that must be performed pre- or post- merge.

  This PR adds a GitHub Actions workflow that will post the PR template as a comment on every PR that Dependabot raises.
  
  ---
  
  <sup>🤖 This PR was automatically raised by a script. For more details, please visit https://github.com/alphagov/bulk-changer or ask in the [Platform Reliability Slack channel](https://gds.slack.com/archives/CAEDZ4A8N).</sup>
EOF

def repo_has_pr_template?(repo_name)
  repo_contains_file?(repo_name, ".github/pull_request_template.md")
end

def repo_has_sync_workflow?(repo_name)
  repo_contains_file?(repo_name, ".github/workflows/copy-pr-template-to-dependabot-prs.yaml")
end

def repo_is_relevant?(repo_name)
  repo_has_pr_template?(repo_name) && !repo_has_sync_workflow?(repo_name) && !repo_has_branch?(repo_name, BRANCH)
end

def add_dependabot_sync_workflows!
  fetch_govuk_repos.lazy.
  filter { |repo_name| repo_is_relevant?(repo_name) }.
  map { |repo_name| Octokit.repo(repo_name) }.
  each do |repo|
    print "Raising PR for #{repo.name}..."

    create_branch! repo, BRANCH
    commit_file!(
      repo,
      src_path: "copy-pr-template-to-dependabot-prs.yaml",
      dst_path: ".github/workflows/copy-pr-template-to-dependabot-prs.yaml",
      commit_title: TITLE,
      branch: BRANCH
    )
    create_pr! repo, branch: BRANCH, title: TITLE, description: DESCRIPTION

    puts " ✅"
  end
end
