# frozen_string_literal: true

module SyntaxErrorSearch
  RSpec.describe SyntaxErrorSearch do
    it "has a version number" do
      expect(SyntaxErrorSearch::VERSION).not_to be nil
    end

    def run_ruby(script)
      `ruby -I#{lib_dir} -rsyntax_error_search/auto #{script} 2>&1`
    end

    it "detects require error and adds a message" do
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

        out = run_ruby(require_rb)
        # puts out

        expect(out).to include("Run `$ syntax_search")
      end
    end

    it "detects require error and adds a message when executed via bundler auto" do
      Dir.mktmpdir do |dir|
        dir = Pathname(dir)
        gemfile = dir.join("Gemfile")
        gemfile.write(<<~EOM)
          gem "syntax_search", path: "#{root_dir}", require: "syntax_error_search/auto"
        EOM
        run!("BUNDLE_GEMFILE=#{gemfile} bundle install --local")
        script = dir.join("script.rb")
        script.write <<~EOM
          describe "things" do
            it "blerg" do
            end

            it "flerg"
            end

            it "zlerg" do
            end
          end
        EOM

        Bundler.with_original_env do
          require_rb = dir.join("require.rb")
          require_rb.write <<~EOM
            Bundler.require

            require_relative "./script.rb"
          EOM

          out = `BUNDLE_GEMFILE=#{gemfile} bundle exec ruby #{require_rb} 2>&1`

          expect($?.success?).to be_falsey
          expect(out).to include("This code has an unmatched")
          expect(out).to include("Run `$ syntax_search")
        end
      end
    end


    it "detects require error and adds a message when executed via bundler auto" do
      Dir.mktmpdir do |dir|
        dir = Pathname(dir)
        gemfile = dir.join("Gemfile")
        gemfile.write(<<~EOM)
          gem "syntax_search", path: "#{root_dir}", require: "syntax_error_search/fyi"
        EOM
        run!("BUNDLE_GEMFILE=#{gemfile} bundle install --local")
        script = dir.join("script.rb")
        script.write <<~EOM
          describe "things" do
            it "blerg" do
            end

            it "flerg"
            end

            it "zlerg" do
            end
          end
        EOM

        Bundler.with_original_env do
          require_rb = dir.join("require.rb")
          require_rb.write <<~EOM
            Bundler.require

            require_relative "./script.rb"
          EOM

          out = `BUNDLE_GEMFILE=#{gemfile} bundle exec ruby #{require_rb} 2>&1`

          expect($?.success?).to be_falsey
          expect(out).to_not include("This code has an unmatched")
          expect(out).to include("Run `$ syntax_search")
        end
      end
    end
  end
end
