# frozen_string_literal: true

module ChemScanner
  module ChemDraw
    # CDX Graphic parser
    class Graphic < BaseNode
      attr_reader :arrow_id, :type, :arrow_head, :head, :tail,
                  :line_type, :orbital_type, :oval_type, :polygon

      GRAPHIC_BRACKET_TYPE = 6

      def initialize(parser, parser_type, id)
        super(parser, parser_type, id)

        @line_type = 0
      end

      def parse_node(tag, _id, data)
        case @props_ref[tag]
        when "Arrow_Type"
          @arrow_head = read_type(tag, data, CDXML_ARROW_TYPE)
        when "Line_Type"
          @line_type = read_type(tag, data, CDXML_LINE_TYPE)
        when "Graphic_Type"
          @type = read_type(tag, data, CDXML_GRAPHIC_TYPE)
        # Graphic objects are the only objects whose kCDXProp_BoundingBox
        # property has a special meaning, representing a pair of points
        # rather than a rectangle.
        when "BoundingBox" then @polygon = read_value(tag, data)
        when "SupersededBy" then @arrow_id = read_value(tag, data)
        when "3DMajorAxisEnd" then @right, @top = read_value(tag, data)
        when "3DMinorAxisEnd" then @left, @bottom = read_value(tag, data)
        when "Orbital_Type"
          @orbital_type = read_type(tag, data, CDXML_ORBITAL_TYPE)
        when "Oval_Type"
          @oval_type = read_type(tag, data, CDXML_OVAL_TYPE)
        else do_unhandled(tag)
        end
      end

      def post_parse_node
        # When dealing with orbital, boundingbox is not reliable
        build_orbital_polygon if @type == 5

        # In case of Graphic is arrow
        # Treat as arrow if is a line, no "SupersededBy" and has "BoundingBox"
        return unless @type == 1 && @arrow_id.nil? && !@polygon.nil?

        vertices = @polygon.vertices
        # start point ~ head
        sp = vertices[1]
        # end point ~ tail
        ep = vertices[3]

        @head = { x: sp.x, y: sp.y }
        @tail = { x: ep.x, y: ep.y }
      end

      def build_orbital_polygon
        return unless @orbital_type == 256 && @oval_type == 3

        p1 = Geometry::Point.new(@left, @bottom)
        p2 = Geometry::Point.new(@left, @top)
        p3 = Geometry::Point.new(@right, @top)
        p4 = Geometry::Point.new(@right, @bottom)

        @polygon = Geometry::Polygon.new([p1, p2, p3, p4])
      end

      def line?
        @type == 1 && @arrow_id.nil? && (@arrow_head.nil? || @arrow_head.zero?)
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

      def cross?
        false
      end
    end
  end
end
