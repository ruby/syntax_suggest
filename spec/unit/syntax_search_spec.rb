# frozen_string_literal: true

require_relative "../spec_helper.rb"

module SyntaxErrorSearch
  RSpec.describe SyntaxErrorSearch do
    it "detects require error and adds a message with auto mode" do
      Dir.mktmpdir do |dir|
        @tmpdir = Pathname(dir)
        @script = @tmpdir.join("script.rb")
        @script.write <<~EOM
          describe "things" do
            it "blerg" do
            end

            it "flerg"
            end

            it "zlerg" do
            end
          end
        EOM

        require_rb = @tmpdir.join("require.rb")
        require_rb.write <<~EOM
          require_relative "./script.rb"
        EOM

        out = `ruby -I#{lib_dir} -rsyntax_search/auto #{require_rb} 2>&1`

        expect(out).to include("Unmatched `end` detected")
        expect(out).to include("Run `$ dead_end")
        expect($?.success?).to be_falsey

        expect(out).to include("syntax_search gem is deprecated")
      end
    end
  end
end
