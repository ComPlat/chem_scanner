# coding: utf-8
# frozen_string_literal: true

module ChemScanner
  module Interpreter
    # Text and group interpreter
    class TextGroupInterpreter
      attr_reader :n_atoms

      rpath = "chem_scanner/interpreter/text_group"
      Gem.find_files("#{rpath}/*.rb").each { |f| require f }

      include Passthrough

      def initialize(scheme)
        @scheme = scheme
        passthrough(scheme)

        @alias_info = {}
      end

      def generate_elements
        generate_indenpendent_molecules

        rtg_map = {}

        @reactions.each do |r|
          rtg = ReactionTextGroup.new(r, @alias_info, @scheme)
          rtg.interpret

          rtg_map[r.arrow_id] = rtg
        end

        # Bringup text-groups information from other reaction if possible
        no_group_rids = rtg_map.select do |_, v|
          !v.alias_groups.empty? && v.text_groups.empty?
        end

        no_group_rids.each do |k, v|
          other_rids = rtg_map.reject do |ok, ov|
            ok == k || ov.text_groups.empty?
          end

          other_rids.each do |_, ov|
            ogroups = ov.text_groups.select { |tg| tg[:bold].nil? }
            ogroups.each do |plain_group|
              v.text_groups.push(plain_group)
            end
          end

          v.text_groups.uniq!(&:keys)
        end

        genr_arr = rtg_map.reduce([]) do |arr, (_, v)|
          arr.concat(v.generate_reaction)
        end

        @reactions.concat(genr_arr)
        @reactions.each do |r|
          %w[reactant reagent product].each do |group|
            group_molecules = r.send("#{group}s")
            group_molecules.each do |m|
              @mol_map[m.id] = m unless @mol_map.key?(m.id)
            end

            r.send("#{group}_ids=", group_molecules.map(&:id))
          end
        end
      end

      def generate_indenpendent_molecules
        independent_ids = @reactions.reduce([]) do |arr, r|
          arr.concat(r.all_ids)
        end

        molecules = @mol_map.reject do |k, _|
          independent_ids.include?(k) || !@alias_info.key?(k)
        end

        molecules.each_value do |m|
          mtg = MoleculeTextGroup.new(m, @alias_info, @scheme)
          mtg.interpret

          genm_arr = mtg.generate_molecule
          genm_arr.each do |genm|
            @mol_map[genm.id] = genm
          end
        end
      end
    end
  end
end
