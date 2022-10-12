require "add_dependabot_sync_workflows"

RSpec.describe "#add_dependabot_sync_workflows!" do
  before do
    stub_govuk_repos([
      "repo-without-pr-template",
      "repo-with-pr-template-but-no-sync-workflow",
      "repo-with-pr-template-and-pr-to-create-sync-workflow",
      "repo-with-sync-workflow",
    ])

    stub_github_repo("repo-without-pr-template")
    stub_github_repo("repo-with-pr-template-but-no-sync-workflow", contents: [".github/pull_request_template.md"])
    stub_github_repo("repo-with-pr-template-and-pr-to-create-sync-workflow", contents: [".github/pull_request_template.md"], feature_branches: [BRANCH])
    stub_github_repo("repo-with-sync-workflow", contents: [".github/pull_request_template.md", ".github/workflows/copy-pr-template-to-dependabot-prs.yaml"])
  end
    
  let!(:create_branch_stub) { stub_create_branch_request("repo-with-pr-template-but-no-sync-workflow", BRANCH) }

  let!(:create_contents_stub) {
    stub_create_contents_request(
      "repo-with-pr-template-but-no-sync-workflow",
      src_path: "copy-pr-template-to-dependabot-prs.yaml",
      dst_path: ".github/workflows/copy-pr-template-to-dependabot-prs.yaml",
      commit_title: TITLE,
      branch: BRANCH
    )
  }
    
  let!(:raise_pr_stub) { stub_create_pull_request("repo-with-pr-template-but-no-sync-workflow", branch: BRANCH, title: TITLE, description: DESCRIPTION) }

  it "raises a PR for repos that have a PR template" do
    expect { add_dependabot_sync_workflows! }.to output("Raising PR for repo-with-pr-template-but-no-sync-workflow... ✅\n").to_stdout

    expect(create_branch_stub).to have_been_requested
    expect(create_contents_stub).to have_been_requested
    expect(raise_pr_stub).to have_been_requested
  end
end
