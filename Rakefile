require "rspec/core/rake_task"
require_relative "lib/pr_raiser"

RSpec::Core::RakeTask.new :spec

task :raise_prs do
  PrRaiser.new.raise_prs!
end

task :default => :spec
