require "util"

def bulk_replace(github_token:, file_path:, old_content:, new_content:, global:, branch:, pr_title:, pr_description:)
  Octokit.access_token = github_token

  quit_requested = false
  Signal.trap("INT") do
    print "Terminating..."
    quit_requested = true
  end

  puts "Search for references of '#{old_content}' and replace with '#{new_content}'"
  exit 0 unless confirm_action("Press 'y' to continue:")

  num_index_columns = govuk_repos.count.to_s.length
  num_name_columns = govuk_repos.map(&:length).max
  govuk_repos.each.with_index(1) do |repo_name, i|
    exit 130 if quit_requested

    print "[#{i.to_s.rjust(num_index_columns)}/#{govuk_repos.count}] #{repo_name.ljust(num_name_columns)} "

    repo = get_repo(repo_name)
    if repo.nil?
      puts "❌ repo doesn't exist (or we don't have permission)"
      next
    end

    existing_file = get_file_contents(repo_name, file_path)

    if existing_file.nil?
      puts "⏭  file not found"
    else
      existing_file_content = Base64.decode64(existing_file.content)
      if !existing_file_content.include?(old_content)
        puts "⏭  content not found in file"
      elsif repo_has_branch?(repo_name, branch)
        puts "⏭  branch \"#{branch}\" already exists"
      else
        new_file_content = if global
                             existing_file_content.gsub(old_content, new_content)
                           else
                             existing_file_content.sub(old_content, new_content)
                           end
        puts "\e[31mYou are about to create a new PR on `#{branch}` with the following changes:\e[0m"
        puts "-------------------------------------------"
        puts pr_title
        puts ""
        puts pr_description
        puts "-------------------------------------------"
        puts file_path
        puts diff(existing_file_content, new_file_content)
        puts "-------------------------------------------"
        printf "\e[31mPress 'y' to continue: \e[0m"
        prompt = $stdin.gets.chomp
        break unless prompt == "y"

        create_branch! repo, branch
        commit_file!(
          repo,
          path: file_path,
          content: new_file_content,
          commit_title: pr_title,
          branch:,
          sha: existing_file&.sha,
        )
        create_pr! repo, branch:, title: pr_title, description: pr_description

        puts "✅ PR raised"
      end
    end
  end
end
