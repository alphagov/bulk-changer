require "add_dependabot_sync_workflows"

describe "#add_dependabot_sync_workflows!" do
  def stub_contents(repo_name, filename, file_content)
    stub_request(:get, "https://api.github.com/repos/alphagov/#{repo_name}/contents/#{filename}").
      to_return(
        file_content.nil? ? { status: 404 } : { status: 200 }
      )
  end

  def stub_branches(repo_name, branches)
    stub_request(:get, "https://api.github.com/repos/alphagov/#{repo_name}/git/refs?per_page=100").
      to_return(
        status: 200,
        headers: { "Content-Type": "application/json" },
        body: branches.map { |branch| { "ref": "refs/heads/#{branch}" } }.to_json
      )
  end

  it "raises a PR for repos that have a PR template" do
    stub_govuk_repos([
      "repo-without-pr-template",
      "repo-with-pr-template-but-no-sync-workflow",
      "repo-with-pr-template-and-pr-to-create-sync-workflow",
      "repo-with-sync-workflow",
    ])

    stub_contents("repo-without-pr-template",                             ".github/pull_request_template.md", nil)
    stub_contents("repo-with-pr-template-but-no-sync-workflow",           ".github/pull_request_template.md", "This is a PR template!")
    stub_contents("repo-with-pr-template-and-pr-to-create-sync-workflow", ".github/pull_request_template.md", "This is a PR template!")
    stub_contents("repo-with-sync-workflow",                              ".github/pull_request_template.md", "This is a PR template!")

    stub_contents("repo-without-pr-template",                             ".github/workflows/copy-pr-template-to-dependabot-prs.yaml", nil)
    stub_contents("repo-with-pr-template-but-no-sync-workflow",           ".github/workflows/copy-pr-template-to-dependabot-prs.yaml", nil)
    stub_contents("repo-with-pr-template-and-pr-to-create-sync-workflow", ".github/workflows/copy-pr-template-to-dependabot-prs.yaml", nil)
    stub_contents("repo-with-sync-workflow",                              ".github/workflows/copy-pr-template-to-dependabot-prs.yaml", "File exists!")

    stub_branches("repo-without-pr-template",                             ["main"])
    stub_branches("repo-with-pr-template-but-no-sync-workflow",           ["main"])
    stub_branches("repo-with-pr-template-and-pr-to-create-sync-workflow", ["main", BRANCH])
    stub_branches("repo-with-sync-workflow",                              ["main"])

    stub_request(:get, "https://api.github.com/repos/alphagov/repo-with-pr-template-but-no-sync-workflow").
      to_return(
        status: 200,
        headers: { "Content-Type": "application/json" },
        body: {
          name: "repo-with-pr-template-but-no-sync-workflow",
          full_name: "alphagov/repo-with-pr-template-but-no-sync-workflow",
          default_branch: "main"
        }.to_json
      )
    
    stub_request(:get, "https://api.github.com/repos/alphagov/repo-with-pr-template-but-no-sync-workflow/git/refs/heads/main").
      to_return(
        status: 200,
        headers: { "Content-Type": "application/json" },
        body: {
          "ref": "refs/heads/main",
          "object": { "sha": "123" }
        }.to_json
      )
    
    stub_request(:post, "https://api.github.com/repos/alphagov/repo-with-pr-template-but-no-sync-workflow/git/refs").to_return(status: 200)

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

    expect(raise_pr_stub).to have_been_requested
  end
end
