# frozen_string_literal: true

module ChemScanner
  module Interpreter
    using Extension

    module PostProcess
      def refine_reagents_label
        @reactions.each do |r|
          added_arr = []

          @arrow_map[r.arrow_id].text_arr.each do |tid|
            text = @text_map[tid]
            bold = text.bold_text
            next if bold.strip.empty?

            mol_id = r.reagent_ids.detect { |id| @mol_map[id].label == bold }
            next unless mol_id.nil?

            min_dist = { key: 0, value: 9_999_999 }
            r.reagent_ids.each do |rid|
              reagent = @mol_map[rid]
              dist = reagent.min_distance_to_point(text.polygon.center)
              min_dist = { key: rid, value: dist } if dist < min_dist[:value]
            end

            if min_dist[:key].positive?
              added_arr.push(text: tid, reagent: min_dist[:key])
            end
          end

          added_arr.each do |added|
            text = @text_map[added[:text]]
            r.text_ids.delete(text.id)
            @arrow_map[r.arrow_id].text_arr.delete(text.id)
            reagent = @mol_map[added[:reagent]]
            reagent.text_ids.push(text.id)
            assemble_molecule_text(reagent)
            # reagent.label = text.bold_text.strip
            # text.remove_bold
          end
        end
      end
    end
  end
end
