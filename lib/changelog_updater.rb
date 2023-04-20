require "util"

def changelog_updater(github_token:, branch:, changes:, change_type:, unreleased:, always_yes:)
  Octokit.access_token = github_token

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

    repo = get_repo(repo_name)
    if repo.nil?
      puts "❌ repo doesn't exist (or we don't have permission)"
      next
    end

    branch_exists = repo_has_branch?(repo_name, branch)
    file_path = "CHANGELOG.md"
    if branch_exists
      puts "⏭  branch \"#{branch}\" already exists"
      next unless confirm_action("Continue on existing branch?", always_yes:)

      existing_file = get_file_contents(repo_name, file_path, branch)
    else
      existing_file = get_file_contents(repo_name, file_path)
    end

    if existing_file.nil?
      puts "❌ CHANGELOG.md not found in #{repo_name}"
      next
    end

    existing_file_content = Base64.decode64(existing_file.content)
    version_header_regex = /(?:^|\n)##?\s*(\d+\.\d+\.\d+)\s*\n/
    match_data = version_header_regex.match(existing_file_content)
    if match_data.nil?
      puts "❌ No version found in CHANGELOG.md"
      next
    end

    if unreleased
      new_file_content = insert_unreleased_changes(existing_file_content, changes)
    else
      new_version = semver_increment(match_data[1], change_type.to_sym)
      new_file_content = insert_new_version_section(existing_file_content, new_version, changes)
    end

    puts "Changes to be made in #{repo_name}:"
    puts diff(existing_file_content, new_file_content)

    proceed = false
    until proceed
      print "Proceed with these changes? (y)es, (e)dit or (n)o? "
      choice = gets.chomp.downcase

      case choice
      when "y"
        proceed = true
      when "e"
        new_file_content = edit_content(new_file_content)

        puts "Updated changes:"
        puts diff(existing_file_content, new_file_content)
      when "n"
        puts "Skipping changes for #{repo_name}"
        break
      else
        puts "Invalid option, please choose (y)es, (e)dit or (n)o."
      end
    end

    next unless proceed

    commit_title = "Update CHANGELOG.md"
    commit_description = "Updates the CHANGELOG.md file to include the following changes:\n\n#{changes}"

    branch_created = create_branch!(repo, branch) unless branch_exists

    if branch_created || branch_exists
      commit_file!(
        repo,
        path: file_path,
        content: new_file_content,
        commit_title: "#{commit_title}\n\n#{commit_description}",
        branch:,
        sha: existing_file&.sha,
      )

      if repo_has_pr?(repo_name, branch)
        puts "✅ commit added to PR for #{repo_name}"
      else
        create_pr!(
          repo,
          branch:,
          title: commit_title,
          description: commit_description,
        )
        puts "✅ PR raised for #{repo_name}"
      end
    end
  end
end
