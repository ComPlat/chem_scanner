# frozen_string_literal: true

module ChemScanner
  module ChemDraw
    # CDX Fragment parser
    class Fragment < BaseNode
      require "chem_scanner/chem_draw/node/fragment_node"
      require "chem_scanner/chem_draw/node/bond"

      attr_accessor :boxed, # indicate if fragment is boxed within an rectangle
                    :polygon, :node_map, :bond_map, :graphic_map

      def initialize(parser, parser_type, id)
        super(parser, parser_type, id)
        @boxed = false

        @node_map = {}
        @bond_map = {}

        @graphic_map = {}
      end

      def parse_node(tag, nid, _data)
        case @props_ref.key?(tag) || @obj_ref[tag]
        when "Node" then create_node(nid)
        when "Bond" then create_bond(nid)
        when "Graphic"
          graphic = Graphic.new(@parser, @parser_type, id)
          graphic.read
          @graphic_map[id] = graphic
        # when "BoundingBox" then @polygon = read_value(tag, data)

        # NOTE: Indicates that this object represents some properties
        # in some other objects.
        # when "RepresentsProperty" then @represent = true
        else do_unhandled(tag)
        end
      end

      def post_parse_node
        return if !@polygon.nil? || @node_map.count.zero?

        rebuild_polygon
      end

      def rebuild_polygon
        fn = @node_map.first[1]
        lb = Geometry::Point.new(fn.x, fn.y)
        rt = Geometry::Point.new(fn.x, fn.y)

        @node_map.each_value do |node|
          # next if node.x.nil? || node.y.nil?
          next if node.has_nil_coord?

          nlb = node.leftbottom
          nrt = node.righttop

          lb.x = nlb.x if nlb.x < lb.x
          lb.y = nlb.y if nlb.y < lb.y

          rt.x = nrt.x if nrt.x > rt.x
          rt.y = nrt.y if nrt.y > rt.y
        end

        points = [
          Geometry::Point.new(lb.x, lb.y),
          Geometry::Point.new(lb.x, rt.y),
          Geometry::Point.new(rt.x, rt.y),
          Geometry::Point.new(rt.x, lb.y),
        ]
        @polygon = Geometry::Polygon.new(points)
      end

      def create_node(id)
        node = FragmentNode.new(@parser, @parser_type, id)
        node.read
        @node_map[id] = node
      end

      def create_bond(id)
        bond = Bond.new(@parser, @parser_type, id)
        bond.read
        @bond_map[id] = bond
      end

      def get_node_with_type(type)
        @node_map.select { |_, v| v.type == type }
      end

      # Check if fragment has ExternalConnectionPoint node
      def get_external_point
        get_node_with_type(12)
      end

      # Get the internal id for Fragment node
      def get_internal_nids
        ext_node = get_external_point
        return [] if ext_node.count.zero?

        ext_ids = ext_node.keys
        internal_ids = []
        ext_ids.each do |ext_id|
          hbond = bond_has_endpoint(ext_id)
          _, bond = hbond

          internal_ids.push(bond.other_endpoint(ext_id))
        end
        [ext_ids, internal_ids]
      end

      def bond_has_endpoint(endpoint)
        @bond_map.detect { |_, b| b.end_points.include?(endpoint) }
      end

      def clone
        cloned = self.class.new(@parser, @parser_type, @id)
        cloned.boxed = @boxed
        cloned.clone_node_map(@node_map)
        cloned.clone_bond_map(@bond_map)

        cloned
      end

      def clone_node_map(node_map)
        @node_map = {}
        node_map.each do |k, v|
          @node_map[k] = v
        end
      end

      def clone_bond_map(bond_map)
        @bond_map = {}
        bond_map.each do |k, v|
          @bond_map[k] = v
        end
      end

      def set_new_id
        new_id = @parser.get_tempid
        set_id(new_id)
        new_id
      end

      def set_id(new_id)
        @id = new_id
      end
    end
  end
end
