# -*- encoding: utf-8 -*-
# stub: haml 3.1.8 ruby lib

Gem::Specification.new do |s|
  s.name = "haml".freeze
  s.version = "3.1.8"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Nathan Weizenbaum".freeze, "Hampton Catlin".freeze, "Norman Clarke".freeze]
  s.date = "2013-02-13"
  s.description = "      Haml (HTML Abstraction Markup Language) is a layer on top of XHTML or XML\n      that's designed to express the structure of XHTML or XML documents\n      in a non-repetitive, elegant, easy way,\n      using indentation rather than closing tags\n      and allowing Ruby to be embedded with ease.\n      It was originally envisioned as a plugin for Ruby on Rails,\n      but it can function as a stand-alone templating engine.\n".freeze
  s.email = ["haml@googlegroups.com".freeze, "norman@njclarke.com".freeze]
  s.executables = ["haml".freeze, "html2haml".freeze]
  s.files = ["bin/haml".freeze, "bin/html2haml".freeze]
  s.homepage = "http://haml.info/".freeze
  s.rubygems_version = "3.4.20".freeze
  s.summary = "An elegant, structured XHTML/XML templating engine.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 3

  s.add_development_dependency(%q<yard>.freeze, [">= 0.5.3"])
  s.add_development_dependency(%q<maruku>.freeze, [">= 0.5.9"])
end
