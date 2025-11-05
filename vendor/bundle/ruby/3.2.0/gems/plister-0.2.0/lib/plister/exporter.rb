module Plister
  class Exporter
    attr_reader :path

    def initialize(path = nil)
      @path = path || "/Users/#{Plister.user}/.osx.yml"
    end

    def export
      File.write path, to_s
    end

    def to_s
      Psych.dump(preferences)
    end

    private

    def types
      @types ||= {
        system: '/Library/Preferences',
        user:   "/Users/#{Plister.user}/Library/Preferences",
        host:   "/Users/#{Plister.user}/Library/preferences/ByHost"
      }
    end

    def paths
      @paths ||= types.map { |type, path| [type, Dir["#{path}/*.plist"]] }.to_h
    end

    def preferences
      @preferences ||= begin
        output = {}
        paths.each do |type, plist_paths|
          plists = plist_paths.map { |domain| Plist.new domain, type: type }
          plists.select!(&:readable?)
          output[type.to_s] = plists.map { |p| [p.domain, p.to_h] }.to_h
        end
        output
      end
    end
  end
end
