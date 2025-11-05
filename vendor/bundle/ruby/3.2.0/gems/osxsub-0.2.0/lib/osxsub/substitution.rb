module OsxSub
  class Substitution
    attr_reader :replace, :with

    def initialize(replace, with, on = true)
      @replace = replace
      @with = with
      @on = on
    end

    def on?
      return false if @on.is_a? String and @on.to_i <= 0
      true & @on
    end

    def sub(string)
      string.gsub(replace, with)
    end
  end
end
