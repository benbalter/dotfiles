# -*- encoding: utf-8 -*-
require File.expand_path('../lib/osxsub/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Mark Wunsch"]
  gem.email         = ["mark@markwunsch.com"]
  gem.description   = %q{Command line utility for OS X Text Substition Preferences.}
  gem.summary       = %q{Command line utility for OS X Text Substition Preferences.}
  gem.homepage      = %q{http://github.com/mwunsch/osxsub}

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "osxsub"
  gem.require_paths = ["lib"]
  gem.version       = OsxSub::VERSION
end
