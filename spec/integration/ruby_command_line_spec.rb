# frozen_string_literal: true

require_relative "../spec_helper.rb"

module DeadEnd
  RSpec.describe "Requires with ruby cli" do
    it "namespaces all monkeypatched methods" do
      Dir.mktmpdir do |dir|
        @tmpdir = Pathname(dir)
        @script = @tmpdir.join("script.rb")
        @script.write <<~'EOM'
          puts Kernel.private_methods
        EOM

        dead_end_methods_array = `ruby -I#{lib_dir} -rdead_end/auto #{@script} 2>&1`.strip.lines.map(&:strip)
        kernel_methods_array = `ruby #{@script} 2>&1`.strip.lines.map(&:strip)
        methods = (dead_end_methods_array - kernel_methods_array).sort
        expect(methods).to eq(["dead_end_original_load", "dead_end_original_require", "dead_end_original_require_relative", "timeout"])


        @script.write <<~'EOM'
          puts Kernel.private_methods
        EOM

        dead_end_methods_array = `ruby -I#{lib_dir} -rdead_end/auto #{@script} 2>&1`.strip.lines.map(&:strip)
        kernel_methods_array = `ruby #{@script} 2>&1`.strip.lines.map(&:strip)
        methods = (dead_end_methods_array - kernel_methods_array).sort
        expect(methods).to eq(["dead_end_original_load", "dead_end_original_require", "dead_end_original_require_relative", "timeout"])
      end
    end

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

        out = `ruby -I#{lib_dir} -rdead_end/auto #{require_rb} 2>&1`

        expect(out).to include("Unmatched `end` detected")
        expect(out).to include("Run `$ dead_end")
        expect($?.success?).to be_falsey

        out = `ruby -I#{lib_dir} -rdead_end #{require_rb} 2>&1`

        expect(out).to include("Unmatched `end` detected")
        expect(out).to include("Run `$ dead_end")
        expect($?.success?).to be_falsey
      end
    end

    it "detects require error and adds a message with fyi mode" do
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

        out = `ruby -I#{lib_dir} -rdead_end/fyi #{require_rb} 2>&1`

        expect(out).to_not include("This code has an unmatched")
        expect(out).to include("Run `$ dead_end")
        expect($?.success?).to be_falsey
      end
    end
  end
end
