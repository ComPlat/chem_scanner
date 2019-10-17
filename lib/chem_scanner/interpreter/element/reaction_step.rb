# frozen_string_literal: true

module ChemScanner
  module Interpreter
    # Reaction Step
    class ReactionStep
      attr_accessor :description, :time, :temperature, :reagents, :number

      def initialize
        @number = 0
        @description = ""
        @time = ""
        @temperature = ""

        @reagents = []
      end

      def inspect
        (
          "#<ReactionStep: description=#{@description}, " +
          "number=#{@number}, " +
          "time=#{@time}, " +
          "temperature=#{@temperature}, " +
          "reagents=#{@reagents}"
        )
      end

      def to_hash
        {
          number: @number,
          description: @description,
          time: @time,
          temperature: @temperature,
          reagents: @reagents,
        }
      end
    end
  end
end
