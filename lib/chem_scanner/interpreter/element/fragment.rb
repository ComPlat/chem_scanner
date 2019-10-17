# frozen_string_literal: true

module ChemScanner
  module Interpreter
    # Molecule class
    class Fragment
      extend Forwardable

      def_delegators :@fragment, :id, :parser, :parser_type,
                     :polygon, :polygon=, :boxed, :boxed=,
                     :node_map, :node_map=, :bond_map, :bond_map=, :graphic_map

      def initialize(chemdraw_fragment)
        @fragment = chemdraw_fragment
      end

      def add(other)
        @fragment.boxed |= other.boxed

        @fragment.node_map.merge!(other.node_map)
        @fragment.bond_map.merge!(other.bond_map)

        @fragment.rebuild_polygon
      end

      def clone
        cfrag = @fragment.clone
        cfrag.set_new_id
        cloned = self.class.new(cfrag)
        cloned.boxed = @fragment.boxed
        cloned.node_map = @fragment.node_map
        cloned.bond_map = @fragment.bond_map

        cloned
      end

      def set_id(new_id)
        @fragment.id = new_id
      end

      def line?
        node_map = @fragment.node_map
        return false if node_map.count < 3

        points = []
        node_map.values.each_with_index do |node, i|
          points << node.point
          next if i < 2

          seg1 = Geometry::Segment.new(points[i - 3], points[i - 2])
          seg2 = Geometry::Segment.new(points[i - 2], points[i - 1])
          return false unless seg1.lies_on_one_line_with?(seg2)
        end

        true
      end
    end
  end
end
