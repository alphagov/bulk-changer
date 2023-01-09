require "util"

# rubocop:disable Layout/MultilineOperationIndentation, Layout/SpaceInsideParens, Style/InverseMethods
def filter_matches?(repo_name, if_any_exist, if_all_exist, unless_any_exist, unless_all_exist)
  predicate = ->(path) { repo_contains_file? repo_name, path }
  (    if_any_exist.empty? ||      if_any_exist.any?(&predicate)) &&
  (    if_all_exist.empty? ||      if_all_exist.all?(&predicate)) &&
  (unless_any_exist.empty? || !unless_any_exist.any?(&predicate)) &&
  (unless_all_exist.empty? || !unless_all_exist.all?(&predicate))
end
# rubocop:enable Layout/MultilineOperationIndentation, Layout/SpaceInsideParens, Style/InverseMethods

def bulk_update_file(dry_run:, github_token:, file_path:, file_content:, branch:, pr_title:, pr_description:, if_any_exist:, if_all_exist:, unless_any_exist:, unless_all_exist:)
  Octokit.access_token = github_token

  file_content = "#{file_content}\n" unless file_content.end_with?("\n")

  quit_requested = false
  Signal.trap("INT") do
    print "Terminating..."
    quit_requested = true
  end

  num_index_columns = govuk_repos.count.to_s.length
  num_name_columns = govuk_repos.map(&:length).max
  govuk_repos.each.with_index(1) do |repo_name, i|
    exit 130 if quit_requested

    print "[#{i.to_s.rjust(num_index_columns)}/#{govuk_repos.count}] #{repo_name.ljust(num_name_columns)} "

    repo = begin
      Octokit.repo(repo_name)
    rescue Octokit::NotFound
      puts "❌ repo doesn't exist (or we don't have permission)"
      next
    end

    existing_file_on_main = get_file_contents repo_name, file_path
    branch_exists = repo_has_branch? repo_name, branch
    pr_exists = repo_has_pr_for_branch? repo_name, branch
    existing_file_in_pr = pr_exists ? get_file_contents(repo_name, file_path, branch) : nil
    if !existing_file_on_main.nil? && file_content == Base64.decode64(existing_file_on_main.content)
      puts "⏭  file already exists with desired content"
    elsif branch_exists && pr_exists && file_content == Base64.decode64(existing_file_in_pr.content)
      puts "⏭  PR already created"
    elsif !filter_matches?(repo_name, if_any_exist, if_all_exist, unless_any_exist, unless_all_exist)
      puts "⏭  filters don't match"
    elsif dry_run
      puts "✅ would raise PR (dry run)"
    else
      create_branch! repo, branch unless branch_exists
      commit_file!(
        repo,
        path: file_path,
        content: file_content,
        commit_title: pr_title,
        branch:,
        sha: (pr_exists ? existing_file_in_pr : existing_file_on_main)&.sha,
      )
      create_pr! repo, branch: branch, title: pr_title, description: pr_description unless pr_exists

      puts "✅ PR raised"
    end
  end
end
