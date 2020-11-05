module SyntaxErrorSearch
  RSpec.describe SyntaxErrorSearch do
    it "has a version number" do
      expect(SyntaxErrorSearch::VERSION).not_to be nil
    end

    def ruby(script)
      `ruby -I#{lib_dir} -rdid_you_do #{script} 2>&1`
    end

    describe "foo" do
      around(:each) do |example|
        Dir.mktmpdir do |dir|
          @tmpdir = Pathname(dir)
          @script = @tmpdir.join("script.rb")
          example.run
        end
      end

      it "blerg" do
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

        # out = ruby(require_rb)
        # puts out
      end
    end
  end
end
