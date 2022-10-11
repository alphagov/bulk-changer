require "minitest/test_task"
require_relative "lib/pr_raiser"

Minitest::TestTask.create

task :raise_prs do
  PrRaiser.new.raise_prs!
end

task :default => :test
