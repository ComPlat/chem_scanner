# frozen_string_literal: true

require "geometry"

module ChemScanner
  include Geometry

  # Extension module
  module Extension
    # Monkey path Polygon class from ruby-geometry
    refine Geometry::Polygon do
      def center
        lb = bounding_box.leftbottom
        rt = bounding_box.righttop

        Point.new((lb.x + rt.x) / 2, (lb.y + rt.y) / 2)
      end

      def height
        lb = bounding_box.leftbottom
        lb.distance_to(bounding_box.lefttop)
      end

      def width
        lb = bounding_box.leftbottom
        lb.distance_to(bounding_box.rightbottom)
      end

      def intersects_with_polygon?(other)
        edges.each do |e1|
          other.edges.each do |e2|
            return true if e1.intersects_with?(e2)
          end
        end

        false
      end

      def contains_polygon?(other)
        other.vertices.each do |v1|
          return false unless contains?(v1)
        end

        true
      end

      def around_polygon?(other)
        (
          contains_polygon?(other) || other.contains_polygon?(self) ||
          contains?(other.center) || other.contains?(center)
        )
      end

      def merge_polygon(another)
        lb = bounding_box.leftbottom
        rt = bounding_box.righttop

        alb = another.bounding_box.leftbottom
        art = another.bounding_box.righttop

        left = [lb.x, alb.x].min
        bottom = [lb.y, alb.y].min
        right = [rt.x, art.x].max
        top = [rt.y, art.y].max

        p1 = Point.new(left, bottom)
        p2 = Point.new(left, top)
        p3 = Point.new(right, top)
        p4 = Point.new(right, bottom)

        Polygon.new([p1, p2, p3, p4])
      end

      def distance_to_point(point)
        min_dist = 9_999_999

        edges.each do |edge|
          dist = edge.distance_to(point)
          min_dist = dist if dist < min_dist
        end

        min_dist
      end

      def euclid_distance_to_point(point)
        min_dist = 9_999_999

        edges.each do |edge|
          dist = edge.euclid_distance_to_point(point)
          min_dist = dist if dist < min_dist
        end

        min_dist
      end

      def intersection_points_with_line(line)
        points = []

        edges.each do |edge|
          eline = edge.to_line
          inter_x = eline.intersect_x(line)
          next if inter_x.nil?

          inter_y = line.y_from_x(inter_x)
          inter_y = edge.to_line.y_from_x(inter_x) if inter_y.nil?

          point = Point.new(inter_x, inter_y)
          points.push(point) if edge.contains_point?(point)
        end

        points
      end
    end
  end
end
