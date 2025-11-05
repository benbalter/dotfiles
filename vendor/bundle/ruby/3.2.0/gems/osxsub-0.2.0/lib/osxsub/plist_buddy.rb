module OsxSub
  class PlistBuddyError < StandardError
    def exists?
      !message.match(/Does Not Exist$/)
    end
  end

  class PlistBuddy
    require 'singleton'

    include Singleton

    PLIST_BUDDY = '/usr/libexec/PlistBuddy'
    GLOBAL_PREFERENCES_PLIST = File.expand_path('~/Library/Preferences/.GlobalPreferences.plist')
    NSUSER_REPLACEMENT_ITEMS = 'NSUserDictionaryReplacementItems'

    def print
      execute plist_buddy(:print)
    end

    def delete
      execute plist_buddy(:delete)
    end

    def add
      execute plist_buddy(:add, "array")
    end

    def merge(path)
      execute plist_buddy("Merge #{path}")
    end

    def plist_buddy(command, *extras)
      %Q[#{PLIST_BUDDY} -x -c "#{command.to_s.capitalize} #{NSUSER_REPLACEMENT_ITEMS} #{extras.join(' ')}" #{GLOBAL_PREFERENCES_PLIST}]
    end

    def execute(command)
      require 'stringio'
      require 'open3'

      out, err = ::StringIO.new, ::StringIO.new
      ::Open3.popen3(command) do |stdin, stdout, stderr|
        out.write stdout.read
        err.write stderr.read
      end
      raise PlistBuddyError, err.string unless err.string.empty?
      out.string
    end
  end
end
