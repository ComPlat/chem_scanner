# frozen_string_literal: true

module ChemScanner
  module Interpreter
    using Extension

    # Base Arrow, independent from reader
    class Arrow
      attr_accessor :id, :middle_points, :tail, :head, :descriptions,
                    :text_arr, :cross, :cross_lines, :reagents_polygons,
                    :height, :line_type

      # Polyline path: tail -> middle1 -> middle2 -> ... -> head
      def initialize(geometry)
        @geometry = geometry
        @id = geometry.id
        @tail = Geometry::Point.new(geometry.tail[:x], geometry.tail[:y])
        @head = Geometry::Point.new(geometry.head[:x], geometry.head[:y])

        @middle_points = []
        @cross = geometry.cross?
        @line_type = geometry.line_type
        @cross_lines = []
        @height = 0
        @text_arr = []
        @reagents_polygons = []
      end

      def points
        [@tail] + @middle_points + [@head]
      end

      def segments
        arr = []
        points.each_with_index do |point, idx|
          next if idx == points.count - 1

          segment = Geometry::Segment.new(point, points[idx + 1])
          arr.push(segment)
        end

        arr
      end

      def head_segment
        point = @middle_points.count.zero? ? @tail : @middle_points.last
        Geometry::Segment.new(point, @head)
      end

      def head_perpen_points
        return nil if @head.nil? || @height.zero?

        tail = @middle_points.count.zero? ? @tail : @middle_points.last
        Geometry::Segment.new(tail, @head).tail_perpen_points_dist(@height)
      end

      def head_perpen_segment
        p1, p2 = head_perpen_points
        Geometry::Segment.new(p1, p2)
      end

      def tail_segment
        point = @middle_points.count.zero? ? @head : @middle_points.first
        Geometry::Segment.new(point, @tail)
      end

      def tail_perpen_points
        return nil if @tail.nil? || @height.zero?

        head = @middle_points.count.zero? ? @head : @middle_points.first
        Geometry::Segment.new(@tail, head).head_perpen_points_dist(@height)
      end

      def tail_perpen_segment
        p1, p2 = tail_perpen_points
        Geometry::Segment.new(p1, p2)
      end

      def tail_head_segment
        Geometry::Segment.new(@tail, @head)
      end

      def add_cross_segment(other)
        @cross_lines.push(other)
        @cross = true
      end

      def change_head(new_head)
        @middle_points.push(@head)
        @head = Geometry::Point.new(new_head[:x], new_head[:y])
      end

      def change_tail(new_tail)
        @middle_points.unshift(@tail)
        @tail = Geometry::Point.new(new_tail.x, new_tail.y)
      end

      def update_tail(new_tail)
        @tail = Geometry::Point.new(new_tail.x, new_tail.y)
      end

      # Polyline path: tail -> middle1 -> middle2 -> ... -> head
      def build_polygons(height)
        @height = height
        @reagents_polygons = []

        segments.each do |segment|
          p1, p2 = segment.head_perpen_points_dist(height)
          p3, p4 = segment.tail_perpen_points_dist(height)

          polygon = Geometry::Polygon.new([p1, p2, p4, p3])
          @reagents_polygons.push(polygon)
        end
      end

      def build_polygons_on_polygons(polygons)
        list_height = []
        @reagents_polygons = []

        segments.each do |segment|
          p1 = segment.point1
          p2 = segment.point2
          hperpen = segment.to_line.perpen_line_via_point(p1)
          tperpen = segment.to_line.perpen_line_via_point(p2)

          list_points = []

          polygons.each do |poly|
            next unless segment.polygon_in_range(poly)

            poly_points = poly.vertices.each_with_object([]) do |v, arr|
              arr.push(hperpen.point_projection(v))
              arr.push(tperpen.point_projection(v))
            end
            list_points.concat(poly_points).concat([p1, p2])
          end

          if list_points.empty?
            build_polygons(0.2)
            next
          end

          xmax = list_points.map(&:x).max + 0.5
          xmin = list_points.map(&:x).min - 0.5
          ymin = list_points.map(&:y).min - 0.5
          ymax = list_points.map(&:y).max + 0.5

          poly_points = [
            Geometry::Point.new(xmin, ymin),
            Geometry::Point.new(xmin, ymax),
            Geometry::Point.new(xmax, ymax),
            Geometry::Point.new(xmax, ymin),
          ]
          list_height.push((ymax - ymin).abs)

          @reagents_polygons.push(Geometry::Polygon.new(poly_points))
        end

        @height = list_height.max || 0.1
      end

      def product_side?(point)
        line = head_perpen_segment.to_line
        side = line.point_side(@head) * line.point_side(point)

        side.positive?
      end

      def reactant_side?(point)
        line = tail_perpen_segment.to_line
        side = line.point_side(@tail) * line.point_side(point)

        side.positive?
      end

      def contains_point?(point)
        segments.each do |segment|
          ppoint = segment.to_line.point_projection(point)
          return ppoint if segment.contains_point?(ppoint)
        end

        nil
      end

      def min_distance_to_polygon(polygon)
        dist_arr = []
        bbox = polygon.bounding_box

        segments.each do |segment|
          dist = segment.distance_to_boundingbox(bbox)
          dist_arr.push(dist)
        end

        dist_arr.min
      end

      def dist_to_head(point)
        Geometry::Segment.new(point, @head).length
      end

      def dist_to_tail(point)
        Geometry::Segment.new(point, @tail).length
      end

      def polygon_around?(poly)
        @reagents_polygons.each do |rpoly|
          return true if poly.around_polygon?(rpoly)
        end

        false
      end

      def all_intersects_with_segment?(segment)
        @reagents_polygons.each do |rpoly|
          return false unless segment.intersects_with_polygon?(rpoly)
        end

        true
      end

      def parallel_to?(other)
        segments.each do |seg|
          other.segments.each do |oseg|
            return false unless seg.parallel_to?(oseg)
          end
        end

        true
      end

      def poly_in_middle?(poly)
        poly_points = poly.bounding_box.points.push(poly.center)

        in_middle = false
        poly_points.each do |point|
          in_middle |= point_in_middle(point)
        end

        in_middle
      end

      def point_in_middle(target_point)
        in_middle = false

        points.each_with_index do |point, idx|
          next if idx.zero?

          segment = Geometry::Segment.new(point, points[idx - 1])
          ppoint = segment.to_line.point_projection(target_point)

          from_head = if idx == 1 then true
                      elsif idx == (points.size - 1) then false
                      end
          in_middle |= segment.point_in_range(ppoint, 4.0 / 5.0, from_head)
        end

        in_middle
      end

      def clone
        cloned = self.class.new(@geometry)
        cloned.id = get_tempid

        cloned.tail = @tail.clone
        cloned.head = @head.clone
        cloned.middle_points = Marshal.load(Marshal.dump(@middle_points))

        cloned.descriptions = @descriptions
        cloned.cross = @cross
        cloned.cross_lines = Marshal.load(Marshal.dump(@cross_lines))
        cloned.reagents_polygons = @reagents_polygons.clone
        cloned.height = @height
        cloned.line_type = @line_type

        cloned
      end

      def get_tempid
        @geometry.get_tempid
      end

      def inspect
        (
          "#<Arrow: id=#{id}, " +
            "reagents_polygon: #{reagents_polygons}," +
            "tail: #{tail}, " +
            "head: #{head}, " +
            "middle_points: #{middle_points}, " +
            "cross: #{cross}, " +
            "height: #{height}, " +
            "line_type: #{line_type}, " +
            "cross_lines: #{cross_lines}, " +
            "text_arr: #{text_arr} >"
        )
      end
    end
  end
end
