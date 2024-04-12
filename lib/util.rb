require "octokit"
require "open-uri"
require "diffy"
require "tempfile"

def govuk_repos
  @govuk_repos ||= JSON.parse(
    URI.open("https://docs.publishing.service.gov.uk/repos.json").read,
  ).map do |repo|
    "alphagov/#{repo['app_name']}"
  end
end

def create_branch!(repo, branch_name)
  sleep 1
  main_branch = Octokit.ref(repo.full_name, "heads/#{repo.default_branch}")
  Octokit.create_ref(repo.full_name, "refs/heads/#{branch_name}", main_branch.object.sha)
rescue Octokit::NotFound, Octokit::UnprocessableEntity => e
  puts "❌ Failed to create branch: #{e.message}"
  puts "Check if '#{branch_name}' already exists or if you have the necessary permissions."
  false
end

def commit_file!(repo, path:, content:, commit_title:, branch:, sha: nil)
  sleep 1
  Octokit.create_contents(
    repo.full_name,
    path,
    commit_title,
    content,
    { branch: }.merge(sha.nil? ? {} : { sha: }),
  )
rescue Octokit::NotFound, Octokit::UnprocessableEntity => e
  puts "❌ Failed to commit file: #{e.message}"
  puts "Check if '#{path}' exists or if you have the necessary permissions."
  false
end

def create_pr!(repo, branch:, title:, description:)
  sleep 1
  Octokit.create_pull_request(
    repo.full_name,
    repo.default_branch,
    branch,
    title,
    description,
  )
rescue Octokit::NotFound, Octokit::UnprocessableEntity => e
  puts "❌ Failed to create PR: #{e.message}"
end

def get_file_contents(repo_name, path, ref = nil)
  options = { path: }
  options[:ref] = ref if ref
  Octokit.contents(repo_name, options)
rescue Octokit::NotFound
  nil
end

def repo_contains_file?(repo_name, path)
  !get_file_contents(repo_name, path).nil?
end

def repo_has_branch?(repo_name, branch_name)
  Octokit.ref(repo_name, "heads/#{branch_name}")
  true
rescue Octokit::NotFound
  false
end

def repo_has_pr?(repo_name, branch_name)
  org_name = repo_name.split("/").first
  Octokit.pull_requests(repo_name, head: "#{org_name}:#{branch_name}").count.positive?
rescue Octokit::NotFound
  false
end

def list_files_in_repo(repo_name, branch: nil, recursive: false)
  branch_sha = if branch
                 Octokit.ref(repo_name, "heads/#{branch}").object.sha
               else
                 Octokit.ref(repo_name, "heads/#{Octokit.repository(repo_name).default_branch}").object.sha
               end

  options = recursive ? { recursive: true } : {}
  tree = Octokit.tree(repo_name, branch_sha, options)
  tree.tree.select { |node| node.type == "blob" }.map(&:path)
rescue Octokit::NotFound
  []
end

def diff(string1, string2)
  Diffy::Diff.new("#{string1}\n", "#{string2}\n").to_s :color
end

def confirm_action(message, overwrite_branch: false)
  return true if overwrite_branch

  printf "\e[31m#{message} (y/n): \e[0m"
  prompt = $stdin.gets.chomp
  prompt.casecmp?("y")
end

def edit_content(content)
  temp_file = Tempfile.new("tempfile_#{Time.now.to_i}")

  temp_file.write(content)
  temp_file.close

  editor = ENV["EDITOR"] || "vi"
  system("#{editor} #{temp_file.path}")

  edited_content = File.read(temp_file.path)
  temp_file.unlink
  edited_content
end

def get_repo(repo_name)
  Octokit.repo(repo_name)
rescue Octokit::NotFound
  nil
end
