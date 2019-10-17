# frozen_string_literal: true

require "geometry"

module ChemScanner
  include Geometry

  # Monkey patch ruby-geometry class
  module Extension
    # Monkey patch Segment class
    refine Geometry::Segment do
      def points
        [point1, point2]
      end

      def contains_point?(point)
        l1 = Geometry.distance(point1, point)
        l2 = Geometry.distance(point, point2)

        length.round(2) === (l1 + l2).round(2)
      end

      def contains_segment?(other)
        contains_point?(other.point1) && contains_point?(other.point2)
      end

      def center
        Point.new((point1.x + point2.x) / 2, (point1.y + point2.y) / 2)
      end

      def to_line
        Line.new(point1, point2)
      end

      def intersects_with_polygon?(polygon)
        count = 0
        polygon.edges.each do |edge|
          count += 1 if edge.intersects_with?(self)
        end

        count > 1
      end

      def intersects_with_line?(line)
        sline = to_line
        inter_x = sline.intersect_x(line)
        return false if inter_x.nil?

        inter_y = line.y_from_x(inter_x)
        inter_y = to_line.y_from_x(inter_x) if inter_y.nil?
        return false if inter_y.nil?

        point = Point.new(inter_x, inter_y)
        contains_point?(point)
      end

      def head_perpen_points_dist(distance)
        dx = point2.x - point1.x
        dy = point2.y - point1.y
        dist = Math.sqrt((dx * dx) + (dy * dy))
        dx /= dist
        dy /= dist
        x3 = point2.x + (distance * dy)
        y3 = point2.y - (distance * dx)
        x4 = point2.x - (distance * dy)
        y4 = point2.y + (distance * dx)
        [Point.new(x3, y3), Point.new(x4, y4)]
      end

      def tail_perpen_points_dist(distance)
        dx = point1.x - point2.x
        dy = point1.y - point2.y
        dist = Math.sqrt((dx * dx) + (dy * dy))
        dx /= dist
        dy /= dist
        x3 = point1.x + (distance * dy)
        y3 = point1.y - (distance * dx)
        x4 = point1.x - (distance * dy)
        y4 = point1.y + (distance * dx)
        [Point.new(x4, y4), Point.new(x3, y3)]
      end

      def parallel_at(point)
        x4 = point.x + point2.x - point1.x
        y4 = point.y + point2.y - point1.y
        Point.new(x4, y4)
      end

      def euclid_distance_to(other)
        l1 = point1.distance_to(other.point1)
        l2 = point2.distance_to(other.point1)
        l3 = point1.distance_to(other.point2)
        l4 = point2.distance_to(other.point2)

        [l1, l2, l3, l4].min
      end

      def euclid_distance_to_point(point)
        l1 = point1.distance_to(point)
        l2 = point2.distance_to(point)

        [l1, l2].min
      end

      def euclid_distance_to_polygon(poly)
        dist = []

        poly.bounding_box.edges.each do |edge|
          min_dist = euclid_distance_to(edge)
          dist.push(min_dist)
        end

        dist.min
      end

      def distance_to_boundingbox(bbox)
        dists = []

        bbox.edges.each do |edge|
          dist = distance_to_segment(edge)
          dists.push(dist)
        end

        dists.min
      end

      def distance_to_segment(other)
        [
          other.distance_to(point1),
          other.distance_to(point2),
          distance_to(other.point1),
          distance_to(other.point2),
        ].min
      end

      def perpen_segment_via_point(point)
        sline = to_line
        pline = sline.perpen_line_via_point(point)

        inter_point = pline.intersection_points_with(sline)
        return nil if inter_point.nil?

        Segment.new(point, inter_point)
      end

      def point_in_range(point, range, from_head = nil)
        return false unless contains_point?(point)

        dist1 = point1.distance_to(point)
        dist2 = point2.distance_to(point)

        dist = case from_head
               when true then dist1
               when false then dist2
               when nil then [dist1, dist2].max
               else return false
               end

        (dist / length) < range
      end

      def polygon_in_range(polygon)
        line = to_line

        polygon.vertices.each do |vertex|
          ppoint = line.point_projection(vertex)
          return true if contains_point?(ppoint)
        end

        false
      end

      def slice_to_many_points(num)
        return [] if num < 2

        delta_x = (point1.x - point2.x).abs
        delta_y = (point1.y - point2.y).abs

        avg_x = delta_x / (num + 1)
        avg_y = delta_y / (num + 1)
        default = OpenStruct.new(
          x: [point1.x, point2.x].min, y: [point1.y, point2.y].min,
        )

        (1..num).to_a.reduce([]) do |arr, _|
          prev = arr.last || default
          arr.push(Point.new(prev.x + avg_x, prev.y + avg_y))
        end
      end

      def to_gis
        "SEGMENT((#{point1.x}, #{point1.y}), (#{point2.x}, #{point2.y}))"
      end
    end
  end
end
