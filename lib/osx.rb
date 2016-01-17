#!/usr/bin/env ruby
# Sets OS X preferences

require 'CFPropertyList'
require 'deep_merge'
require 'yaml'

path = File.expand_path "../osx.yml", File.dirname(__FILE__)
prefs = YAML.load(File.open(path).read)

uuid = `ioreg -rd1 -c IOPlatformExpertDevice`.match(/"IOPlatformUUID" = "([0-9A-F-]{36})"/)[1]
user = `logname`.strip

prefs.each do |group, plists|
  plists.each do |plist, options|
    file = case group
    when "system"
      "/Library/Preferences/#{plist}.plist"
    when "user"
      "/Users/#{user}/Library/Preferences/#{plist}.plist"
    when "host"
      "/Users/#{user}/Library/preferences/ByHost/#{plist}.#{uuid}.plist"
    end
    plist = CFPropertyList::List.new file: file
    data = CFPropertyList.native_types(plist.value)
    data = options.deep_merge(data)
    plist.value = CFPropertyList.guess(data, :convert_unknown_to_string => true)
    plist.save
  end
end
