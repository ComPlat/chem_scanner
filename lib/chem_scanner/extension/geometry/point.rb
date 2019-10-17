# frozen_string_literal: true

require "geometry"

module ChemScanner
  # Monkey patch Point class from ruby-geometry
  module Extension
    refine Geometry::Point do
      def euclid_distance_to_polygon(polygon)
        polygon.euclid_distance_to_point(self)
      end

      def distance_to(other)
        Geometry.distance(self, other)
      end
    end
  end
end
