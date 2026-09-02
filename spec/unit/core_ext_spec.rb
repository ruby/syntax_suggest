require_relative "../spec_helper"

module SyntaxSuggest
  RSpec.describe "Core extension" do
    it "SyntaxError monkepatch ensures there is a newline to the end of the file" do
      Dir.mktmpdir do |dir|
        tmpdir = Pathname(dir)
        file = tmpdir.join("file.rb")
        file.write(<<~EOM.strip)
          print 'no newline
        EOM

        core_ext_file = lib_dir.join("syntax_suggest").join("core_ext")
        require_relative core_ext_file

        original_message = "blerg"
        error = SyntaxError.new(original_message)
        def error.set_tmp_path_for_testing=(path)
          @tmp_path_for_testing = path
        end
        error.set_tmp_path_for_testing = file
        def error.path
          @tmp_path_for_testing
        end

        detailed = error.detailed_message(highlight: false, syntax_suggest: true)
        expect(detailed).to include("'no newline\n#{original_message}")
        expect(detailed).to_not include("print 'no newline#{original_message}")
      end
    end

    # https://github.com/ruby/syntax_suggest/issues/258
    it "SyntaxError monkeypatch does not leak raw invalid bytes into the annotation" do
      Dir.mktmpdir do |dir|
        tmpdir = Pathname(dir)
        file = tmpdir.join("file.rb")

        # Source contains a byte (0xFF) that is invalid in its encoding. This
        # mirrors the invalid-encoding sources that broke Ruby's
        # spec/ruby/language/source_encoding_spec.rb on CI machines running
        # under LC_ALL=C.
        file.binwrite("def foo\n  x = \xFF\nend\n")

        core_ext_file = lib_dir.join("syntax_suggest").join("core_ext")
        require_relative core_ext_file

        error = SyntaxError.new("blerg")
        def error.set_tmp_path_for_testing=(path)
          @tmp_path_for_testing = path
        end
        error.set_tmp_path_for_testing = file
        def error.path
          @tmp_path_for_testing
        end

        detailed = error.detailed_message(highlight: false, syntax_suggest: true)

        # The raw invalid bytes must not leak into the annotation. When they do,
        # any regex match on the output raises `ArgumentError: invalid byte
        # sequence` (e.g. under LC_ALL=C where the captured output is US-ASCII).
        expect(detailed.valid_encoding?).to be(true)
      end
    end
  end
end
