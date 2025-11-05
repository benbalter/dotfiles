require 'rexml/document'

module OsxSub
  class NSUserReplacementItems
    require 'erb'

    PLIST_TEMPLATE = <<-PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
  <% substitutions.each do |substitution| %>
	<dict>
    <% if substitution.on? %>
		<key>on</key>
		<integer>1</integer>
    <% end %>
		<key>replace</key>
		<string><%= html_escape substitution.replace %></string>
		<key>with</key>
		<string><%= html_escape substitution.with %></string>
	</dict>
  <% end %>
</array>
</plist>
    PLIST

    def self.from_plist_buddy
      plist_buddy = PlistBuddy.instance
      self.from_xml plist_buddy.print
    rescue PlistBuddyError => e
      unless e.exists?
        warn("#{e}Adding and Merging default preferences")
        plist_buddy.add
        self.defaults.merge!
        retry
      end
    end

    def self.from_xml(xml)
      doc = REXML::Document.new(xml, :ignore_whitespace_nodes => :all)
      plist = doc.elements['plist/array'].map do |dict|
        tuple = dict.each.select {|node| node.has_name?("key") }.map do |key|
          [key.text, key.next_element.text]
        end
        Hash[tuple]
      end
      self.new plist.map {|dict| Substitution.new(dict['replace'], dict['with'], dict['on']) }
    end

    def self.defaults
      default_substitutions = [
        Substitution.new("(c)", "\xC2\xA9"),
        Substitution.new("(r)", "\xC2\xAE"),
        Substitution.new("(p)", "\xE2\x84\x97"),
        Substitution.new("TM", "\xE2\x84\xA2"),
        Substitution.new("c/o", "\xE2\x84\x85"),
        Substitution.new("...", "\xE2\x80\xA6"),
        Substitution.new("1/2", "\xC2\xBD", false),
        Substitution.new("1/3", "\xE2\x85\x93", false),
        Substitution.new("2/3", "\xE2\x85\x94", false),
        Substitution.new("1/4", "\xC2\xBC", false),
        Substitution.new("3/4", "\xC2\xBE", false),
        Substitution.new("1/8", "\xE2\x85\x9B", false),
        Substitution.new("3/8", "\xE2\x85\x9C", false),
        Substitution.new("5/8", "\xE2\x85\x9D", false),
        Substitution.new("7/8", "\xE2\x85\x9E", false)
      ]
      self.new(default_substitutions)
    end

    include ERB::Util

    attr_reader :substitutions

    def initialize(substitutions)
      @substitutions = substitutions
    end

    def sub(text)
      substitutions.select(&:on?).inject(text) {|memo, obj| obj.sub(memo) }
    end

    def to_plist
      template = ERB.new(PLIST_TEMPLATE, nil, '>')
      template.result(binding)
    end

    def merge!
      tmp_file = temp_plist_file
      PlistBuddy.instance.merge tmp_file.path
    ensure
      if tmp_file
        tmp_file.close
        tmp_file.unlink
      end
    end

  private

    def temp_plist_file
      require 'tempfile'
      tmp_file = Tempfile.new("nsuser_replacement_items_plist")
      tmp_file.write to_plist
      tmp_file.rewind
      tmp_file
    end
  end
end

