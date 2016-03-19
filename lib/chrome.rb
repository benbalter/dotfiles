#!/usr/bin/env ruby
# Sets Chrome preferences

require 'json'

def set_prefs(file)
  file = File.expand_path(file)
  json = File.open(file).read
  prefs = JSON.parse(json)
  yield(prefs)
  File.write(file, prefs.to_json)
end

# Profile preferences
set_prefs('~/Library/Application Support/Google/Chrome/Default/Preferences') do |prefs|
  prefs['autofill']['enabled'] = false
  prefs['enable_do_not_track'] = true
  prefs['profile']['password_manager_enabled'] = false
  prefs['plugins']['plugins_list'].select { |p| p['name'] =~ /\bFlash\b/ }.each do |p|
    p['enabled'] = false
  end
end

# App state preferences
set_prefs('~/Library/Application Support/Google/Chrome/Local State') do |prefs|
  prefs['browser']['confirm_to_quit'] = true
end
