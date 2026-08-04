# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'

Rake::TestTask.new do |task|
  task.libs << 'test'
  task.pattern = 'test/**/*_test.rb'
  task.warning = true
end

RuboCop::RakeTask.new do |task|
  task.options = ['--ignore-parent-exclusion']
end

task default: %i[test rubocop]
