# frozen_string_literal: true

require "geometry"

module ChemScanner
  # Monkey path Line class from ruby-geometry
  module Extension
    include Geometry

    # Monkey patch Line class
    refine Geometry::Line do
      def angle
        return 90 if vertical?
        return 0 if horizontal?

        p1, p2 = [point1, point2].sort_by(&:x)
        delta_x = p1.x - p2.x
        delta_y = p1.y - p2.y

        arc = if point1.y > point2.y # inverted axis/origin
                Math.atan(delta_y / delta_x)
              else
                Math.atan(delta_x / delta_y)
              end
        (arc.positive? ? arc : (2 * Math::PI + arc)) * 360 / (2 * Math::PI)
      end

      def to_segment
        Segment.new(point1, point2)
      end

      def abc_coeff
        a = point2.y - point1.y
        b = point1.x - point2.x
        c = a * point1.x + b * point1.y

        [a, b, c]
      end

      # Get point belong to the line, give x or y
      def get_point(value, is_y = false)
        if is_y
          x = x_from_y(value)
          Point.new(x, Float(value))
        end

        y = y_from_x(value)
        Point.new(Float(value), y)
      end

      def x_from_y(point_y)
        b = point1.y - point2.y
        return nil if b.zero?

        Float(point1.x - ((point1.y - point_y) * (point1.x - point2.x) / b))
      end

      def y_from_x(point_x)
        b = point1.x - point2.x
        return nil if b.zero?

        Float(point1.y - ((point1.x - point_x) * (point1.y - point2.y)) / b)
      end

      def intersects_with_segment?(segment)
        segment.intersects_with_line?(self)
      end

      def intersects_with_polygon?(polygon)
        polygon.edges.each do |edge|
          return true if intersects_with_segment?(edge)
        end

        false
      end

      def intersection_points_with_polygon(polygon)
        polygon.intersection_points_with_line(self)
      end

      def intersection_points_with(line)
        return nil if parallel_to?(line)

        # Ax + By = C
        a1, b1, c1 = abc_coeff
        a2, b2, c2 = line.abc_coeff

        determinant = a1 * b2 - a2 * b1

        x = (b2 * c1 - b1 * c2) / determinant
        y = (a1 * c2 - a2 * c1) / determinant

        Point.new(x, y)
      end

      # positive: same side with point2
      # negative: same side with point1
      def point_side(point)
        v = Segment.new(point1, point).to_vector
        to_segment.to_vector.cross_product(v)
      end

      def perpen_line_via_point(point)
        if vertical?
          Line.new(point, Point.new(point.x + 5, point.y))
        elsif horizontal?
          Line.new(point, Point.new(point.x, point.y + 5))
        else
          m2 = (-1 / slope)
          x2 = point.x + 5
          y2 = m2 * x2 + (point.y - m2 * point.x)

          Line.new(point, Point.new(x2, y2))
        end
      end

      def point_projection(point)
        pline = perpen_line_via_point(point)
        pline.intersection_points_with(self)
      end
    end
  end
end
