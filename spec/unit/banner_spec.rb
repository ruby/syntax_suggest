# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe Banner do
    it "Unmatched | banner" do
      source = <<~EOM
        Foo.call do |
        end
      EOM

      invalid_obj = WhoDisSyntaxError.new(source)
      banner = Banner.new(invalid_obj: invalid_obj)
      expect(banner.call).to include("Unmatched `|` character detected")
    end

    it "Unmatched { banner" do
      source = <<~EOM
        class Cat
          lol = {
        end
      EOM

      invalid_obj = WhoDisSyntaxError.new(source)
      banner = Banner.new(invalid_obj: invalid_obj)
      expect(banner.call).to include("Unmatched `{` character detected")
    end

    it "Unmatched } banner" do
      skip("Unsupported ruby version") unless Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.7")

      source = <<~EOM
        def foo
          lol = }
        end
      EOM

      invalid_obj = WhoDisSyntaxError.new(source)
      banner = Banner.new(invalid_obj: invalid_obj)
      expect(banner.call).to include("Unmatched `}` character detected")
    end

    it "Unmatched [ banner" do
      source = <<~EOM
        class Cat
          lol = [
        end
      EOM

      invalid_obj = WhoDisSyntaxError.new(source)
      banner = Banner.new(invalid_obj: invalid_obj)
      expect(banner.call).to include("Unmatched `[` character detected")
    end

    it "Unmatched ] banner" do
      source = <<~EOM
        def foo
          lol = ]
        end
      EOM

      invalid_obj = WhoDisSyntaxError.new(source)
      banner = Banner.new(invalid_obj: invalid_obj)
      expect(banner.call).to include("Unmatched `]` character detected")
    end

    it "Unmatched end banner" do
      source = <<~EOM
        class Cat
          end
        end
      EOM

      invalid_obj = WhoDisSyntaxError.new(source)
      banner = Banner.new(invalid_obj: invalid_obj)
      expect(banner.call).to include("DeadEnd: Unmatched `end` detected")
    end

    it "Unmatched unknown banner" do
      source = <<~EOM
        class Cat
          def meow
            1 *
          end
        end
      EOM

      invalid_obj = WhoDisSyntaxError.new(source)
      banner = Banner.new(invalid_obj: invalid_obj)
      expect(banner.call).to include("DeadEnd: Unmatched `unknown` detected")
    end

    it "missing end banner" do
      source = <<~EOM
        class Cat
          def meow
        end
      EOM

      invalid_obj = WhoDisSyntaxError.new(source)
      banner = Banner.new(invalid_obj: invalid_obj)
      expect(banner.call).to include("DeadEnd: Missing `end` detected")
    end

    it "naked (closing) parenthesis" do
      invalid_obj = WhoDisSyntaxError.new("def initialize; ); end").call

      expect(
        Banner.new(invalid_obj: invalid_obj).call
      ).to include("Unmatched `)` character detected")
    end

    it "naked (opening) parenthesis" do
      invalid_obj = WhoDisSyntaxError.new("def initialize; (; end").call

      expect(
        Banner.new(invalid_obj: invalid_obj).call
      ).to include("Unmatched `(` character detected")
    end
  end
end
