#!/usr/bin/env ruby

require 'json'

#levels = JSON.parse(File.read('original_levels.json'))

module HRM
  module Instruction
    def inbox(state, address)
      if val = STDIN.gets
        val = val.chomp
        state.value = val =~ /^[-+]?[0-9]+$/ ? val.to_i : val 
      else
        state.value = nil
        state.pc = -100
      end
    end

    def outbox(state, address)   ; puts state.value ; state.value = nil ; end
    def copyfrom(state, address) ; state.value = state[address] ; end
    def copyto(state, address)   ; state[address] = state.value ; end
    def add(state, address)      ; state.value += state[address] ; end
    def sub(state, address)      ; state.value -= state[address] ; end
    def bumpup(state, address)   ; state.value = state[address] += 1 ; end
    def bumpdown(state, address) ; state.value = state[address] -= 1 ; end
    def jump(state, address)     ; state.pc = address ; end
    def jump_if_zero(state, address) ; state.pc = address if state.zero? ; end
    def jump_if_neg(state, address) ; state.pc = address  if state.neg? ; end

    # for when no more instructions (nil defaults to done)
    def done(state, address) ; state.pc = -100 ; end
  end
end

####

module HRM
  class State
    MAX_MEMORY_SIZE = 25

    attr_accessor :pc, :value, :memory
    def initialize()
      @value = nil
      @pc = 1
      @memory = Array.new(MAX_MEMORY_SIZE)
    end

    def inc
      @pc += 1
    end

    def [](index)
      @memory[index]
    end

    def []=(index, value)
      @memory[index] = value
    end

    def zero?
      @value == 0 || @value == "0"
    end

    def neg?
      value.to_s =~ /^-/ || value < 1
    end
  end

  class Machine
    include Instruction

    def self.run(filepath)
      im = parse_source_code(File.read(filepath))
      new(im).run
    end

    def self.parse_source_code(strs)
      [nil] + strs.split(/\R/).reject { |line| line.start_with?("#")}.map do |line|
        instruction, arg = line.split
        [instruction.downcase.to_sym, arg]
      end
    end

    attr_accessor :state, :im
    def initialize(im)
      @state = State.new
      @im = im
    end

    # note nil => 0 (not perfect but...)
    def deref(arg, state)
      arg && arg =~ /\[\s*(\d+)\s*\]/ ? state[$1.to_i] : arg.to_i
    end

    def run
      while state.pc > 0
        instruction, arg = im[state.pc]
        state.inc

        public_send(instruction || "done", state, deref(arg, state))
      end
    end
  end
end

HRM::Machine.run(ARGV[0])
