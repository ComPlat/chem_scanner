# frozen_string_literal: true

module ChemScanner
  module Interpreter
    require "chem_scanner/interpreter/text_group/bold_groups"

    class MoleculeTextGroup
      include BoldGroup

      attr_accessor :alias_groups, :text_groups, :plain_groups, :bold_groups

      def initialize(molecule, alias_info, scheme)
        @molecule = molecule
        @alias_info = alias_info
        @mol_map = scheme.mol_map
        @text_map = scheme.text_map

        # List of aliases, ex: ["R1", "R2"]
        @alias_groups = []

        # final list if text-groups and label
        @text_groups = []

        retrieve_alias_groups
      end

      def retrieve_alias_groups
        mid = @molecule.id
        if @alias_info.key?(mid)
          @alias_groups = @alias_info[mid].map { |i| i[:group] }.compact
        end

        @alias_groups.reject!(&:empty?)
      end

      def interpret
        build_molecule_combis
      end

      def build_molecule_combis
        # group list without associated label
        @plain_groups = {}

        # groups with associated label
        @bold_groups = []

        @molecule.text_ids.each do |tid|
          bolds, groups = text_bold_groups(tid)
          bolds.reject!(&:empty?)

          if bolds.empty?
            @plain_groups.merge!(groups) { |_, old, new| old.concat(new) }
          else
            norm_bolds = normalize_bold_groups(bolds, groups)

            @bold_groups.concat(norm_bolds)
          end
        end

        n_atom_groups = plain_groups.reject do |k, _|
          ChemScanner::Interpreter.super_atom?(k)
        end

        combis = if n_atom_groups.empty?
                   group_combinations(plain_groups)
                 else
                   n_atom_combinations(plain_groups)
                 end

        @text_groups = @bold_groups + combis.map { |g| { group: g } }
      end

      def generate_molecule
        malias = @alias_info[@molecule.id]

        generated_molecules = []
        @text_groups.each do |bg|
          cmol = @molecule.clone
          group_val = bg[:group]

          generated_text = []
          malias.each do |ainfo|
            agroup = ainfo[:group]
            val = group_val[agroup]
            next if val.nil?

            if ainfo[:type] == GENERATE_N_ATOM
              next if (val =~ /\d+/).nil? || val.to_i == 1

              cmol.n_atom_transform(ainfo[:aid], val.to_i)
            else
              cmol.group_transform(ainfo[:aid], agroup, val)
            end

            generated_text << "#{agroup} - #{val}"
          end

          cmol.update_output_formats
          bg[:bold].nil? || cmol.label = bg[:bold]

          cmol.text += ". Generated with: " + generated_text.join("; ") unless generated_text.empty?
          @mol_map[cmol.id] = cmol
          generated_molecules.push(cmol)
        end

        generated_molecules
      end

      def n_atom_combinations(group)
        pilot_key = group.keys.first
        group.each do |k, v|
          pilot_key = k if v.count > group[pilot_key].count
        end

        combis = []
        group[pilot_key].each_with_index do |_, idx|
          combi = {}
          group.each do |k, v|
            combi[k] = v[idx] unless v[idx].nil?
          end

          combis.push(combi)
        end

        combis
      end

      def inspect
        (
          "#<MoleculeTextGroup: id=#{@molecule.id}, " +
          "alias_groups: #{@alias_groups}, " +
          "plain_groups: #{@plain_groups}, " +
          "bold_groups: #{@bold_groups} >"
        )
      end
    end
  end
end
