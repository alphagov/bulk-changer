require "add_dependabot_sync_workflows"

describe "#add_dependabot_sync_workflows!" do
  it "raises a PR for repos that have a PR template" do
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
    
    create_branch_stub = stub_create_branch_request("repo-with-pr-template-but-no-sync-workflow", BRANCH)

    stub_request(:put, "https://api.github.com/repos/alphagov/repo-with-pr-template-but-no-sync-workflow/contents/.github/workflows/copy-pr-template-to-dependabot-prs.yaml").
      with(
        body: {
          "branch": BRANCH,
          "content": Base64.encode64(File.read("copy-pr-template-to-dependabot-prs.yaml")).gsub(/\n/, ""),
          "message": TITLE,
        }
      ).
      to_return(status: 200)
    
    raise_pr_stub = stub_request(:post, "https://api.github.com/repos/alphagov/repo-with-pr-template-but-no-sync-workflow/pulls").
      with(
        body: {
          "base": "main",
          "head": BRANCH,
          "title": TITLE,
          "body": DESCRIPTION,
        }
      ).
      to_return(status: 200)

    expect { add_dependabot_sync_workflows! }.to output("Raising PR for repo-with-pr-template-but-no-sync-workflow... ✅\n").to_stdout

    expect(create_branch_stub).to have_been_requested
    expect(raise_pr_stub).to have_been_requested
  end
end
