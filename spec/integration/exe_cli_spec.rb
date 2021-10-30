# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe "exe" do
    def exe_path
      root_dir.join("exe").join("dead_end")
    end

    def exe(cmd)
      out = run!("#{exe_path} #{cmd}", raise_on_nonzero_exit: false)
      puts out if ENV["DEBUG"]
      out
    end

    it "parses valid code" do
      ruby_file = exe_path
      out = exe(ruby_file)
      expect(out.strip).to include("Syntax OK")
      expect($?.success?).to be_truthy
    end

    it "parses invalid code" do
      ruby_file = fixtures_dir.join("this_project_extra_def.rb.txt")
      out = exe(ruby_file)

      expect(out.strip).to include("❯ 36      def filename")
      expect($?.success?).to be_falsey
    end

    it "handles heredocs" do
      lines = fixtures_dir.join("rexe.rb.txt").read.lines
      Tempfile.create do |file|
        lines.delete_at(85 - 1)

        Pathname(file.path).write(lines.join)

        out = exe(file.path)

        expect(out).to include(<<~EOM)
             16  class Rexe
          ❯  77    class Lookups
          ❯  78      def input_modes
          ❯ 148    end
            551  end
        EOM
      end
    end

    # When ruby sub shells it is not a interactive shell and dead_end will
    # default to no coloring. Colors/bold can be forced with `--terminal`
    # flag
    it "passing --terminal will force color codes" do
      ruby_file = fixtures_dir.join("this_project_extra_def.rb.txt")
      out = exe("#{ruby_file} --terminal")

      expect(out.strip).to include("\e[0m❯ 36  \e[1;3m    def filename")
    end

    it "records search" do
      Dir.mktmpdir do |dir|
        dir = Pathname(dir)
        tmp_dir = dir.join("tmp").tap(&:mkpath)
        ruby_file = dir.join("file.rb")
        ruby_file.write("def foo\n  end\nend")

        expect(tmp_dir).to be_empty

        out = exe("#{ruby_file} --record #{tmp_dir}")

        expect(tmp_dir).to_not be_empty
      end
    end

    it "prints the version" do
      out = exe("-v")
      expect(out.strip).to include(DeadEnd::VERSION)
    end
  end
end
