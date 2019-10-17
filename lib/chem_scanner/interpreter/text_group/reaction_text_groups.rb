# frozen_string_literal: true

module ChemScanner
  module Interpreter
    require "chem_scanner/interpreter/text_group/bold_groups"

    class ReactionTextGroup
      include BoldGroup

      attr_accessor :alias_groups, :text_groups, :plain_groups, :bold_groups

      def initialize(reaction, alias_info, scheme)
        @reaction = reaction
        @alias_info = alias_info
        @scheme = scheme
        @mol_map = scheme.mol_map
        @text_map = scheme.text_map

        # List of aliases, ex: ["R1", "R2"]
        @alias_groups = []

        # final list if text-groups and label
        @text_groups = []

        @reactants = {}
        @reagents = {}
        @products = {}

        retrieve_alias_groups
      end

      def retrieve_alias_groups
        mids = @reaction.all_ids.select { |id| @mol_map.key?(id) }
        @alias_groups = mids.reduce([]) do |arr, mid|
          next arr unless @alias_info.key?(mid)

          alias_groups = @alias_info[mid].map { |i| i[:group] }.compact
          arr.concat(alias_groups.reject(&:empty?))
        end
      end

      def interpret
        @bold_groups = []
        @plain_groups = {}

        interpret_reaction_text

        %w[reactant reagent product].each { |g| interpret_molecule_group(g) }

        @plain_groups.select! { |k, _| @alias_groups.include?(k) }
        combis = group_combinations(@plain_groups).map { |g| { group: g } }

        @text_groups = @bold_groups + combis
      end

      def interpret_reaction_text
        @reaction.text_ids.each do |tid|
          text = @text_map[tid].markdown.gsub(/ *\*\* *\n/, "\n**")
          lines = text.split("\n")

          lines.each do |line|
            groups = reaction_line_bold_groups(line)
            plain, bolds = groups.partition { |x| x[:bold].nil? }

            @bold_groups.concat(bolds)
            plain.each do |nb|
              @plain_groups.merge!(nb) { |_, old, new| old.concat(new) }
            end
          end
        end
      end

      def interpret_molecule_group(group)
        group_ids = @reaction.send("#{group}_ids")
        gmols = group_ids.select { |i| @mol_map.key?(i) }
        layout = {}

        gmols.each do |mid|
          mol = @mol_map[mid]
          mtg = MoleculeTextGroup.new(mol, @alias_info, @scheme)
          mtg.interpret

          @bold_groups.concat(mtg.bold_groups)
          @plain_groups.merge!(mtg.plain_groups) { |_, o, n| o.concat(n) }

          layout[mid] = mtg
        end

        @bold_groups.reject! { |bg| bg[:group].empty? }
        instance_variable_set("@#{group}s".to_sym, layout) unless layout.empty?
      end

      def generate_reaction
        creactions = generate_from_plain_groups
        bg_reactions = generate_from_bold_groups

        creactions.concat(bg_reactions)
      end

      def generate_from_plain_groups
        genr_arr = []

        combis = @text_groups.reject { |x| x.key?(:bold) }
        combis.each do |combi|
          mids = @alias_info.keys
          rmids = @reaction.all_ids.select do |mid|
            mids.include?(mid) || @mol_map[mid].clone_from
          end
          next if rmids.empty?

          genr = @reaction.clone

          rmids.each do |mid|
            next unless @alias_info.key?(mid)

            mtg = MoleculeTextGroup.new(@mol_map[mid], @alias_info, @scheme)
            mtg.text_groups = [combi]
            gmol = mtg.generate_molecule.first

            genr.replace_molecule(mid, gmol)
          end

          genr_arr.push(genr)
        end

        genr_arr
      end

      def generate_from_bold_groups
        max = max_group_size
        genr_arr = []
        used_groups = []

        (0..max - 1).each do |idx|
          new_r = false
          genr = @reaction.clone

          [@reactants, @reagents, @products].each do |group|
            group.select { |k, _| @alias_info.key?(k) }.each do |k, v|
              next if v.bold_groups.empty?

              mg = v.bold_groups[idx] || v.bold_groups.last
              mg_info = mg

              if mg[:group].empty? && !mg[:bold].nil?
                mgs = @bold_groups.select do |bg|
                  bg[:bold] == mg[:bold] && !bg[:group].empty?
                end
                next unless mgs.count == 1

                mg_info = mg.merge(mgs.first)
              end

              is_used = used_groups.detect do |x|
                (
                  x[:bold] == mg_info[:bold] &&
                  x[:group].to_a == mg_info[:group].to_a
                )
              end
              next unless is_used.nil?

              new_r = true
              mtg = MoleculeTextGroup.new(@mol_map[k], @alias_info, @scheme)
              used_groups.push(mg_info)
              mtg.text_groups = [mg_info]
              gmol = mtg.generate_molecule.first

              genr.replace_molecule(k, gmol)
            end
          end

          genr_arr.push(genr) if new_r
        end

        genr_arr
      end

      def reaction_line_bold_groups(line)
        bold_info, groups = line_bold_groups(line, @alias_groups)

        list_bold = bold_info.reduce([]) do |arr, bold|
          bold.gsub!(":", "")
          norm = normalize_bold(bold)
          barr = norm.empty? ? bold : norm
          arr.push(barr)
        end

        bolds = list_bold.reject(&:empty?)
        return [] if bolds.empty? && groups.empty?

        rgroups = bolds.reduce([]) do |arr, bold|
          arr.concat(normalize_bold_groups(bold, groups))
        end

        bolds.empty? ? [groups] : rgroups
      end

      def max_group_size
        max_group_size = 0

        [@reactants, @reagents, @products].each do |group|
          group.each_value do |v|
            gmax = v.bold_groups.count
            max_group_size = gmax if gmax > max_group_size
          end
        end

        max_group_size
      end

      def inspect
        (
          "#<ReactionTextGroup: id=#{@reaction.arrow_id}, " +
          "alias_groups: #{@alias_groups}, " +
          "plain_groups: #{@plain_groups}, " +
          "bold_groups: #{@bold_groups} >"
        )
      end
    end
  end
end
