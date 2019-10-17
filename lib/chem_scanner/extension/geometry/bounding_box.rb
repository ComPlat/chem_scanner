# frozen_string_literal: true

require "geometry"

module ChemScanner
  # Extension module
  module Extension
    include Geometry

    # Monkey path BoundingBox class from ruby-geometry
    refine Geometry::BoundingBox do
      def lefttop
        Point.new(leftbottom.x, righttop.y)
      end

      def rightbottom
        Point.new(righttop.x, leftbottom.y)
      end

      def center
        lb = leftbottom
        rt = righttop

        Point.new((lb.x + rt.x) / 2, (lb.y + rt.y) / 2)
      end

      def edges
        [
          Segment.new(leftbottom, lefttop),
          Segment.new(leftbottom, rightbottom),
          Segment.new(lefttop, righttop),
          Segment.new(rightbottom, righttop),
        ]
      end

      def points
        [leftbottom, lefttop, righttop, rightbottom]
      end

      def euclid_distance_to(other)
        distance_list = []

        edges.each do |edge|
          other.edges.each do |oedge|
            distance_list.push(edge.euclid_distance_to(oedge))
          end
        end

        distance_list.min
      end

      def distance_to_point(point)
        distance_list = []

        edges.each do |edge|
          distance_list.push(edge.distance_to(point))
        end

        distance_list.min
      end

      def euclid_distance_to_point(point)
        point.distance_to(center)
      end

      def area
        Segment.new(leftbottom, lefttop).length *
          Segment.new(lefttop, righttop).length
      end

      def to_gis
        coords = points.map { |point| "(#{point.x}, #{point.y})" }.join(",")
        "POLYGON(#{coords})"
      end

      def contains_point?(point)
        (
          point.x <= righttop.x && point.x >= leftbottom.x &&
          point.y <= righttop.y && point.y >= leftbottom.y
        )
      end
    end
  end
end
