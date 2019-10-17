# frozen_string_literal: true

module ChemScanner
  module ChemDraw
    # CDX Graphic parser
    class FontTable < BaseNode
      attr_reader :table

      def initialize(parser_type, data)
        @parser_type = parser_type
        @data = data
      end

      def read
        @parser_type == "cdx" ? read_cdx : read_cdxml
      end

      def read_cdx
        @table = []
        run_count = read_int(@data[2, 2], true)

        iter = 4
        (1..run_count).each do
          font, length = read_cdx_font_attribute(iter)
          @table.push(font)
          iter += 6 + length
        end

        @table
      end

      def read_cdx_font_attribute(iter)
        id = read_int(@data[iter, 2], true)
        charset = read_int(@data[iter + 2, 2], true)
        length = read_int(@data[iter + 4, 2], true)
        name = @data[iter + 6, length]

        [{ id: id, charset: charset, name: name }, length]
      end

      def read_cdxml
        @table = @data.element_children.each_with_object([]) do |font, table|
          next if font.name != "font"

          id = font.attr("id").to_i
          charset = font.attr("charset")
          name = font.attr("name")

          table.push(id: id, charset: charset, name: name)
        end
      end
    end
  end
end
