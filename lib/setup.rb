$LOAD_PATH.prepend "lib"

require "rubygems"
require "bundler/setup"
require "octokit"

Octokit.auto_paginate = true
