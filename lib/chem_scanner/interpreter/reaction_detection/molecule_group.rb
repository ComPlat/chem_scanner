# frozen_string_literal: true

module ChemScanner
  module Interpreter
    using Extension

    module ReactionDetection
      require "chem_scanner/interpreter/reaction_detection/text_assignment"

      def assign_molecule_group
        all_reagent_ids = @reactions.reduce([]) do |acc, r|
          acc.concat(@arrow_map[r.arrow_id].text_arr)
        end

        auto_fit_arrow_polygons

        @mol_group_map.select do |tid, mgroup|
          (
            !all_reagent_ids.include?(tid) &&
            mgroup.molecules.count == 1 &&
            !mgroup.molecules.first.boxed
          )
        end.each do |mkey, mgroup|
          mol = mgroup.molecules.first
          mmid = mol.fragment.id

          mgroup_pos = {}
          @reactions.each do |reaction|
            rid = reaction.arrow_id
            arrow = @arrow_map[rid]
            group = detect_position(arrow, mgroup.title.polygon)
            next if group.nil?

            mgroup_pos[rid] = group
          end

          pos = mgroup_pos.detect { |_, p| p == "reagents" }
          next unless pos.nil?

          pos = mgroup_pos.detect { |_, p| %w[reactants products].include?(p) }
          next if pos.nil?

          # Don't need to keep it text_map anymore
          mol.text = @text_map.delete(mkey).value unless mgroup_pos.empty?
          mol.text_ids.delete(mkey)
          @mol_map.each_value { |m| m.text_ids.delete(mkey) }

          reaction = @reactions.detect { |r| r.arrow_id == pos[0] }
          group_ids = reaction.send("#{pos[1][0...-1]}_ids")
          group_ids.push(mmid)
        end
      end
    end
  end
end
