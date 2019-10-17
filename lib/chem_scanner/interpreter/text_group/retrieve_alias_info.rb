# coding: utf-8
# frozen_string_literal: true

module ChemScanner
  module Interpreter
    # Text and group interpreter
    class TextGroupInterpreter
      def retrieve_alias_info
        @alias_info = {}

        interpreter = ChemScanner::Interpreter

        @mol_map.each_value do |molecule|
          atoms = molecule.atom_map.values.select(&:is_alias)
          mid = molecule.id

          atoms.each do |atom|
            text = atom.alias_text
            is_alias_group = interpreter.alias_group?(text)

            next unless is_alias_group || interpreter.rgroup_atom?(text)

            type = is_alias_group ? GENERATE_ALIAS_GROUP : GENERATE_RGROUP
            # Extract only R-group, NOT "OR2", "SR1" ...
            group = is_alias_group ? text : text.scan(/(R\d+|R *)/).last.last

            info = { group: group, aid: atom.id, type: type }
            cur_info = @alias_info[mid] || []
            @alias_info[mid] = cur_info.push(info)
          end
        end

        @n_atoms.each do |mid, n_atom_info|
          info = n_atom_info.map { |ainfo| ainfo.merge(type: GENERATE_N_ATOM) }
          cur_info = @alias_info[mid] || []
          @alias_info[mid] = cur_info.concat(info)
        end
      end
    end
  end
end
