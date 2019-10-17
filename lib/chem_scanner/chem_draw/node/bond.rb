# frozen_string_literal: true

module ChemScanner
  module ChemDraw
    CDX_BOND_ORDER = {
      0x0001 => 1,
      0x0002 => 2,
      0x0004 => 3,
      0x0008 => 4,
      0x0010 => 5,
      0x0020 => 6,
      0x0040 => 0.5,
      0x0080 => 1.5,
      0x0100 => 2.5,
      0x0200 => 3.5,
      0x0400 => 4.5,
      0x0800 => 5.5,
      0x1000 => "dative",
      0x2000 => "ionic",
      0x4000 => "hydrogen",
    }.freeze

    CDXML_BOND_DISPLAY = {
      "Solid" => 0,
      "Dash" => 1,
      "Hash" => 2,
      "WedgedHashBegin" => 3,
      "WedgedHashEnd" => 4,
      "Bold" => 5,
      "WedgeBegin" => 6,
      "WedgeEnd" => 7,
      "Wavy" => 8,
      "HollowWedgeBegin" => 9,
      "HollowWedgeEnd" => 10,
      "WavyWedgeBegin" => 11,
      "WavyWedgeEnd" => 12,
      "Dot" => 13,
      "DashDot" => 14,
    }.freeze

    # CDX Bond parser
    class Bond < BaseNode
      attr_accessor :begin_id, :end_id, :stereo, :order, :color

      def initialize(parser, parser_type, id)
        super(parser, parser_type, id)

        @begin_id = nil
        @end_id = nil
        @stereo = 0
        @order = 1

        @color = 0
      end

      def parse_node(tag, _id, data)
        case @props_ref[tag]
        when "Bond_Begin" then @begin_id = read_value(tag, data)
        when "Bond_End" then @end_id = read_value(tag, data)
        when "Bond_Order" then @order = bond_order(read_value(tag, data))
        when "Bond_Display" then @stereo = bond_display(tag, data)
        when "ForegroundColor" then @color = read_value(tag, data)
        else do_unhandled(tag)
        end
      end

      def bond_order(val)
        return val if @parser_type == "cdxml"

        CDX_BOND_ORDER[val] || 0
      end

      def bond_display(tag, data)
        return read_value(tag, data) if @parser_type == "cdx"

        CDXML_BOND_DISPLAY[data.text]
      end

      def end_points
        [@begin_id, @end_id]
      end

      def replace_endpoint(endpoint, new_point)
        if @begin_id == endpoint
          @begin_id = new_point
        elsif @end_id == endpoint
          @end_id = new_point
        end
      end

      def other_endpoint(endpoint)
        endpoint == @begin_id ? @end_id : @begin_id
      end

      def has_endpoint?(id)
        [@begin_id, @end_id].include?(id)
      end
    end
  end
end
