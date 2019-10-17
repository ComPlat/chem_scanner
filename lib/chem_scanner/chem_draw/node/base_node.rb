# frozen_string_literal: true

module ChemScanner
  module ChemDraw
    require "chem_scanner/chem_draw/node/base_value"

    # ChemDraw basic Node
    class BaseNode
      include BaseValue
      attr_reader :parser, :parser_type, :id, :polygon

      def initialize(parser, parser_type, id)
        @parser = parser
        @parser_type = parser_type

        check_id = id.nil? || id.zero?
        @id = check_id ? @parser.get_tempid : id

        case parser_type
        when "cdx" then set_cdx
        when "cdxml" then set_cdxml
        end
      end

      def set_cdx
        @obj_ref = ChemDraw::CDX_OBJ
        @props_ref = ChemDraw::CDX_PROPS
      end

      def set_cdxml
        @obj_ref = ChemDraw::CDXML_OBJ
        @props_ref = ChemDraw::CDXML_PROPS
      end

      def read
        return cdx_read if @parser_type == "cdx"

        cdxml_read
      end

      def cdx_read
        pre_parse_node

        reader = @parser.reader
        tag = reader.read_next

        while tag.positive?
          cid = reader.current_id
          parse_node(tag, cid, reader.data)

          tag = reader.read_next(false)
        end

        post_parse_node
      end

      def cdxml_read
        pre_parse_node

        nid = @parser.reader.attr("id").to_i
        nid = nil if nid.zero?

        @parser.reader.attributes.each_value do |attr|
          parse_node(attr.name, nid, attr)
        end
        # end

        children = @parser.reader.element_children
        children.each do |child|
          @parser.reader = child
          nid = @parser.reader.attr("id").to_i
          nid = nid.to_i unless nid.nil?

          parse_node(child.name, nid, child)
        end

        post_parse_node
      end

      def pre_parse_node; end

      def parse_node
        raise NotImplementedError, "You must implement the parse method"
      end

      def post_parse_node; end

      def bounding_box
        @polygon.bounding_box
      end

      def assign_center
        return if @polygon.nil?
        return unless @center.nil?

        box = bounding_box
        lb = box.leftbottom
        rt = box.righttop

        @center = Geometry::Point.new(
          (lb.x + rt.x) / 2,
          (lb.y + rt.y) / 2,
        )
      end

      def center_x
        return nil if @center.nil?

        center.x
      end

      def center_y
        return nil if @center.nil?

        center.y
      end

      def get_tempid
        parser.get_tempid
      end
    end
  end
end
