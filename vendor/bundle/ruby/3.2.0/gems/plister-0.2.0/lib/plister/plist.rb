module Plister
  class Plist
    attr_accessor :domain, :type
    TYPES = %w(user system host).freeze

    def initialize(domain, type: 'user')
      @domain = normalize_domain(domain)
      @type   = type.to_s
      raise ArgumentError, 'Invalid type' unless valid_type?
    end

    def preferences
      @preferences ||= CFPropertyList.native_types(list.value)
    rescue CFFormatError
      {}
    end
    alias to_h preferences

    def preferences=(prefs)
      list.value = CFPropertyList.guess(prefs, convert_unknown_to_string: true)
      @preferenes = nil
      preferences
    end

    def merge(prefs)
      self.preferences = preferences.deep_merge(prefs)
    end

    def write
      raise IOError, "#{path} is not writable by #{Plister.user}" unless writable?
      list.save
    end

    def exists?
      File.exist?(path)
    end

    def writable?
      File.writable?(path)
    end

    def readable?
      File.readable?(path)
    end

    private

    def path
      @path ||= begin
        case type
        when 'system'
          "/Library/Preferences/#{domain}.plist"
        when 'user'
          "/Users/#{Plister.user}/Library/Preferences/#{domain}.plist"
        when 'host'
          "/Users/#{Plister.user}/Library/preferences/ByHost/#{domain}.#{Plister.uuid}.plist"
        end
      end
    end

    def list
      raise IOError, "#{path} does not exist" unless exists?
      raise IOError, "#{path} is not readable by #{Plister.user}" unless readable?
      @list ||= CFPropertyList::List.new file: path
    end

    def valid_type?
      TYPES.include?(type)
    end

    def normalize_domain(domain)
      domain = File.basename(domain)
      domain = domain.sub(/\.plist\z/, '')
      domain = domain.sub(/\.#{Plister.uuid}\z/, '')
      domain
    end
  end
end
