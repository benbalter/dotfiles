require 'cfpropertylist'
require 'deep_merge'
require 'psych'

require_relative 'plister/version'
require_relative 'plister/plist'
require_relative 'plister/preferences'
require_relative 'plister/exporter'

module Plister
  class << self
    def preferences(path = nil)
      Plister::Preferences.new(path)
    end

    def user
      @user ||= begin
        user = `whoami`.strip
        return user unless user == 'root'
        `logname`.strip
      end
    end

    def uuid
      @uuid ||= begin
        uuid = `ioreg -rd1 -c IOPlatformExpertDevice`
        matches = uuid.match(/"IOPlatformUUID" = "([0-9A-F-]{36})"/)
        matches[1] if matches
      end
    end
  end
end
