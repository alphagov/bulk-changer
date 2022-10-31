require "setup"
require "webmock/rspec"

RSpec.configure do |config|
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed

  # The following options will be defaults in RSpec v4, and can be removed when it releases
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups
end

def stub_govuk_repos(repo_names)
  stub_request(:get, "https://docs.publishing.service.gov.uk/repos.json").
    to_return(
      status: 200,
      headers: { "Content-Type": "application/json" },
      body: repo_names.map { |repo_name| { "app_name": repo_name } }.to_json
    )
end

def stub_github_repo(repo_name, feature_branches: [], contents: [])
  stub_request(:get, "https://api.github.com/repos/alphagov/#{repo_name}").
    to_return(
      status: 200,
      headers: { "Content-Type": "application/json" },
      body: {
        name: repo_name,
        full_name: "alphagov/#{repo_name}",
        default_branch: "main"
      }.to_json
    )
  
  stub_request(:get, %r{\Ahttps://api.github.com/repos/alphagov/#{repo_name}/git/refs/heads/.+\z}).to_return(status: 404)
  (["main"] + feature_branches).each do |branch|
    stub_request(:get, "https://api.github.com/repos/alphagov/#{repo_name}/git/refs/heads/#{branch}").
      to_return(
        status: 200,
        headers: { "Content-Type": "application/json" },
        body: {
          "ref": "refs/heads/main",
          "object": { "sha": "123" }
        }.to_json
      )
  end
  
  stub_request(:get, %r{\Ahttps://api.github.com/repos/alphagov/#{repo_name}/contents/.+\z}).to_return(status: 404)
  contents.each do |path, content|
    stub_request(:get, "https://api.github.com/repos/alphagov/#{repo_name}/contents/#{path}").
      to_return(
        status: 200,
        headers: { "Content-Type": "application/json" },
        body: {
          sha: Digest::SHA1.hexdigest("blob #{content.length}\0#{content}"),
          content: Base64.encode64(content),
        }.to_json
      )
  end
end

def stub_create_branch_request(repo_name, branch_name)
  stub_request(:post, "https://api.github.com/repos/alphagov/#{repo_name}/git/refs").
    with(body: { ref: "refs/heads/#{branch_name}", "sha": "123" }).
    to_return(status: 200)
end

def stub_update_contents_request(repo_name, path:, content:, previous_content:, commit_title:, branch:)
  stub_request(:put, "https://api.github.com/repos/alphagov/#{repo_name}/contents/#{path}").
    with(
      body: {
        branch: branch,
        content: Base64.strict_encode64(content),
        message: commit_title,
        sha: Digest::SHA1.hexdigest("blob #{previous_content.length}\0#{previous_content}")
      }
    ).
    to_return(status: 200)
end

def stub_create_contents_request(repo_name, path:, content:, commit_title:, branch:)
  stub_request(:put, "https://api.github.com/repos/alphagov/#{repo_name}/contents/#{path}").
    with(
      body: {
        "branch": branch,
        "content": Base64.encode64(content).gsub(/\n/, ""),
        "message": commit_title,
      }
    ).
    to_return(status: 200)
end

def stub_create_pull_request(repo_name, branch:, title:, description:)
  stub_request(:post, "https://api.github.com/repos/alphagov/#{repo_name}/pulls").
    with(
      body: {
        "base": "main",
        "head": branch,
        "title": title,
        "body": description,
      }
    ).
    to_return(status: 200)
end
