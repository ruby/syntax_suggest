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

    it "prints the version" do
      out = exe("-v")
      expect(out.strip).to include(DeadEnd::VERSION)
    end
  end
end
