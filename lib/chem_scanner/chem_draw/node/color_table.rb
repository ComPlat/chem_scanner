module ChemScanner
  module ChemDraw
    # ColorTable
    class ColorTable < BaseNode
      attr_reader :table

      def initialize(parser_type, data)
        @parser_type = parser_type
        @data = data
      end

      def read
        @parser_type == "cdx" ? read_cdx : read_cdxml
      end

      def read_cdx
        @nums = read_int(@data[0, 2], true)
        rgbs = binary_chunks(@data[2..-1], 2).map { |x| read_int(x, true) }

        table = rgbs.each_slice(3).to_a.map do |x|
          x.reduce("") do |memo, c|
            rgb = c >> 8
            memo << rgb.to_s(16).rjust(2, "0")
          end
        end

        @table = %w[000000 FFFFFF] + table
      end

      def read_cdxml
        table = @data.element_children.each_with_object([]) do |color, t|
          next if color.name != "color"

          rgb = %w[r g b].reduce("") do |memo, c|
            ct = color.attr(c).to_i * 255
            memo << ct.to_s(16).rjust(2, "0")
          end

          t.push(rgb)
        end

        @table = %w[000000 FFFFFF] + table
      end
    end
  end
end
