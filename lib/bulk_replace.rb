require "util"

def bulk_replace(github_token:, file_path:, old_content:, new_content:, global:, branch:, commit_title:, commit_description:, pr_title:, pr_description:, use_regex:, continue_on_existing_branch:, file_path_is_regex:)
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

    branch_exists = repo_has_branch?(repo_name, branch)

    if file_path_is_regex
      files_in_repo = list_files_in_repo(repo_name, branch: branch_exists ? branch : nil)
      matching_files = files_in_repo.select { |path| Regexp.compile(file_path).match?(path) }
    else
      matching_files = [file_path]
    end

    matching_files.each do |file|
      if branch_exists
        puts "⏭  branch \"#{branch}\" already exists"
        next unless confirm_action("Continue on existing branch?", continue_on_existing_branch:)

        existing_file = get_file_contents(repo_name, file, branch)
      else
        existing_file = get_file_contents(repo_name, file)
      end

      if existing_file.nil?
        puts "⏭  file not found"
      else
        existing_file_content = Base64.decode64(existing_file.content)
        old_content_regex = use_regex ? Regexp.new(old_content) : Regexp.new(Regexp.escape(old_content))
        has_pr = repo_has_pr?(repo_name, branch)
        if !old_content_regex.match?(existing_file_content)
          puts "⏭  content not found in file"
        else
          new_file_content = if global
                               existing_file_content.gsub(old_content_regex, new_content)
                             else
                               existing_file_content.sub(old_content_regex, new_content)
                             end

          branch_created = create_branch!(repo, branch) unless branch_exists
          if branch_created || branch_exists
            puts "\e[31mYou are about to #{has_pr ? 'add a commit to an existing' : 'create a new'} PR on `#{branch}` with the following changes:\e[0m"
            puts "-------------------------------------------"
            puts pr_title ||= commit_title
            puts ""
            puts pr_description ||= commit_description
            puts "-------------------------------------------"
            puts file
            puts diff(existing_file_content, new_file_content)
            puts "-------------------------------------------"
            proceed = false
            until proceed
              print "Proceed with these changes? (y)es, (e)dit or (n)o? "
              choice = $stdin.gets.chomp.downcase

              case choice
              when "y", "yes"
                proceed = true
              when "e", "edit"
                edited_content = edit_content(new_file_content)
                new_file_content = edited_content

                puts "Updated changes:"
                puts diff(existing_file_content, new_file_content)
              when "n", "no"
                puts "Skipping changes for #{repo_name}"
                break
              else
                puts "Invalid option, please choose (y)es, (e)dit or (n)o."
              end
            end

            next unless proceed

            commit_file!(
              repo,
              path: file,
              content: new_file_content,
              commit_title: "#{commit_title}\n\n#{commit_description}",
              branch:,
              sha: existing_file&.sha,
            )

            if has_pr
              puts "✅ commit added to PR"
            else
              create_pr! repo, branch:, title: pr_title, description: pr_description
              puts "✅ PR raised"
            end
          end
        end
      end
    end
  end
end
