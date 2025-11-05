module Plister
  class Preferences
    attr_reader :path

    def initialize(path = nil)
      @path = path || "/Users/#{Plister.user}/.osx.yml"
    end

    def set!(verbose: false)
      data.each do |type, domains|
        domains.each do |domain, prefs|
          puts "Setting #{type} preferences for #{domain}" if verbose
          plist = Plist.new(domain, type: type)
          plist.merge(prefs)
          plist.write
        end
      end
    end

    def domains
      @domains ||= data.map { |_k, v| v.keys }.flatten
    end

    private

    def data
      @data ||= Psych.load(contents) || {}
    end

    def contents
      @contents ||= File.open(path).read
    end
  end
end
