require "bulk_update_file"

RSpec.describe "#bulk_update_file" do
  let(:defaults) {
    {
      dry_run: false,
      github_token: "123",
      file_path: "file.txt",
      file_content: "New file content",
      branch: "branch",
      pr_title: "PR Title",
      pr_description: "PR Description",
      if_file_exists: [],
      unless_file_exists: []
    }
  }

  def call(**options)
    bulk_update_file(**defaults.merge(options))
  end

  it "raises PRs for repos where the file does not already exist" do
    stub_govuk_repos(["foo"])
    stub_github_repo("foo")

    create_branch_stub = stub_create_branch_request("foo", defaults[:branch])
    create_contents_stub = stub_create_contents_request("foo", path: defaults[:file_path], content: defaults[:file_content], commit_title: defaults[:pr_title], branch: defaults[:branch])
    raise_pr_stub = stub_create_pull_request("foo", branch: defaults[:branch], title: defaults[:pr_title], description: defaults[:pr_description])

    expect { call }.to output("[1/1] alphagov/foo ✅ PR raised\n").to_stdout

    expect(create_branch_stub).to have_been_requested
    expect(create_contents_stub).to have_been_requested
    expect(raise_pr_stub).to have_been_requested
  end

  it "skips repos where the file already exists with the desired content" do
    stub_govuk_repos(["foo"])
    stub_github_repo("foo", contents: [defaults[:file_path]])
    expect { call }.to output("[1/1] alphagov/foo ⏭  file already exists\n").to_stdout
  end

  it "does not raise PRs if the dry_run option is set" do
    stub_govuk_repos(["foo"])
    stub_github_repo("foo")
    expect { call(dry_run: true) }.to output("[1/1] alphagov/foo ✅ would raise PR (dry run)\n").to_stdout
  end

  it "notifies the user if the repo does not exist" do
    stub_govuk_repos(["foo"])
    stub_request(:get, "https://api.github.com/repos/alphagov/foo").to_return(status: 404)
    expect { call }.to output("[1/1] alphagov/foo ❌ repo doesn't exist (or we don't have permission)\n").to_stdout
  end

  it "skips repos where the branch already exists" do
    stub_govuk_repos(["foo"])
    stub_github_repo("foo", feature_branches: [defaults[:branch]])
    expect { call }.to output("[1/1] alphagov/foo ⏭  branch \"#{defaults[:branch]}\" already exists\n").to_stdout
  end

  it "respects the if_file_exists filter" do
    stub_govuk_repos(["foo"])
    stub_github_repo("foo")
    expect { call(if_file_exists: ["nonexistent_file"]) }.to output("[1/1] alphagov/foo ⏭  filters don't match\n").to_stdout
  end

  it "respects the unless_file_exists filter" do
    stub_govuk_repos(["foo"])
    stub_github_repo("foo", contents: ["existing_file"])
    expect { call(unless_file_exists: ["existing_file"]) }.to output("[1/1] alphagov/foo ⏭  filters don't match\n").to_stdout
  end

  it "respects GitHub's rate limit headers" do
    stub_govuk_repos(["foo"])

    rate_limit_expires_at = Time.now + 1
    github_request_stub = stub_request(:get, "https://api.github.com/repos/alphagov/foo").
      to_return do |request|
        if Time.now < rate_limit_expires_at
          {
            status: 403,
            headers: {
              'X-RateLimit-Limit' => 5000,
              'X-RateLimit-Remaining' => 0,
              'X-RateLimit-Reset' => rate_limit_expires_at.to_i
            },
            body: "rate limit exceeded"
          }
        else
          { status: 404 }
        end
      end

    expect { call }.to output("[1/1] alphagov/foo ❌ repo doesn't exist (or we don't have permission)\n").to_stdout
    expect(github_request_stub).to have_been_requested.times(2)
  end
end
