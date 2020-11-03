require "bundler/setup"
require "syntax_error_search"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def code_line_array(string)
  code_lines = []
  string.lines.each_with_index do |line, index|
    code_lines << SyntaxErrorSearch::CodeLine.new(line: line, index: index)
  end
  code_lines
end

# Allows us to write cleaner tests since <<~EOM block quotes
# strip off all leading indentation and we need it to be preserved
# sometimes.
class String
  def indent(number)
    self.lines.map do |line|
      if line.chomp.empty?

        line
      else
        " " * number + line
      end
    end.join
  end
end


