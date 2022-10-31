require "util"

def filter_matches?(repo_name, allowlist, blocklist)
  allowlist.all?  { |path| repo_contains_file?(repo_name, path) } &&
  blocklist.none? { |path| repo_contains_file?(repo_name, path) }
end

def bulk_update_file(dry_run:, github_token:, file_path:, file_content:, branch:, pr_title:, pr_description:, if_file_exists:, unless_file_exists:)
  Octokit.access_token = github_token

  num_index_columns = govuk_repos.count.to_s.length
  num_name_columns = govuk_repos.map(&:length).max
  govuk_repos.each.with_index(1) do |repo_name, i|
    print "[#{i.to_s.rjust(num_index_columns)}/#{govuk_repos.count}] #{repo_name.ljust(num_name_columns)} "

    repo = begin
      Octokit.repo(repo_name)
    rescue Octokit::NotFound
      puts "❌ repo doesn't exist (or we don't have permission)"
      next
    end

    existing_file = get_file_contents(repo_name, file_path)
    if !existing_file.nil? && file_content == Base64.decode64(existing_file.content)
      puts "⏭  file already exists with desired content"
    elsif repo_has_branch?(repo_name, branch)
      puts "⏭  branch \"#{branch}\" already exists"
    elsif !filter_matches?(repo_name, if_file_exists, unless_file_exists)
      puts "⏭  filters don't match"
    elsif dry_run
      puts "✅ would raise PR (dry run)"
    else
      create_branch! repo, branch
      commit_file!(
        repo,
        path: file_path,
        content: file_content,
        commit_title: pr_title,
        branch: branch,
        sha: existing_file&.sha,
      )
      create_pr! repo, branch: branch, title: pr_title, description: pr_description

      puts "✅ PR raised"
    end
  end
end
