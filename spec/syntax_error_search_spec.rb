RSpec.describe SyntaxErrorSearch do
  it "has a version number" do
    expect(SyntaxErrorSearch::VERSION).not_to be nil
  end
end


RSpec.describe SyntaxErrorSearch do
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

module SpaceCount
  def self.indent(string)
    string.split(/\w/).first&.length || 0
  end
end

class CodeLine
  attr_reader :line, :index, :indent

  VALID_STATUS = [:valid, :invalid, :unknown].freeze

  def initialize(line: , index:)
    @line = line
    @stripped_line = line.strip
    @index = index
    @indent = SpaceCount.indent(line)
    @is_end = line.strip == "end".freeze
    @status = nil # valid, invalid, unknown
    @visible = true
    @block_memeber = nil
  end

  def belongs_to_block?
    @block_member
  end

  def mark_block(code_block)
    @block_member = code_block
  end

  def marked_invalid?
    @status == :invalid
  end

  def mark_valid
    @status = :valid
  end

  def mark_invalid
    @status = :invalid
  end

  def mark_invisible
    @visible = false
  end

  def mark_visible
    @visible = true
  end

  def visible?
    @visible
  end

  def line_number
    index + 1
  end

  def not_empty?
    !empty?
  end

  def empty?
    @stripped_line.empty?
  end

  def to_s
    @line
  end

  def is_end?
    @is_end
  end
end

class CodeBlock
  attr_reader :lines

  def initialize(source: , lines: [])
    @lines = Array(lines)
    @source = source
  end


  def <=>(other)
    self.current_indent <=> other.current_indent
  end

  def visible_lines
    @lines
      .select(&:not_empty?)
      .select(&:visible?)
  end

  def max_indent
    visible_lines.map(&:indent).max
  end

  def block_with_neighbors_while
    array = []
    array << before_lines.take_while do |line|
      yield line
    end
    array << lines

    array << after_lines.take_while do |line|
      yield line
    end

    CodeBlock.new(
      source: @source,
      lines: array.flatten
    )
  end

  # We can guess a block boundry exists when there's
  # a change in indentation (spaces decrease) or an empty line
  #
  # Expand on until boundry condition is met:
  #
  #   - Indentation goes down (do not add this line, stop search)
  #   - empty line (add this line, stop search)
  #
  # Check valid/invalid

  # Two cases:
  #
  #   - Search same indent
  #   - Search smaller indent
  #
  # Take a line, find the nearest indent
  #
  # Pick a line, expand up until we've hit an empty
  def expand_until_next_boundry
    expand_to_indent(next_indent)
  end

  def expand_until_neighbors
    expand_to_indent(current_indent)
  end

  def expand_to_indent(indent)
    array = []
    before_lines(skip_empty: false).each do |line|
      if line.empty?
        array.prepend(line)
        break
      end

      if line.indent == indent
        array.prepend(line)
      else
        break
      end
    end

    array << @lines

    after_lines(skip_empty: false).each do |line|
      if line.empty?
        array << line
        break
      end

      if line.indent == indent
        array << line
      else
        break
      end
    end

    @lines = array.flatten
  end

  def next_indent
    [
      before_line&.indent || 0,
      after_line&.indent || 0
    ].max
  end

  def current_indent
    lines.detect(&:not_empty?)&.indent || 0
  end

  def before_line
    before_lines.first
  end

  def after_line
    after_lines.first
  end

  def before_lines(skip_empty: true)
    index = @lines.first.index
    lines = @source.code_lines.select {|line| line.index < index }
    lines.select!(&:not_empty?) if skip_empty
    lines.select!(&:visible?)
    lines.reverse!

    lines
  end

  def after_lines(skip_empty: true)
    index = @lines.last.index
    lines = @source.code_lines.select {|line| line.index > index }
    lines.select!(&:not_empty?) if skip_empty
    lines.select!(&:visible?)
    lines
  end

  # Returns a code block of the source that does not include
  # the current lines. This is useful for checking if a source
  # with the given lines removed parses successfully. If so
  #
  # Then it's proof that the current block is invalid
  def block_without
    @block_without ||= CodeBlock.new(
      source: @source,
      lines: @source.code_lines - @lines
    )
  end

  def document_valid_without?
    block_without.valid?
  end

  def valid?
    CodeSource.valid?(self.to_s)
  end

  def to_s
    CodeSource.code_lines_to_source(@lines)
  end
end

class CodeSource
  attr_reader :lines, :indent_array, :indent_hash, :code_lines

  def initialize(source)
    @frontier = []
    @lines = source.lines
    @indent_array = []
    @indent_hash = Hash.new {|h, k| h[k] = [] }

    @code_lines = []
    lines.each_with_index do |line, i|
      code_line = CodeLine.new(
        line: line,
        index: i,
      )

      @indent_array[i] = code_line.indent
      @indent_hash[code_line.indent] << code_line
      @code_lines << code_line
    end
  end

  def get_max_indent
    @indent_hash.select! {|k, v| !v.empty?}
    @indent_hash.keys.sort.last
  end

  def indent_hash
    @indent_hash
  end

  def self.code_lines_to_source(source)
    source = source.select(&:visible?)
    source = source.join
  end

  def self.valid?(source)
    source = code_lines_to_source(source) if source.is_a?(Array)
    source = source.to_s

    # Parser writes to stderr even if you catch the error
    #
    stderr = $stderr
    $stderr = StringIO.new

    Parser::CurrentRuby.parse(source)
    true
  rescue Parser::SyntaxError
    false
  ensure
    $stderr = stderr if stderr
  end

  def pop_max_indent_line(indent = get_max_indent)
    return nil if @indent_hash.empty?

    if (line = @indent_hash[indent].shift)
      return line
    else
      pop_max_indent_line
    end
  end

  # Returns a CodeBlock based on the maximum indentation
  # present in the source
  def max_indent_to_block
    if (line = pop_max_indent_line)
      block = CodeBlock.new(
        source: self,
        lines: line
      )
      block.expand_until_neighbors
      clean_hash(block)

      return block
    end
  end

  # Returns the highest indentation code block from the
  # frontier or if
  def next_frontier
    if @frontier.any?
      @frontier.sort!
      block = @frontier.pop

      if self.get_max_indent && block.current_indent <= self.get_max_indent
        @frontier.push(block)
        block = nil
      else

        block.expand_until_next_boundry
        clean_hash(block)
        return block
      end
    end

    max_indent_to_block if block.nil?
  end

  def clean_hash(block)
    block.lines.each do |line|
      @indent_hash[line.indent].delete(line)
    end
  end

  def invalid_code
    CodeBlock.new(
     lines: code_lines.select(&:marked_invalid?),
     source: self
    )
  end

  def frontier_holds_syntax_error?
    lines = code_lines
    @frontier.each do |block|
      lines -= block.lines
    end

    return true if lines.empty?

    CodeBlock.new(
      source: self,
      lines: lines
    ).valid?
  end

  def detect_invalid
    while block = next_frontier
      if block.valid?
        block.lines.each(&:mark_valid)
        block.lines.each(&:mark_invisible)
        next
      end

      if block.document_valid_without?
        block.lines.each(&:mark_invalid)
        return
      end

      @frontier << block

      if frontier_holds_syntax_error?
        @frontier.each do |block|
          block.lines.each(&:mark_invalid)
        end
        return
      end
    end
  end
end

RSpec.describe CodeLine do

  it "detect" do
    source = CodeSource.new(<<~EOM)
      def foo
        puts 'lol'
      end
    EOM
    source.detect_invalid
    expect(source.code_lines.map(&:marked_invalid?)).to eq([false, false, false])

    source = CodeSource.new(<<~EOM)
      def foo
        end
      end
    EOM
    source.detect_invalid
    expect(source.code_lines.map(&:marked_invalid?)).to eq([false, true, false])

    source = CodeSource.new(<<~EOM)
      def foo
        def blerg
      end
    EOM
    source.detect_invalid
    expect(source.code_lines.map(&:marked_invalid?)).to eq([false, true, false])
  end
  it "frontier" do
    source = CodeSource.new(<<~EOM)
      def foo
        puts 'lol'
      end
    EOM
    block = source.next_frontier
    expect(block.lines).to eq([source.code_lines[1]])

    source.code_lines[1].mark_invisible

    block = source.next_frontier
    expect(block.lines).to eq(
      [source.code_lines[0], source.code_lines[2]])
  end

  it "frontier levels" do

    source_string = <<~EOM
      describe "hi" do
        Foo.call
        end
      end

      it "blerg" do
        Bar.call
        end
      end
    EOM

    source = CodeSource.new(source_string)

    block = source.next_frontier
    expect(block.to_s).to eq(<<-EOM)
  Foo.call
  end
EOM

    block = source.next_frontier
    expect(block.to_s).to eq(<<-EOM)
  Bar.call
  end
EOM
  end


  it "max indent to block" do
    source = CodeSource.new(<<~EOM)
      def foo
        puts 'lol'
      end
    EOM
    block = source.max_indent_to_block

    expect(block.lines).to eq([source.code_lines[1]])

    block = source.max_indent_to_block
    expect(block.lines).to eq([source.code_lines[0]])

    source = CodeSource.new(<<~EOM)
      def foo
        puts 'lol'
      end

      def bar
        puts 'boo'
      end
    EOM
    block = source.max_indent_to_block
    expect(block.lines).to eq([source.code_lines[1]])

    block = source.max_indent_to_block
    expect(block.lines).to eq([source.code_lines[5]])
  end

  it "code block can detect if it's valid or not" do
    source = CodeSource.new(<<~EOM)
      def foo
        puts 'lol'
      end
    EOM

    block = CodeBlock.new(source: source, lines: source.code_lines[1])
    expect(block.valid?).to be_truthy
    expect(block.document_valid_without?).to be_truthy
    expect(block.block_without.lines).to eq([source.code_lines[0], source.code_lines[2]])
    expect(block.max_indent).to eq(2)
    expect(block.before_lines).to eq([source.code_lines[0]])
    expect(block.before_line).to eq(source.code_lines[0])
    expect(block.after_lines).to eq([source.code_lines[2]])
    expect(block.after_line).to eq(source.code_lines[2])
    expect(
      block.block_with_neighbors_while {|n| n.indent == block.max_indent - 2}.lines
    ).to eq(source.code_lines)

    expect(
      block.block_with_neighbors_while {|n| n.index == 1 }.lines
    ).to eq([source.code_lines[1]])

    source = CodeSource.new(<<~EOM)
      def foo
        bar; end
      end
    EOM

    block = CodeBlock.new(source: source, lines: source.code_lines[1])
    expect(block.valid?).to be_falsey
    expect(block.document_valid_without?).to be_truthy
    expect(block.block_without.lines).to eq([source.code_lines[0], source.code_lines[2]])
    expect(block.before_lines).to eq([source.code_lines[0]])
    expect(block.after_lines).to eq([source.code_lines[2]])
  end

  it "ignores marked valid lines" do
    code_lines = []
    code_lines << CodeLine.new(line: "def foo\n",            index: 0)
    code_lines << CodeLine.new(line: "  Array(value) |x|\n", index: 1)
    code_lines << CodeLine.new(line: "  end\n",              index: 2)
    code_lines << CodeLine.new(line: "end\n",                index: 3)

    expect(CodeSource.valid?(code_lines)).to be_falsey
    expect(CodeSource.code_lines_to_source(code_lines)).to eq(<<~EOM)
      def foo
        Array(value) |x|
        end
      end
    EOM

    code_lines[0].mark_invisible
    code_lines[3].mark_invisible

    expected = ["  Array(value) |x|\n", "  end\n"].join
    expect(CodeSource.code_lines_to_source(code_lines)).to eq(expected)
    expect(CodeSource.valid?(code_lines)).to be_falsey
  end

  it "ignores marked invalid lines" do
    code_lines = []
    code_lines << CodeLine.new(line: "def foo\n",            index: 0)
    code_lines << CodeLine.new(line: "  Array(value) |x|\n", index: 1)
    code_lines << CodeLine.new(line: "  end\n",              index: 2)
    code_lines << CodeLine.new(line: "end\n",                index: 3)

    expect(CodeSource.valid?(code_lines)).to be_falsey
    expect(CodeSource.code_lines_to_source(code_lines)).to eq(<<~EOM)
      def foo
        Array(value) |x|
        end
      end
    EOM

    code_lines[1].mark_invisible
    code_lines[2].mark_invisible

    expect(CodeSource.code_lines_to_source(code_lines)).to eq(<<~EOM)
      def foo
      end
    EOM

    expect(CodeSource.valid?(code_lines)).to be_truthy
  end


  it "empty code line" do
    source = CodeSource.new(<<~EOM)
      # Not empty

      # Not empty
    EOM

    expect(source.code_lines.map(&:empty?)).to eq([false, true, false])
    expect(source.code_lines.map {|l| CodeSource.valid?(l) }).to eq([true, true, true])
  end

  it "blerg" do
    source = CodeSource.new(<<~EOM)
      def foo
        puts 'lol'
      end
    EOM

    expect(source.indent_array).to eq([0, 2, 0])
    # expect(source.indent_hash).to eq({0 =>[0, 2], 2 =>[1]})
    expect(source.code_lines.join()).to eq(<<~EOM)
      def foo
        puts 'lol'
      end
    EOM
  end

  describe "detect cases" do
    it "finds one invalid code block with typo def" do
      source_string = <<~EOM
        defzfoo
          puts "lol"
        end
      EOM
      source = CodeSource.new(source_string)
      source.detect_invalid

      expect(source.invalid_code.to_s).to eq(<<~EOM)
      defzfoo
      end
      EOM
    end

    it "finds TWO invalid code block with missing do at the depest indent" do
      source = <<~EOM
        describe "hi" do
          Foo.call
          end
        end

        it "blerg" do
          Bar.call
          end
        end
      EOM

      source = CodeSource.new(source)
      source.detect_invalid


      expect(source.invalid_code.to_s).to eq(<<-EOM)
  Foo.call
  end
  Bar.call
  end
EOM
    end

    it "finds one invalid code block with missing do at the depest indent" do
      source = <<~EOM
        describe "hi" do
          Foo.call
          end
        end

        it "blerg" do
        end
      EOM

      source = CodeSource.new(source)
      source.detect_invalid

      expect(source.code_lines[1].marked_invalid?).to be_truthy
      expect(source.code_lines[2].marked_invalid?).to be_truthy

      expect(source.invalid_code.to_s).to eq("  Foo.call\n  end\n")
    end
  end

  describe "expansion" do

    it "expand until next boundry (indentation)" do
      source_string = <<~EOM
        describe "what" do
          Foo.call
        end

        describe "hi"
          Bar.call do
            Foo.call
          end
        end

        it "blerg" do
        end
      EOM

      source = CodeSource.new(source_string)
      block = CodeBlock.new(
        lines: source.code_lines[6],
        source: source
      )

      block.expand_until_next_boundry

      expect(block.to_s).to eq(<<-EOM)
  Bar.call do
    Foo.call
  end
EOM

      block.expand_until_next_boundry

      expect(block.to_s).to eq(<<-EOM)

describe "hi"
  Bar.call do
    Foo.call
  end
end

EOM
    end

    it "expand until next boundry (empty lines)" do
      source_string = <<~EOM
        describe "what" do
        end

        describe "hi"
        end

        it "blerg" do
        end
      EOM

      source = CodeSource.new(source_string)
      block = CodeBlock.new(
        lines: source.code_lines[0],
        source: source
      )
      block.expand_until_next_boundry

      expect(block.to_s.strip).to eq(<<~EOM.strip)
        describe "what" do
        end
      EOM

      source = CodeSource.new(source_string)
      block = CodeBlock.new(
        lines: source.code_lines[3],
        source: source
      )
      block.expand_until_next_boundry

      expect(block.to_s.strip).to eq(<<~EOM.strip)
        describe "hi"
        end
      EOM

      block.expand_until_next_boundry

      expect(block.to_s.strip).to eq(source_string.strip)
    end
  end
end
