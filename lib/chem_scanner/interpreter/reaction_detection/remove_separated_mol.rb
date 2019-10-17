# frozen_string_literal: true

module ChemScanner
  module Interpreter
    using Extension

    module ReactionDetection
      # (1): A ---> C
      #
      # (2): B ---> D
      #             |
      #             |
      #             V
      #             E
      # Remove C from (2)
      def remove_separated_mol
        dist_gap = 2.0

        @reactions.each do |r|
          arrow = @arrow_map[r.arrow_id]

          %w[reactant_ids product_ids].each do |group|
            rgroup = r.send(group)
            next if rgroup.count < 2

            # Distance map of 1 molecule to arrow
            #   and other molecules within group
            dist_map = distance_molecule_group(rgroup, arrow, group)
            min_dist = dist_map.min_by { |_, value| value }.last

            remove_map = dist_map.select do |k, v|
              dist_check = v > (dist_gap * min_dist)
              next unless dist_check

              in_other = @reactions.select do |other|
                check = (
                  other.arrow_id != r.arrow_id &&
                  other.molecule_ids.include?(k)
                )
                next unless check

                oarrow = @arrow_map[other.arrow_id]
                !arrow.parallel_to?(oarrow)
              end

              in_other.count > 0
            end
            remove_keys = remove_map.keys

            remove_map.each_key do |k|
              mol = @mol_map[k]
              next if mol.nil?

              (rgroup - [k]).each do |id|
                om = @mol_map[id]
                next if om.nil?

                d = Geometry.distance(mol.polygon.center, om.polygon.center)

                remove_keys.push(id) if d < (dist_gap * min_dist)
              end
            end

            rgroup.delete_if { |x| remove_keys.include?(x) }
          end
        end
      end

      def distance_molecule_group(rgroup, arrow, group)
        dist_map = {}
        intersect_points_with_line = ->(id, line) do
          @mol_map[id].polygon.intersection_points_with_line(line)
        end

        if group == "reactant_ids"
          apoint = arrow.tail
          aline = arrow.tail_segment.to_line
        else
          apoint = arrow.head
          aline = arrow.head_segment.to_line
        end

        rgroup.each do |id|
          next unless @mol_map.key?(id)

          # Distance to arrow
          inter_points = intersect_points_with_line.call(id, aline)
          da = 9_999_999
          inter_points.each do |point|
            length = Geometry.distance(apoint, point)
            da = length if length < da
          end

          # Distance to other molecule within group
          dmols = 9_999_999
          (rgroup - [id]).each do |mid|
            other = @mol_map[mid]
            next if other.nil?

            intersect_points_with_line.call(mid, aline).each do |op|
              inter_points.each do |p|
                length = Geometry.distance(p, op)
                dmols = length if length < dmols
              end
            end
          end

          dist_map[id] = [da, dmols].min
        end

        dist_map
      end
    end
  end
end
