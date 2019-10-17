# coding: utf-8
# frozen_string_literal: true

module ChemScanner
  # Interpreter of extracted/scanned information
  module Interpreter
    using Extension

    module PostProcess
      def refine_text_as_molecule
        key_to_delete = []

        @text_map.each do |k, text|
          mol = @mol_map.values.detect { |m| m.text_ids.include?(k) }
          next if mol.nil?

          smi = ChemScanner.get_abbreviation(text.value)
          next if smi.empty?

          group_pos = {}
          @reactions.each do |reaction|
            rid = reaction.arrow_id
            arrow = @arrow_map[rid]
            group = detect_position(arrow, text.polygon)
            next if group.nil?

            group_pos[rid] = group
          end

          pos = group_pos.detect { |_, p| p == "reagents" }
          next unless pos.nil?

          pos = group_pos.detect { |_, p| %w[reactants products].include?(p) }
          next if pos.nil?

          puts "group: #{group_pos}"
          key_to_delete.push(k)
          mol.text_ids.delete(k)
          @mol_map[k] = Molecule.new_from_smiles(k, smi)

          pos = group_pos.first
          reaction = @reactions.detect { |r| r.arrow_id == pos[0] }
          group_ids = reaction.send("#{pos[1][0...-1]}_ids")
          group_ids.push(k)
        end

        # Don't need to keep it text_map anymore
        key_to_delete.each { |k| @text_map.delete(k) }
      end
    end
  end
end
