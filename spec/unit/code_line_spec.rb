# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  class BucketRange
    attr_reader :len, :bucket_size, :overage

    def initialize(concurrency: , len: )
      @len = len
      @bucket_size = (len / concurrency.to_f).floor
      @overage = len - concurrency * bucket_size
      @range_for_bucket = concurrency.times.map do |i|
        start_index = i * bucket_size
        end_index = start_index + bucket_size.pred
        end_index += overage if i == concurrency.pred

        (start_index..end_index)
      end

      @index_to_bucket = concurrency.times.each_with_object({}) do |bucket_i, hash|
        range_for_bucket(bucket_i).each do |index|
          hash[index] = bucket_i
        end
      end
      freeze
    end

    def bucket_for_index(index)
      @index_to_bucket[index]
    end

    def range_for_bucket(bucket_i)
      @range_for_bucket[bucket_i]
    end
  end


  # Make a communication channel (pipe)
  # create N ractors, and register them with the pipe in order
  # send an array of ractors to N ractors
  #
  # When ractor is done sending it sends a :done signals to all other ractors
  pipe = Ractor.new do
    loop do
      puts Ractor.receive
    end
  end

  r = Ractor.new do
  end

  pipe.send(r)

  class BucketSort
    attr_reader :bucket_range

    def initialize(concurrency: , elements: [])
      @elements = elements
      @concurrency = concurrency
      @bucket_range = BucketRange.new(concurrency: concurrency, len: lex.length)
    end

    def call
      @concurrency.times.each do |bucket_i|
        # Send self to pipe.
        # Receive array of ractors
        array = InsertionSort.new
        bucket_range.range_for_bucket(bucket_i).each do |index|
          # target_bucket = bucket_range.bucket_for_index(index)
          value = @elements[index]
          target_bucket = bucket_range.bucket_for_index(value.pos[0])
          if target_bucket != bucket_id
            # send to target bucket
          else
            array << value
          end
        end
        # Send `:done` call to all ractors

        # Receive values and sort until N `:done` calls received
        array.to_a.freeze # return sorted array
      end
    end
  end

  RSpec.describe "foo" do
    it "divides up evenly" do
      bucket = BucketRange.new(concurrency: 2, len: 10)

      expect(bucket.bucket_for_index(0)).to eq(0)
      expect(bucket.bucket_for_index(1)).to eq(0)
      expect(bucket.bucket_for_index(2)).to eq(0)
      expect(bucket.bucket_for_index(3)).to eq(0)
      expect(bucket.bucket_for_index(4)).to eq(0)
      expect(bucket.bucket_for_index(5)).to eq(1)
      expect(bucket.bucket_for_index(9)).to eq(1)

      expect(bucket.range_for_bucket(0)).to eq(0..4)
      expect(bucket.range_for_bucket(1)).to eq(5..9)
    end

    it "divides up unevenly" do
      bucket = BucketRange.new(concurrency: 3, len: 10)

      expect(bucket.bucket_for_index(0)).to eq(0)
      expect(bucket.bucket_for_index(1)).to eq(0)
      expect(bucket.bucket_for_index(2)).to eq(0)
      expect(bucket.bucket_for_index(3)).to eq(1)
      expect(bucket.bucket_for_index(4)).to eq(1)
      expect(bucket.bucket_for_index(5)).to eq(1)
      expect(bucket.bucket_for_index(6)).to eq(2)
      expect(bucket.bucket_for_index(7)).to eq(2)
      expect(bucket.bucket_for_index(8)).to eq(2)
      expect(bucket.bucket_for_index(9)).to eq(2)

      expect(bucket.range_for_bucket(0)).to eq(0..2)
      expect(bucket.range_for_bucket(1)).to eq(3..5)
      expect(bucket.range_for_bucket(2)).to eq(6..9)
    end
  end

  RSpec.describe CodeLine do

    it "supports endless method definitions" do
      skip("Unsupported ruby version") unless Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3")

      line = CodeLine.from_source(<<~'EOM').first
        def square(x) = x * x
      EOM

      expect(line.is_kw?).to be_falsey
      expect(line.is_end?).to be_falsey
    end

    it "retains original line value, after being marked invisible" do
      line = CodeLine.from_source(<<~'EOM').first
        puts "lol"
      EOM
      expect(line.line).to match('puts "lol"')
      line.mark_invisible
      expect(line.line).to eq("")
      expect(line.original).to match('puts "lol"')
    end

    it "knows which lines can be joined" do
      code_lines = CodeLine.from_source(<<~'EOM')
        user = User.
          where(name: 'schneems').
          first
        puts user.name
      EOM

      # Indicates line 1 can join 2, 2 can join 3, but 3 won't join it's next line
      expect(code_lines.map(&:ignore_newline_not_beg?)).to eq([true, true, false, false])
    end
    it "trailing if" do
      code_lines = CodeLine.from_source(<<~'EOM')
        puts "lol" if foo
        if foo
        end
      EOM

      expect(code_lines.map(&:is_kw?)).to eq([false, true, false])
    end

    it "trailing unless" do
      code_lines = CodeLine.from_source(<<~'EOM')
        puts "lol" unless foo
        unless foo
        end
      EOM

      expect(code_lines.map(&:is_kw?)).to eq([false, true, false])
    end

    it "trailing slash" do
      code_lines = CodeLine.from_source(<<~'EOM')
        it "trailing s" \
           "lash" do
      EOM

      expect(code_lines.map(&:trailing_slash?)).to eq([true, false])

      code_lines = CodeLine.from_source(<<~'EOM')
        amazing_print: ->(obj)  { obj.ai + "\n" },
      EOM
      expect(code_lines.map(&:trailing_slash?)).to eq([false])
    end

    it "knows it's got an end" do
      line = CodeLine.from_source("   end").first

      expect(line.is_end?).to be_truthy
      expect(line.is_kw?).to be_falsey
    end

    it "knows it's got a keyword" do
      line = CodeLine.from_source("  if").first

      expect(line.is_end?).to be_falsey
      expect(line.is_kw?).to be_truthy
    end

    it "ignores marked lines" do
      code_lines = CodeLine.from_source(<<~EOM)
        def foo
          Array(value) |x|
          end
        end
      EOM

      expect(DeadEnd.valid?(code_lines)).to be_falsey
      expect(code_lines.join).to eq(<<~EOM)
        def foo
          Array(value) |x|
          end
        end
      EOM

      expect(code_lines[0].visible?).to be_truthy
      expect(code_lines[3].visible?).to be_truthy

      code_lines[0].mark_invisible
      code_lines[3].mark_invisible

      expect(code_lines[0].visible?).to be_falsey
      expect(code_lines[3].visible?).to be_falsey

      expect(code_lines.join).to eq(<<~EOM.indent(2))
        Array(value) |x|
        end
      EOM
      expect(DeadEnd.valid?(code_lines)).to be_falsey
    end

    it "knows empty lines" do
      code_lines = CodeLine.from_source(<<~EOM)
        # Not empty

        # Not empty
      EOM

      expect(code_lines.map(&:empty?)).to eq([false, true, false])
      expect(code_lines.map(&:not_empty?)).to eq([true, false, true])
      expect(code_lines.map { |l| DeadEnd.valid?(l) }).to eq([true, true, true])
    end

    it "counts indentations" do
      code_lines = CodeLine.from_source(<<~EOM)
        def foo
          Array(value) |x|
            puts 'lol'
          end
        end
      EOM

      expect(code_lines.map(&:indent)).to eq([0, 2, 4, 2, 0])
    end

    it "doesn't count empty lines as having an indentation" do
      code_lines = CodeLine.from_source(<<~EOM)


      EOM

      expect(code_lines.map(&:indent)).to eq([0, 0])
    end
  end
end
