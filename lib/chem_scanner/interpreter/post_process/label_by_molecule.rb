# frozen_string_literal: true

module ChemScanner
  module Interpreter
    using Extension

    module PostProcess
      def replace_label_by_molecule
        @reactions.each do |r|
          @arrow_map[r.arrow_id].text_arr.each do |tid|
            text = @text_map[tid]

            bolds = text.bold_text.strip.split(ABB_DELIM).reject(&:empty?)
            bolds.each do |bold|
              mol = @mol_map.detect { |_, m| m.label == bold }
              next if mol.nil?

              mid = mol[0]
              r.reagent_ids.push(mid) unless r.reagent_ids.include?(mid)
            end

            non_bolds = text.non_bold_text.strip.split(ABB_DELIM)
            non_bolds.reject(&:empty?).each do |plain|
              next if plain.length < 3 || !(plain =~ /eq(uiv)?\.?/).nil?

              mol = @mol_map.detect { |_, m| m.text.strip == plain.strip }
              next if mol.nil?

              mid = mol[0]
              r.reagent_ids.push(mid) unless r.reagent_ids.include?(mid)
            end
          end
        end
      end
    end
  end
end
