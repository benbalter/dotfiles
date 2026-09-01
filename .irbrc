# frozen_string_literal: true

# https://github.com/carlhuda/bundler/issues/183#issuecomment-1149953
if defined?(Bundler)
  global_gemset = ENV['GEM_PATH'].split(':').grep(/ruby.*@global/).first
  if global_gemset
    all_global_gem_paths = Dir.glob("#{global_gemset}/gems/*")
    all_global_gem_paths.each do |p|
      gem_path = "#{p}/lib"
      $LOAD_PATH << gem_path
    end
  end
end

require 'irb/completion'
require 'irb/ext/save-history'

IRB.conf[:SAVE_HISTORY] = 100000
IRB.conf[:HISTORY_FILE] = "#{Dir.home}/.history/ruby"
IRB.conf[:PROMPT_MODE] = :SIMPLE
IRB.conf[:AUTO_INDENT] = true
IRB.conf[:USE_AUTOCOMPLETE] = true
IRB.conf[:USE_COLORIZE] = true

# Use Pry everywhere
require 'pry'
if $stdin.tty?
  Pry.start
  exit
end
