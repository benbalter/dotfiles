#!/usr/bin/env ruby

require 'yaml'

installed = `mas list`.split("\n").map { |line| line.split(" ").first.to_i }
apps = YAML.load_file File.expand_path("~/.mas.yml")
apps.each do |id, name|
  if installed.include? id
    puts "#{name} is already installed"
  else
    puts "Installing #{name}"
    `mas install #{id}`
  end
end
