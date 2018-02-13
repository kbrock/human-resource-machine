#!/usr/bin/env ruby

require 'json'

#levels = JSON.parse(File.read('original_levels.json'))

module HRM
  module Instruction
    def inbox
      unless @value = STDIN.gets&.chomp
        exit(0)
      end

      if @value =~ /^[-+]?[0-9]+$/
        @value = @value.to_i
      end
    end

    def outbox
      puts @value
      @value = nil
    end

    def copyfrom(address)
      @value = @memory[address]
    end

    def copyto(address)
      @memory[address] = @value
    end

    def add(address)
      @value += @memory[address]
    end

    def sub(address)
      @value -= @memory[address]
    end

    def bumpup(address)
      @value = @memory[address] += 1
    end

    def bumpdown(address)
      @value = @memory[address] -= 1
    end

    def jump(address)
      @pc = address
    end

    def jump_if_zero(address)
      if @value.zero?
        @pc = address
      end
    end

    def jump_if_neg(address)
      if @value.negative?
        @pc = address
      end
    end
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
      loop do
        instruction, arg = @im[@pc]
        @pc += 1

        exit(0) if instruction.nil?

        if arg.nil?
          public_send(instruction)
        else
          if arg =~ /\[\s*(\d+)\s*\]/
            public_send(instruction, @memory[$1.to_i])
          else
            public_send(instruction, arg.to_i)
          end
        end
      end
    end

    private

    def parse_source_code
      @source.split(/\R/).map do |line|
        if line.start_with?("#")
          nil
        else
          instruction, arg = line.split
          [instruction.downcase.to_sym, arg]
        end
      end.compact
    end
  end
end

HRM::Machine.run(ARGV[0])
