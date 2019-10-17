# frozen_string_literal: true

module ChemScanner
  module ChemDraw
    # Class which traverse the tree in CDX binary files
    class CdxReader
      HEADER_STRING_LEN = 8
      HEADER_STRING = "VjCD0100"
      HEADER_LENGTH = 28
      TAG_OBJECT = 0x8000

      attr_reader :len, :valid, :iter, :bin, :depth, :cur_tag

      def initialize(file, is_path)
        @ids = []
        @depth = 0

        @bin = is_path ? IO.binread(file) : file

        if @bin[0, HEADER_STRING_LEN] == HEADER_STRING
          @iter = HEADER_LENGTH
          @valid = true
        else
          @valid = false
        end
      end

      def end?
        @iter > @bin.size
      end

      def read_next(objects_only = false, target_depth = -2)
        @cur_tag = read(objects_only, target_depth)
        @cur_tag
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def read(objects_only = false, target_depth = -2)
        while @iter <= @bin.size
          tag = read_int16

          return -1 if tag.nil?

          if tag.zero?
            if @depth.zero?
              @iter = @bin.size
              return 0
            end
            @depth -= 1
            @ids.pop

            return 0 if target_depth.negative? || @depth == target_depth
          elsif (tag & TAG_OBJECT).nonzero?
            @ids.push(read_int32)
            @depth += 1

            return tag if target_depth.negative? || @depth - 1 == target_depth
          else
            @len = read_int16
            unless objects_only
              @buf = @bin[@iter, @len]
              @iter += @len

              return tag
            end

            @iter += @len
          end
        end
        0
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def ignore_object
        read_next(true, @depth - 1)
      end

      def current_id
        @ids.last
      end

      def data
        @buf.dup
      end

      private

      def read_int16
        buf = @bin[@iter, 2]
        @iter += 2
        buf.unpack("S")[0]
      end

      def read_int32
        buf = @bin[@iter, 4]
        @iter += 4
        buf.unpack("L")[0]
      end
    end
  end
end
