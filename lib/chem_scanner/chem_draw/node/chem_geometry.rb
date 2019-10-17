# frozen_string_literal: true

module ChemScanner
  module ChemDraw
    # Geometry parser
    class ChemGeometry < BaseNode
      attr_reader :tail, :head, :head_type, :nogo, :line_type

      def initialize(parser, parser_type, id)
        super(parser, parser_type, id)

        @middle_points = []
        @line_type = 0
      end

      # NOTE: head ----> tail (head at tail)
      def parse_node(tag, _nid, data)
        case @props_ref[tag]
        when "3DTail"
          x, y = read_value(tag, data)
          @tail = { x: x, y: y }
        when "3DHead"
          x, y = read_value(tag, data)
          @head = { x: x, y: y }
        when "Arrow_ArrowHead_Head"
          @arrow_head = read_type(tag, data, CDXML_ARROW_TYPE)
        when "Arrow_NoGo" then @nogo = read_value(tag, data)
        when "Line_Type"
          @line_type = read_type(tag, data, CDXML_LINE_TYPE)
        else do_unhandled(tag)
        end
      end

      def segment
        Geometry::Segment.new_by_arrays(
          [@tail[:x], @tail[:y]],
          [@head[:x], @head[:y]],
        )
      end

      def vector
        segment.to_vector
      end

      def line
        segment.to_line
      end

      def headless
        @arrow_head != 2
      end

      def cross?
        !@nogo.nil?
      end
    end
  end
end
