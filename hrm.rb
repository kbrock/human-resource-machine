#!/usr/bin/env ruby

require 'json'

module HRM
  module Instruction
    def inbox(state, _)
      if val = state.read
        state.value = val =~ /^[-+]?[0-9]+$/ ? val.to_i : val 
      else
        state.value = nil
        state.pc = 100
      end
    end

    def outbox(state, _)   ; state.write state.value ; state.value = nil ; end
    def copyfrom(state, address) ; state.value = state[address] ; end
    def copyto(state, address)   ; state[address] = state.value ; end
    def add(state, address)      ; state.value += state[address] ; end
    def sub(state, address)      ; state.value -= state[address] ; end
    def bumpup(state, address)   ; state.value = state[address] += 1 ; end
    def bumpdn(state, address) ; state.value = state[address] -= 1 ; end
    def jump(state, line)     ; state.pc = line ; end
    def jumpz(state, line) ; state.pc = line if state.zero? ; end
    def jumpn(state, line) ; state.pc = line  if state.neg? ; end

    # for when no more instructions (nil defaults to done) - think no longer necessary
    def done(state, address) ; puts "done" ; state.pc = 100 ; end
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
    def example_inbox ; cur_level["examples"][0]["inbox"] ; end
    def example_outbox ; cur_level["examples"][0]["outbox"] ; end
    #"challenge": { "size": 6, "speed": 6}
    def challenge_size ; cur_level["challenge"]["size"] ; end
    def challenge_speed ; cur_level["challenge"]["speed"] ; end
  end

  class State
    attr_accessor :pc, :value, :memory
    attr_accessor :stdin, :stdout
    def initialize(memory, stdin)
      @value = nil
      @pc = 1
      @memory = memory

      @stdin = stdin
      @stdout = []
    end

    def inc ; @pc += 1 ; end
    def [](index) ; @memory[index] ; end
    def []=(index, value) ; @memory[index] = value ; end
    def zero? ; value == 0 || value == "0" ; end
    def neg?  ; value.to_s =~ /^-/ || value < 1 ; end

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
        if instruction[1].kind_of?(String)
          unless (back_ref = refs[instruction[1]])
            raise "unknown back_ref on line #{i}: #{instruction.inspect} - know: #{refs.keys}"
          end
          instruction[1] = back_ref
        end
        instruction
      end
    end
  end

  class Machine
    include Instruction

    def self.run(level_num, filepath, debug = false)
      level = Level.new(level_num.to_i)

      state = State.new(level.floor_tiles, level.example_inbox.dup)
      im = Compiler.compile(File.read(filepath))

      # display compiled code
      if debug
        puts im.each_with_index.map { |(instr, addr, deref), i| "%2s: %-8s %s" % [i, instr, deref ? "[#{addr}]" : addr] }
      end

      machine = new(state, im)
      result = machine.run(debug)

      result = {
        "level"   => level.number,
        "speed"   => result["speed"],
        "size"    => im.size,
        "outbox"  => state.stdout,
        "success" => (level.example_outbox == state.stdout),
      }

      puts "#{result.inspect}"
      if !result["success"]
        puts "level:  #{level.number}"
        puts "inbox:  #{level.example_inbox.inspect}"
        puts "outbox: #{level.example_outbox.inspect}"
        puts
        puts "did not match output"
        puts "expected: #{level.example_outbox}"
        puts "outbox:   #{machine.state.stdout}"
      end
    end

    attr_accessor :state, :im
    def initialize(state, im)
      @state = state
      @im = im
    end

    def run(debug = false)
      counter = 0
      while state.pc >= 0 && state.pc < im.size
        counter += 1
        instruction, arg, deref = im[state.pc]

        puts "#{counter}> #{state.pc}:#{instruction || "done"} #{deref ? "[#{arg}]" : arg}" if debug

        state.inc
        arg = state[arg.to_i] if deref
        public_send(instruction || "done", state, arg)
        if debug
          puts "inbox:  #{state.stdin[0..5].inspect}"
          print "hands: [#{state.value || " "}]"
          puts @state.memory.empty? ? "" : " memory: #{state.memory.inspect}"
          puts "outbox: #{state.stdout[0..5].inspect}"
          puts
        end
      end
      {"speed" => counter}
    end
  end
end

if ARGV[1]
  HRM::Machine.run(ARGV[0], ARGV[1])
else
  guess_level = ARGV[0].gsub(/^[^0-9]*([0-9]*)[^0-9].*$/) { $1 }.to_i
  HRM::Machine.run(guess_level, ARGV[0], true)
end
