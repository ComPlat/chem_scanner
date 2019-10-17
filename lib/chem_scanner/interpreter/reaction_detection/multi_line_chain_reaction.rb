# frozen_string_literal: true

module ChemScanner
  module Interpreter
    using Extension

    module ReactionDetection
      def multi_line_chain_reaction
        return if check_reaction_orderring

        rarray = @reactions.select do |r|
          r.reactant_ids.count.zero? || r.product_ids.count.zero?
        end

        rcount = rarray.count
        return if rcount.zero?

        auto_fit_arrow_polygons

        sorted_akey = sort_arrow_map

        get_reaction = ->(id) { @reactions.detect { |r| r.arrow_id == id } }

        rarray.each do |reaction|
          rkey = sorted_akey.find_index do |key_arr|
            key_arr.include?(reaction.arrow_id)
          end
          next if rkey.nil?

          if reaction.reactant_ids.count.zero?
            other_ids = sorted_akey[rkey - 1]
            next if other_ids.nil?

            other_id = other_ids.last
            other = get_reaction.call(other_id)
            reaction.reactant_ids.concat(other.product_ids)
          else
            other_ids = sorted_akey[rkey + 1]
            next if other_ids.nil?

            other_id = other_ids.first
            other = get_reaction.call(other_id)
            reaction.product_ids.concat(other.reactant_ids)
          end
        end
      end

      def check_reaction_orderring
        return true if @arrow_map.count < 2

        @arrow_map.each_value do |arrow|
          return true if arrow.middle_points.count > 0
          return true unless arrow.head_segment.to_line.horizontal?
        end

        false
      end

      def sort_arrow_map
        sorted_arr = []
        arrow_keys = @arrow_map.keys

        while !arrow_keys.empty?
          arrow = @arrow_map[arrow_keys.first]
          aheight = arrow.height
          min_height = arrow.head.y - aheight
          max_height = arrow.head.y + aheight

          akeys = arrow_keys.select do |ak|
            y_head = @arrow_map[ak].head.y
            y_head >= min_height && y_head <= max_height
          end

          sorted_arr.push(akeys)
          arrow_keys = arrow_keys - akeys
        end

        sorted_arr.map! { |arr| arr.sort_by! { |id| @arrow_map[id].head.x } }
        sorted_arr.sort_by! { |arr| - @arrow_map[arr.first].head.y }

        sorted_arr
      end
    end
  end
end
