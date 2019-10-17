# frozen_string_literal: true

module ChemScanner
  module Interpreter
    using Extension

    module PreProcess
      def find_fragment_inside_rectangle
        # 3 = Rectangle
        @graphic_map.select do |_, v|
          v.type == 3 && v.bounding_box.area < 100
        end.each do |_, graphic|
          @fragment_map.each_value do |fragment|
            next unless graphic.polygon.contains_polygon?(fragment.polygon)

            fragment.boxed = true
          end

          @fragment_group_map.each do |_, fgroup|
            fmap = fgroup[:fragment_map]
            next unless fmap.values.count == 1

            text = fgroup[:title]
            next unless graphic.polygon.contains_polygon?(text.polygon)

            fragment = fmap.values.first
            fragment.boxed = true
          end
        end
      end

      def extract_fragment_graphic
        @fragment_map.each_value do |fragment|
          next if fragment.graphic_map.empty?

          @graphic_map.merge!(fragment.graphic_map)
        end
      end
    end
  end
end
