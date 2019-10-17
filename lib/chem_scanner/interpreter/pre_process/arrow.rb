# frozen_string_literal: true

module ChemScanner
  module Interpreter
    using Extension

    ESTIMATED_DIST = 0.2

    module PreProcess
      # - Detect cross arrow from line map
      # - Attach "extend" line to arrow
      def refine_arrow
        detect_line_fragment

        # Headless arrow ~ line, part of the real arrow
        segment_keys = @geometry_map.select { |_, g| g.headless }.keys
        segment_keys.each do |k|
          segment = @geometry_map.delete(k)
          tail = Geometry::Point.new(segment.tail[:x], segment.tail[:y])
          head = Geometry::Point.new(segment.head[:x], segment.head[:y])

          @segment_map[k] = Geometry::Segment.new(tail, head)
        end

        segment_keys = @graphic_map.select { |_, g| g.line? }.keys
        segment_keys.each do |k|
          segment = @graphic_map.delete(k)
          tail = Geometry::Point.new(segment.tail[:x], segment.tail[:y])
          head = Geometry::Point.new(segment.head[:x], segment.head[:y])

          @segment_map[k] = Geometry::Segment.new(tail, head)
        end

        #      |
        # ---->|
        #      |
        #      V
        arrow_graphic = @graphic_map.reject { |_, g| g.head.nil? || g.tail.nil? }
        all_arrow = @geometry_map.merge(arrow_graphic)
        all_arrow.each do |key, geometry|
          arrow = Arrow.new(geometry)
          @arrow_map[key] = arrow
          aseg = geometry.segment
          line = aseg.to_line

          all_arrow.except(key).each do |_, other|
            oseg = other.segment
            next unless line.intersects_with_segment?(oseg)

            point = line.intersection_points_with(oseg.to_line)
            next unless oseg.contains_point?(point)

            #     |
            #     |
            # ----|->
            #     |
            #     |
            #     v
            # NOTE: due to manually drawing,
            # the intersection point may not exactly the head of the arrow
            next if Geometry.distance(arrow.head, point) > ESTIMATED_DIST

            # If it intersect with any other geometry
            arrow.change_head(other.head)
          end
        end

        #  \
        # --\-->
        #    \
        # Same effect as "nogo" attritbue
        try_check_cross

        # -----|
        #      |
        #      V
        try_extend_tail

        #      |------>
        #      |
        # -----|
        #      |
        #      |------>
        try_extend_split
      end

      # - Check text within mol
      # - Detect if there are any "arrow" molecule, ( straight C bonds: ----- )
      #   which people drawing to be viewed as an arrow
      def detect_line_fragment
        remove_keys = []

        @fragment_map.each do |key, fragment|
          # Check if user draw a molecule as an "extended" arrow
          next unless fragment.line?

          remove_keys.push(key)
          @fragment_as_line += 1

          nodes = fragment.node_map.values
          is_vertical = nodes.map(&:y).uniq.count == 1
          sorted_atoms = nodes.sort_by { |atom| is_vertical ? atom.y : atom.x }
          segment = Geometry::Segment.new(sorted_atoms.first, sorted_atoms.last)

          @segment_map[key] = segment
        end

        remove_keys.each { |k| @fragment_map.delete(k) }
      end

      # Try to extend base arrow if possible
      def try_extend_tail
        arrow_new_tail = {}
        @segment_map.each do |key, seg|
          @arrow_map.each_value do |arrow|
            dist1 = Geometry.distance(seg.point1, arrow.tail)
            dist2 = Geometry.distance(seg.point2, arrow.tail)
            if dist1 <= dist2
              dist = dist1
              point = seg.point2
            else
              dist = dist2
              point = seg.point1
            end

            next if dist > ESTIMATED_DIST

            arrow_new_tail[arrow.id] = { skey: key, point: point }
          end
        end

        arrow_new_tail.each do |aid, tail_info|
          @segment_map.delete(tail_info[:skey])
          arrow = @arrow_map[aid]
          arrow.change_tail(tail_info[:point])
        end
      end

      def try_extend_split
        arrow_new_split = {}

        @segment_map.each do |key, segment|
          line = segment.to_line

          @arrow_map.each_value do |arrow|
            asegment = arrow.tail_segment
            next unless line.intersects_with_segment?(asegment)

            point = line.intersection_points_with(asegment.to_line)
            dist1 = Geometry.distance(segment.point1, point)
            dist2 = Geometry.distance(segment.point2, point)
            next if [dist1, dist2].min > ESTIMATED_DIST

            tail_point = dist1 < dist2 ? segment.point2 : segment.point1
            arrow_new_split[arrow.id] = {
              key: key,
              point: point,
              tpoint: tail_point,
            }
          end
        end

        arrow_new_split.each do |aid, split_info|
          arrow = @arrow_map[aid]
          arrow.update_tail(split_info[:point])
          arrow.change_tail(split_info[:tpoint])

          @segment_map.delete(split_info[:skey])
        end
      end

      def try_check_cross
        @arrow_map.each_value do |arrow|
          next if arrow.cross

          keys = []
          @segment_map.each do |key, seg|
            arrow.segments.each do |aseg|
              next unless seg.intersects_with?(aseg)

              pintersect = seg.intersection_point_with(aseg)
              check = aseg.contains_point?(pintersect) \
                      && seg.point_in_range(pintersect, 3.0 / 5.0)
              next unless check

              # Add to the "polyline" of arrow
              arrow.add_cross_segment(seg)
              keys.push(key)
            end
          end

          keys.each { |key| @segment_map.delete(key) }
        end
      end
    end
  end
end
