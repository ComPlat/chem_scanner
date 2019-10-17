# frozen_string_literal: true

module ChemScanner
  module ChemDraw
    ALIAS_VALUES = [0, 4, 5, 8, 12].freeze

    # CDX Node parser
    class FragmentNode < BaseNode
      require "chem_scanner/chem_draw/node/fragment"
      require "chem_scanner/chem_draw/node/text"

      attr_accessor :num_hydrogens, :atnum, :spin, :charge, :iso, :type,
                    :ext_type, :x, :y, :is_alias, :alias_text,
                    :warning, :warning_data, :fragment, :nested_fragment,
                    :nested_text, :color, :expanded, :point, :is_polymer

      def initialize(parser, parser_type, id)
        super(parser, parser_type, id)

        @num_hydrogens = -1
        @atnum = -1
        @spin = 0
        @charge = 0
        @iso = 0
        @color = 0
        @type = -1
        @ext_type = -1
        @alias_text = ""
        @warning = false
        @warning_data = ""
        @is_alias = false

        @nested_fragment = {}
        @nested_text = {}
        @expanded = false
        @is_polymer = false
      end

      # rubocop:disable Methods/PerceivedComplexity
      def parse_node(tag, nid, data)
        ref = @props_ref[tag]
        ref = ref.nil? ? @obj_ref[tag] : ref

        case ref
        when "Node_Element" then @atnum = read_value(tag, data)
        when "Atom_Radical" then @spin = read_value(tag, data)
        when "Atom_Isotope" then @iso = read_value(tag, data)
        when "Fragment"
          frag = Fragment.new(@parser, @parser_type, nid)
          frag.read
          @nested_fragment[nid] = frag
        when "Atom_GenericNickname"
          nickname = send("#{@parser_type}_text", data)
          @generic_nickname = nickname.first[:text] unless nickname.empty?
        when "Node_Type"
          @type = read_type(tag, data, CDXML_NODE_TYPE)
          @is_alias = ALIAS_VALUES.include?(@type)
        when "2DPosition" then @x, @y = read_value(tag, data)
        when "Atom_Charge" then @charge = read_value(tag, data)
        when "Text"
          @text = Text.new(@parser, @parser_type, nid, true)
          # NOTE: MUST read first in order to maintain CDX reader
          @text.read
          @polygon = @text.polygon

          @nested_text[@text.id] = @text
        when "ChemicalWarning"
          @warning = true
          @warning_data = @parser_type == "cdxml" ? data.text : data
        when "Atom_NumHydrogens" then @num_hydrogens = read_value(tag, data)
        when "ForegroundColor" then @color = read_value(tag, data)
        when "Atom_ExternalConnectionType"
          @ext_type = read_type(tag, data, CDXML_ATOM_EXTERNAL_CONNECTION_TYPE)
        else do_unhandled(tag)
        end
      end
      # rubocop:enable Methods/PerceivedComplexity

      def post_parse_node
        @point = Geometry::Point.new(@x, @y)

        if !@text.nil? && !@text.value.empty?
          @alias_text = @text.value
          return
        end

        interpreter = ChemScanner::Interpreter
        if !@generic_nickname.nil? &&
            interpreter.rgroup_atom?(@generic_nickname)
          @is_alias = true
          @type = 7
          @alias_text = @generic_nickname
        end
      end

      def leftbottom
        @polygon.nil? ? point : @polygon.bounding_box.leftbottom
      end

      def righttop
        @polygon.nil? ? point : @polygon.bounding_box.righttop
      end

      def has_nil_coord?
        (@x.nil? || @y.nil?) && @polygon.nil?
      end

      def set_type(type)
        @type = type
      end

      def set_expanded
        @expanded = true
      end

      def set_is_polymer
        @is_alias = true
        @is_polymer = true
      end

      def clone
        cloned = self.class.new(@parser, @parser_type, nil)
        cloned.num_hydrogens = @num_hydrogens
        cloned.atnum = @atnum
        cloned.spin = @spin
        cloned.charge = @charge
        cloned.iso = @iso
        cloned.color = @color
        cloned.type = @type
        cloned.alias_text = @alias_text
        cloned.warning = @warning
        cloned.warning_data = @warning_data
        cloned.is_alias = @is_alias
        cloned.expanded = @expanded

        cloned.nested_fragment = {}
        cloned.nested_text = {}
        @nested_fragment.each { |k, v| cloned.nested_fragment[k] = v }
        @nested_text.each { |k, v| cloned.nested_text[k] = v }

        cloned
      end
    end
  end
end
