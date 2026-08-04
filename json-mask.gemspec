# frozen_string_literal: true

require_relative 'lib/json_mask/version'

Gem::Specification.new do |spec|
  spec.name = 'json-mask'
  spec.version = JsonMask::VERSION
  spec.authors = ['Robert Sheldon']
  spec.email = ['rsheldon@wistia.com']

  spec.summary = 'Select fields from JSON-compatible Ruby objects without changing their shape'
  spec.description = <<~DESCRIPTION
    A dependency-free implementation of the Google partial-response and JSON Mask fields
    language for filtering Hash and Array response data.
  DESCRIPTION
  spec.homepage = 'https://github.com/rsheldiii/json-mask-ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1'

  spec.metadata = {
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'changelog_uri' => "#{spec.homepage}/blob/main/CHANGELOG.md",
    'rubygems_mfa_required' => 'true',
    'source_code_uri' => spec.homepage
  }

  spec.files = Dir.chdir(__dir__) do
    Dir['CHANGELOG.md', 'LICENSE.txt', 'README.md', 'lib/**/*.rb']
  end
  spec.require_paths = ['lib']
end
