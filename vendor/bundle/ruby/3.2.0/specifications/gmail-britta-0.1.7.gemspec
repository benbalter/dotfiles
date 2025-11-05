# -*- encoding: utf-8 -*-
# stub: gmail-britta 0.1.7 ruby lib

Gem::Specification.new do |s|
  s.name = "gmail-britta".freeze
  s.version = "0.1.7"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Andreas Fuchs".freeze]
  s.date = "2016-01-29"
  s.description = "This gem helps create large (>50) gmail filter chains by writing xml compatible with gmail's \"import/export filters\" feature.".freeze
  s.email = "asf@boinkor.net".freeze
  s.extra_rdoc_files = ["LICENSE.txt".freeze, "README.md".freeze]
  s.files = ["LICENSE.txt".freeze, "README.md".freeze]
  s.homepage = "http://github.com/antifuchs/gmail-britta".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Create complex gmail filtersets with a ruby DSL.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<haml>.freeze, ["~> 3.1.6"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0.9.2"])
  s.add_development_dependency(%q<shoulda>.freeze, [">= 0"])
  s.add_development_dependency(%q<bundler>.freeze, [">= 1.2.0"])
  s.add_development_dependency(%q<minitest>.freeze, [">= 0"])
  s.add_development_dependency(%q<nokogiri>.freeze, [">= 0"])
end
