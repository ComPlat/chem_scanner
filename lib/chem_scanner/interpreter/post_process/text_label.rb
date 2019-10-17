# coding: utf-8
# frozen_string_literal: true

module ChemScanner
  # Interpreter of extracted/scanned information
  module Interpreter
    using Extension

    module PostProcess
      # text_id could be both on text_map and mol_group_map
      # Text-as-label, e.g. "ligand = ", "amide = "
      def refine_text_label
        @mol_map.select { |_, m| m.text.strip[-1] == "=" }.each do |mid, mol|
          label_text = mol.text.strip.chomp("=").strip
          existed = false

          @reactions.each do |r|
            @arrow_map[r.arrow_id].text_arr.each do |tid|
              text = @text_map[tid]
              next unless text.value.include?(label_text)

              existed = true
            end

            r.reagent_ids.push(mid) unless r.reagent_ids.include?(mid)
          end

          next unless existed

          @reactions.each do |r|
            %w[reactant product].each do |group|
              group_ids = r.send("#{group}_ids")
              group_ids.delete(mid) if group_ids.include?(mid)
            end
          end
        end
      end
    end
  end
end
