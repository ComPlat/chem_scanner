# coding: utf-8
# frozen_string_literal: true

module ChemScanner
  module Interpreter
    using Extension

    ABB_DELIM = Regexp.new('[.·\s,\'"\/\n]')
    ALIAS_GROUP = ["Ar", "X", "Y", "M"].freeze

    GENERATE_RGROUP = 0
    GENERATE_ALIAS_GROUP = 1
    GENERATE_N_ATOM = 2

    def self.alias_group?(text)
      ALIAS_GROUP.include?(text)
    end

    def self.rgroup_atom?(text)
      !(text =~ /R\d+/).nil? || !(text =~ /R */).nil?
    end

    def self.super_atom?(text)
      alias_group?(text) || rgroup_atom?(text)
    end

    module SchemeBase
      def auto_fit_arrow_polygons
        @reactions.each do |reaction|
          arrow = @arrow_map[reaction.arrow_id]

          polygons = []
          reaction.reagent_ids.each do |id|
            obj = @mol_map.key?(id) ? @mol_map[id] : @text_map[id]
            polygons.push(obj.polygon)
          end

          # build "arrow area" based on molecules boundingbox
          arrow.build_polygons_on_polygons(polygons)
        end
      end

      def assemble_molecule_text(mol)
        tarr = mol.text_ids.map { |id| @text_map[id] }.compact
        mol.text = tarr.map(&:non_bold_text).join(" ")

        bold_arr = tarr.map(&:bold_text).reject { |t| t.strip.empty? }
        return unless bold_arr.count == 1

        mol.label = bold_arr.first.gsub(/  +/, " ")
      end

      def add_molecule_substitution_info(mid, info)
        cur_info = @mol_substitutes[mid] || []
        @mol_substitutes[mid] = cur_info.push(info)
      end

      def add_reaction_substitution_info(rid, info)
        cur_info = @reaction_substitutes[rid] || []
        @reaction_substitutes[rid] = cur_info.push(info)
      end
    end
  end
end
