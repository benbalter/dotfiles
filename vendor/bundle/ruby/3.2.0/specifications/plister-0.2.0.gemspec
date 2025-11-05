# -*- encoding: utf-8 -*-
# stub: plister 0.2.0 ruby lib

Gem::Specification.new do |s|
  s.name = "plister".freeze
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Ben Balter".freeze]
  s.date = "2016-08-30"
  s.email = ["ben.balter@github.com".freeze]
  s.executables = ["plister".freeze]
  s.files = ["bin/plister".freeze]
  s.homepage = "https://github.com/benbalter/plister".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "A utility for programmatically setting OS X plist file preferences".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<CFPropertyList>.freeze, ["~> 2.3"])
  s.add_runtime_dependency(%q<deep_merge>.freeze, ["~> 1.0"])
  s.add_runtime_dependency(%q<slop>.freeze, ["~> 4.0"])
  s.add_development_dependency(%q<bundler>.freeze, ["~> 1.11"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 10.0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 0.36"])
end
