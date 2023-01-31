require "bulk_update_file"

RSpec.describe "#bulk_update_file" do
  let(:dry_run)          { false }
  let(:github_token)     { "123" }
  let(:file_path)        { "file.txt" }
  let(:file_content)     { "New file content\n" }
  let(:branch)           { "branch" }
  let(:pr_title)         { "PR Title" }
  let(:pr_description)   { "PR Description" }
  let(:if_any_exist)     { [] }
  let(:if_all_exist)     { [] }
  let(:unless_any_exist) { [] }
  let(:unless_all_exist) { [] }

  def call(**options)
    defaults = {
      dry_run:,
      github_token:,
      file_path:,
      file_content:,
      branch:,
      pr_title:,
      pr_description:,
      if_any_exist:,
      if_all_exist:,
      unless_any_exist:,
      unless_all_exist:,
    }
    bulk_update_file(**defaults.merge(options))
  end

  it "raises PRs for repos where the file does not already exist" do
    stub_govuk_repos(%w[foo])
    stub_github_repo("foo")

    create_branch_stub = stub_create_branch_request("foo", branch)
    create_contents_stub = stub_create_contents_request("foo", path: file_path, content: file_content, commit_title: pr_title, branch:)
    raise_pr_stub = stub_create_pull_request("foo", branch:, title: pr_title, description: pr_description)

    expect { call }.to output("[1/1] alphagov/foo ✅ PR raised\n").to_stdout

    expect(create_branch_stub).to have_been_requested
    expect(create_contents_stub).to have_been_requested
    expect(raise_pr_stub).to have_been_requested
  end

  it "raises PRs for repos where the file already exists, but not with the desired content" do
    stub_govuk_repos(%w[foo])
    stub_github_repo("foo", contents: { file_path => "Foo\n" })

    create_branch_stub = stub_create_branch_request("foo", branch)
    create_contents_stub = stub_update_contents_request("foo", path: file_path, content: file_content, previous_content: "Foo\n", commit_title: pr_title, branch:)
    raise_pr_stub = stub_create_pull_request("foo", branch:, title: pr_title, description: pr_description)

    expect { call }.to output("[1/1] alphagov/foo ✅ PR raised\n").to_stdout

    expect(create_branch_stub).to have_been_requested
    expect(create_contents_stub).to have_been_requested
    expect(raise_pr_stub).to have_been_requested
  end

  it "skips repos where the file already exists with the desired content" do
    stub_govuk_repos(%w[foo])
    stub_github_repo("foo", contents: { file_path => file_content })
    expect { call }.to output("[1/1] alphagov/foo ⏭  file already exists with desired content\n").to_stdout
  end

  it "does not raise PRs if the dry_run option is set" do
    stub_govuk_repos(%w[foo])
    stub_github_repo("foo")
    expect { call(dry_run: true) }.to output("[1/1] alphagov/foo ✅ would raise PR (dry run)\n").to_stdout
  end

  it "notifies the user if the repo does not exist" do
    stub_govuk_repos(%w[foo])
    stub_request(:get, "https://api.github.com/repos/alphagov/foo").to_return(status: 404)
    expect { call }.to output("[1/1] alphagov/foo ❌ repo doesn't exist (or we don't have permission)\n").to_stdout
  end

  it "raises PRs if the branch already exists (e.g. bulk change script was interrupted)" do
    stub_govuk_repos(%w[foo])
    stub_github_repo("foo", feature_branches: [branch])
    raise_pr_stub = stub_create_pull_request("foo", branch:, title: pr_title, description: pr_description)

    expect { call }.to output("[1/1] alphagov/foo ⏭  branch \"#{branch}\" already exists. Creating PR...\n✅ PR raised\n").to_stdout
    expect(raise_pr_stub).to have_been_requested
  end

  it "skips repos where the PR already exists" do
    stub_govuk_repos(%w[foo])
    stub_github_repo("foo", feature_branches: [branch])
    stub_create_branch_request("foo", branch)
    stub_create_contents_request("foo", path: file_path, content: file_content, commit_title: pr_title, branch:)
    stub_github_get_pull_requests("foo", branch)
    expect { call }.to output("[1/1] alphagov/foo ⏭  PR already exists\n").to_stdout
  end

  it "respects the if_any_exist filter" do
    stub_govuk_repos(%w[foo])
    stub_github_repo("foo", contents: { "existing_file" => "File content\n" })
    expect { call(if_any_exist: %w[nonexistent_file]) }.to output("[1/1] alphagov/foo ⏭  filters don't match\n").to_stdout
    expect { call(if_any_exist: %w[nonexistent_file existing_file], dry_run: true) }.to output("[1/1] alphagov/foo ✅ would raise PR (dry run)\n").to_stdout
  end

  it "respects the if_all_exist filter" do
    stub_govuk_repos(%w[foo])
    stub_github_repo("foo", contents: { "existing_file" => "File content\n" })
    expect { call(if_all_exist: %w[nonexistent_file existing_file]) }.to output("[1/1] alphagov/foo ⏭  filters don't match\n").to_stdout
    expect { call(if_all_exist: %w[existing_file], dry_run: true) }.to output("[1/1] alphagov/foo ✅ would raise PR (dry run)\n").to_stdout
  end

  it "respects the unless_any_exist filter" do
    stub_govuk_repos(%w[foo])
    stub_github_repo("foo", contents: { "existing_file" => "File content\n" })
    expect { call(unless_any_exist: %w[existing_file nonexistent_file]) }.to output("[1/1] alphagov/foo ⏭  filters don't match\n").to_stdout
    expect { call(unless_any_exist: %w[nonexistent_file], dry_run: true) }.to output("[1/1] alphagov/foo ✅ would raise PR (dry run)\n").to_stdout
  end

  it "respects the unless_all_exist filter" do
    stub_govuk_repos(%w[foo])
    stub_github_repo("foo", contents: { "existing_file" => "File content\n" })
    expect { call(unless_all_exist: %w[existing_file]) }.to output("[1/1] alphagov/foo ⏭  filters don't match\n").to_stdout
    expect { call(unless_all_exist: %w[existing_file nonexistent_file], dry_run: true) }.to output("[1/1] alphagov/foo ✅ would raise PR (dry run)\n").to_stdout
  end

  it "respects GitHub's rate limit headers" do
    stub_govuk_repos(%w[foo])

    rate_limit_expires_at = Time.now + 1
    github_request_stub = stub_request(:get, "https://api.github.com/repos/alphagov/foo")
      .to_return do |_request|
        if Time.now < rate_limit_expires_at
          {
            status: 403,
            headers: {
              "X-RateLimit-Limit" => 5000,
              "X-RateLimit-Remaining" => 0,
              "X-RateLimit-Reset" => rate_limit_expires_at.to_i,
            },
            body: "rate limit exceeded",
          }
        else
          { status: 404 }
        end
      end

    expect { call }.to output("[1/1] alphagov/foo ❌ repo doesn't exist (or we don't have permission)\n").to_stdout
    expect(github_request_stub).to have_been_requested.times(2)
  end
end
