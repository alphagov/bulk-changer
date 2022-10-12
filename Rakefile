$LOAD_PATH.prepend "lib"

require "rspec/core/rake_task"
require "add_dependabot_sync_workflows"

RSpec::Core::RakeTask.new :spec

task :add_dependabot_sync_workflows do
  add_dependabot_sync_workflows!
end

task default: :spec
