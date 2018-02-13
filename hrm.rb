#!/usr/bin/env ruby

require 'json'

#levels = JSON.parse(File.read('original_levels.json'))

module HRM
  module Instruction
    def inbox(address)
      if @value = STDIN.gets&.chomp
        if @value =~ /^[-+]?[0-9]+$/
          @value = @value.to_i
        end
      else
        @pc = -1
      end
    end

    def outbox(address)   ; puts @value ; @value = nil ; end
    def copyfrom(address) ; @value = @memory[address] ; end
    def copyto(address)   ; @memory[address] = @value ; end
    def add(address)      ; @value += @memory[address] ; end
    def sub(address)      ; @value -= @memory[address] ; end
    def bumpup(address)   ; @value = @memory[address] += 1 ; end
    def bumpdown(address) ; @value = @memory[address] -= 1 ; end
    def jump(address)     ; @pc = address ; end
    def jump_if_zero(address) ; @pc = address if @value == 0 || @value == "0" ; end
    def jump_if_neg(address) ; @pc = address  if @value < 1 || @value.to_s =~ /^-/ ; end
  end
end

####

module HRM
  class Machine
    include Instruction

    MAX_MEMORY_SIZE = 25

    def self.run(filepath)
      new(File.read(filepath)).run
    end

    def initialize(source)
      @source = source
      @im = [nil] + parse_source_code
      @value = nil
      @pc = 1
      @memory = Array.new(MAX_MEMORY_SIZE)
    end

    def run
      while @pc > 0
        instruction, arg = @im[@pc]
        @pc += 1

        break if instruction.nil?

        if arg
          if arg =~ /\[\s*(\d+)\s*\]/
            arg = @memory[$1.to_i]
          else
            arg = arg.to_i
          end
        end
        public_send(instruction, arg)
      end
    end

    private

    def parse_source_code
      @source.split(/\R/).reject { |line| line.start_with?("#")}.map do |line|
        instruction, arg = line.split
        [instruction.downcase.to_sym, arg]
      end
    end
  end
end

HRM::Machine.run(ARGV[0])
