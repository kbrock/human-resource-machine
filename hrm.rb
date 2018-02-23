#!/usr/bin/env ruby

require 'json'

module HRM
  class Op
    attr_accessor :name, :arg, :deref
    def initialize(name = nil, arg = nil, deref = nil)
      @name  = name
      @arg   = arg
      @deref = deref
    end

    def inbox(state, _)
      if val = state.read
        state.hands = val =~ /^[-+]?[0-9]+$/ ? val.to_i : val
      else # nothing for input - end of program
        state.value = nil
        state.exit!(:eof)
      end
    end

    def outbox(state, _)   ; state.write state.hands ; state.value = nil ; end
    def copyfrom(state, address) ; state.hands = state[address] ; end
    def copyto(state, address)   ; state[address] = state.hands ; end
    def add(state, address)      ; state.hands += state[address] ; end
    def sub(state, address)      ; state.hands -= state[address] ; end
    def bumpup(state, address)   ; state.hands = state[address] += 1 ; end
    def bumpdn(state, address)   ; state.hands = state[address] -= 1 ; end
    def jump(state, line)  ; state.pc = line ; end
    def jumpz(state, line) ; state.pc = line if state.zero? ; end
    def jumpn(state, line) ; state.pc = line if state.neg?  ; end

    # for when no more instructions (nil defaults to done) - think no longer necessary
    def done(state, address) ; state.exit!(:end) ; end

    def call(state)
      state.inc if name
      public_send(name || "done", state, deref ? state[arg] : arg)
    end

    def inspect(pc, counter)
      deref_str = deref ? "[#{arg}]" : arg
      "#{counter + 1}> #{pc}: #{name || "done"} #{deref_str}"
    end

    NIL = Op.new(nil, nil, nil)
  end

  module Instruction
    def op(im, pc)
      instruction, arg, deref = im[pc]
      Op.new(instruction, arg, deref)
    end

    def old_op(name)
      ->(arg, deref, state) { Op.new(name, arg, deref).call(state) }
    end

    def inspect_op(im, pc, counter)
      op(im, pc).inspect(pc, counter)
    end
  end

  class Level
    attr_accessor :level
    def initialize(level = 1)
      @levels = JSON.parse(File.read(File.expand_path("original_levels.json", __dir__)))
      @level = level
    end

    def cur_level ; @levels[@level - 1] ; end

    #"number": 1,
    def number   ; cur_level["number"] ; end
    # "name": "Mail Room",
    def name     ; cur_level["name"] ; end
    # "instructions": "Drag commands into this area to build a program.\n\nYour program should tell your worker to grab each thing from the INBOX, and drop it into the OUTBOX.",
    # "commands": [ "INBOX", "OUTBOX" ],
    # "floor": {"columns": 3, "rows": 1, "tiles": {"9" : 0}}
    def floor_size ; cur_level["floor"] ? cur_level["floor"]["columns"] * cur_level["floor"]["rows"] : 0 ; end
    def floor_tiles
      arr = Array.new(floor_size)
      tiles = cur_level["floor"] && cur_level["floor"]["tiles"]
      case tiles
      when Hash
        tiles.each { |n, v| arr[n.to_i] = v }
      when Array
        tiles.each_with_index { |v, i| arr[i] = v }
      end
      arr
    end
    # "examples": [
    #   { "inbox": [ 1, 9, 4 ], "outbox": [ 1, 9, 4 ] },
    #   { "inbox": [ 4, 3, 3 ], "outbox": [ 4, 3, 3 ] }
    # ],
    def example_inbox ; cur_level["examples"][0]["inbox"].freeze ; end
    def example_outbox ; cur_level["examples"][0]["outbox"].freeze ; end
    #"challenge": { "size": 6, "speed": 6}
    def challenge_size ; cur_level["challenge"]["size"] ; end
    def challenge_speed ; cur_level["challenge"]["speed"] ; end
  end

  class State
    attr_accessor :pc, :value, :memory, :counter
    attr_accessor :stdin, :stdout
    def initialize(memory, stdin)
      @counter = 0
      @pc = 1
      @exit = false

      @value = nil
      @memory = memory

      @stdin = stdin
      @stdout = []
    end

    def inspect
      [
        "inbox:  #{stdin[0..5].inspect}",
        "hands: [#{@value || " "}]#{@memory.empty? ? "" : " memory: #{@memory.inspect}"}",
        "outbox: #{stdout[0..5].inspect}"
      ]
    end

    def inc ; @pc += 1 ; @counter += 1 ; self ; end
    def exit!(status = true) ; @exit = status ; self ; end
    def status ; @exit ; end
    def exit?  ; @exit ; end
    def hands
      @value or raise "empty hands"
    end

    def hands=(val)
      @value = val or raise "hands set to no value"
    end

    def [](index)
      raise "invalid address on floor" unless index
      @memory[index] or raise "empty floor address #{index}"
    end

    def []=(index, value)
      raise "invalid address on floor" unless index
      @memory[index] = value or raise "floor set to no value"
    end

    alias floor  :[]
    alias floor= :[]=

    def zero? ; hands == "0"       || hands == 0 ; end
    def neg?  ; hands.to_s =~ /^-/ || hands < 1  ; end

    def read ; @stdin.shift ; end
    def write(val) ; @stdout << val ; end
  end

  class Compiler
    def self.compile(strs)
      lines = strs.split(/\R/)

      line_no = 1 ; mode = :read_code

      # label to offset lookup
      refs = {}
      code = lines.map do |line|
        case mode

        when :read_code
          # -- this is a comment --
          if line =~ /^ *([-#]|$)/ # single line comment or blank
            nil
          # define comment
          # .....
          # .....;
          elsif line =~ /define *comment/i
            mode = :read_comment
            nil
          # NOTE: my custom field
          # reg 0: aa
          elsif line =~ /^ *reg *(\d*): *(.*)/i
            refs[$2] = $1.to_i
            nil
          # a:
          elsif line =~ /^ *([a-z_0-9]*):/
            refs[$1] = line_no
            nil
          else # translate code
            instruction, arg = line.split
            instruction = instruction.downcase.to_sym
            unless instruction == :comment
              line_no += 1
              # todo - dereference
              if arg =~ /^\[(\d*)\]$/
                arg, deref = [$1.to_i, true]
              elsif arg =~ /^\d*$/
                arg = arg.to_i
              else # dereference what we can
                # overly simplistic. pretty much the same as the second pass below
                # optimal 1 1/2 phase parser would be to remember where to run next block
                arg = refs[arg] if refs.key?(arg)
              end
              [instruction, arg, deref].compact
            end
          end
        # middle of a define comment block
        # looking for the trailing ;
        when :read_comment
          mode = :read_code if line =~ /;/
          nil
        end
      end.compact
      [nil] + code.each_with_index.map do |instruction, i|
        if instruction[1].kind_of?(String) && instruction[0] != :define
          unless (back_ref = refs[instruction[1]])
            raise "unknown back_ref on line #{i}: #{instruction.inspect} - know: #{refs.keys}"
          end
          instruction[1] = back_ref
        end
        instruction
      end
    end

    def self.print_source(im)
      instr_size = Math::log10(im.size).floor + 1
      im.each_with_index do |(instr, addr, deref), i|
        puts "%*s: %-8s %s" % [instr_size, i, instr, deref ? "[#{addr}]" : addr]
      end
    end
  end

  class Machine
    include Instruction

    def self.run(level_num, filepath, options = {})
      level = Level.new(level_num.to_i)
      im = Compiler.compile(File.read(filepath))
      state = State.new(level.floor_tiles, level.example_inbox.dup)

      # display compiled code
      if options[:print_source]
        Compiler.print_source(im)
      end

      # currently, only producing {"speed" => }
      state = new.run(state, im, options[:debug])

      result = {
        "level"   => level.number,
        "speed"   => state.counter,
        "size"    => im.size,
        "success" => (level.example_outbox == state.stdout),
        "status"  => state.status,
      }

      puts "#{result.inspect}"
      if !result["success"]
        puts "level:  #{level.number}"
        puts "name:   #{level.name}"
        puts
        puts "inbox:  #{level.example_inbox.inspect}"
        puts
        puts "expected: #{level.example_outbox}"
        puts "outbox:   #{state.stdout}"
      end
    end

    def step(state, im)
      instruction, arg, deref = im[state.pc]
      old_op(instruction).call(arg, deref, state)
    end

    COUNTER_MAX = 2000
    def run(state, im, debug = false)
      while !state.exit?
        puts inspect_op(im, state.pc, state.counter) if debug
        step(state, im)
        state.exit!(:infinite) if state.counter > COUNTER_MAX
        puts state.inspect, "" if debug
      end

      state
    end
  end
end

require "optparse"

options = {:debug => false, :print_source => false}

ARGV.options do |opts|
  opts.banner = "Usage:  #{File.basename($PROGRAM_NAME)} [--debug] [level] asm_file"

  opts.on( "-h", "--help",   "Show this message." ) { puts opts ; exit }
  opts.on(       "--debug",  "Debug instructions" ) { options[:debug] = true}
  opts.on(       "--source", "print source" ) { options[:print_source] = true}

  begin
    opts.parse!
  rescue
    puts opts
    exit
  end
end

def guess_level(filename)
  ARGV[0].gsub(/^[^0-9]*([0-9]*)[^0-9].*$/) { $1 }.to_i
end

level, filename = ARGV[1] ? ARGV[0..1] : [guess_level(ARGV[0]), ARGV[0]]
HRM::Machine.run(level, filename, options)
