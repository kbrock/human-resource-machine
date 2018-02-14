#!/usr/bin/env ruby

require 'json'

#levels = JSON.parse(File.read('original_levels.json'))

module HRM
  module Instruction
    def inbox(state, _)
      if val = state.io.read
        state.value = val =~ /^[-+]?[0-9]+$/ ? val.to_i : val 
      else
        state.value = nil
        state.pc = 100
      end
    end

    def outbox(state, _)   ; state.io.write state.value ; state.value = nil ; end
    def copyfrom(state, address) ; state.value = state[address] ; end
    def copyto(state, address)   ; state[address] = state.value ; end
    def add(state, address)      ; state.value += state[address] ; end
    def sub(state, address)      ; state.value -= state[address] ; end
    def bumpup(state, address)   ; state.value = state[address] += 1 ; end
    def bumpdown(state, address) ; state.value = state[address] -= 1 ; end
    def jump(state, line)     ; state.pc = line ; end
    def jump_if_zero(state, line) ; state.pc = line if state.zero? ; end
    def jump_if_neg(state, line) ; state.pc = line  if state.neg? ; end
    alias bumpdn bumpdown
    alias jumpz jump_if_zero
    alias jumpn jump_if_neg

    # for when no more instructions (nil defaults to done) - think no longer necessary
    def done(state, address) ; puts "done" ; state.pc = 100 ; end
  end

  class IO
    def initialize(stdin = nil)
      @stdin = stdin || STDIN.read.chomp.split
      @stdout = []
      @cntr = 0
    end
    def read
      @stdin ? @stdin[@cntr += 1] : STDIN.gets&.chomp
    end

    def write(val)
      @stdout << val
      puts val
    end
  end

  class State
    MAX_MEMORY_SIZE = 25

    attr_accessor :pc, :value, :memory
    attr_accessor :io
    def initialize(io, memory = nil)
      @value = nil
      @pc = 1
      @memory = memory || Array.new(MAX_MEMORY_SIZE)
      @io = io
    end

    def inc ; @pc += 1 ; end
    def [](index) ; @memory[index] ; end
    def []=(index, value) ; @memory[index] = value ; end
    def zero? ; value == 0 || value == "0" ; end
    def neg?  ; value.to_s =~ /^-/ || value < 1 ; end
  end

  class Compiler
    def self.compile(strs)
      lines = strs.split(/\R/)

      line_no = 1 ; state = :read_code

      # label to offset lookup
      refs = {}
      code = lines.map do |line|
        case state

        when :read_code
          if line =~ /^([-#]|$)/ # single line comment or blank
            nil
          elsif line =~ /define *comment/i
            state = :read_comment
            nil
          elsif line =~ /^ *([a-z]*):/
            refs[$1] = line_no
            nil
          else # translate code
            instruction, arg = line.split
            instruction = instruction.downcase
            if instruction == 'comment'
              nil # skip
            else
              line_no += 1
              # todo - dereference
              arg = arg.to_i if arg =~ /\d/
              [instruction.downcase.to_sym, arg]
            end
          end
        when :read_comment
          if line =~ /;$/
          end
          nil
        end
      end.compact
      [nil] + code.each_with_index.map do |instruction, i|
        if instruction[0] =~ /jump/
          unless (back_ref = refs[instruction[1]])
            raise "unknown back_ref on line #{i}: #{instruction.inspect}"
          end
          instruction[1] = back_ref
        end
        instruction
      end
    end
  end

  class Machine
    include Instruction

    def self.run(filepath)
      im = Compiler.compile(File.read(filepath))
      new(im).run
    end

    attr_accessor :state, :im
    def initialize(im)
      @io = IO.new()
      @state = State.new(@io)
      @im = im
    end

    # note nil => 0 (not perfect but...)
    def deref(arg, state)
      arg && arg =~ /\[\s*(\d+)\s*\]/ ? state[$1.to_i] : arg.to_i
    end

    def run
      while state.pc >= 0 && state.pc < im.size
        instruction, arg = im[state.pc]
        state.inc

        public_send(instruction || "done", state, deref(arg, state))
      end
    end
  end
end

HRM::Machine.run(ARGV[0])
