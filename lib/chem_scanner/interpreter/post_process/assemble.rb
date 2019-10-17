# frozen_string_literal: true

module ChemScanner
  # Interpret the parsed/extracted geometry block
  module Interpreter
    class Scheme
      def assemble_reaction
        @reactions.each do |r|
          %w[reactant reagent product].each do |group|
            group_ids = r.send("#{group}_ids")
            groups = r.send("#{group}s")

            group_ids.each do |id|
              if @text_map.key?(id)
                r.text_ids.push(id)
                next
              end

              if @mol_map.key?(id)
                groups.push(@mol_map[id])
                next
              end

              @mol_group_map.select do |_, mgroup|
                mgroup.molecule_ids.include?(id)
              end.each do |_, mgroup|
                groups.push(mgroup.molecules.first)
              end
            end
          end

          r.arrow = @arrow_map[r.arrow_id]
          r.text_ids.concat(r.arrow.text_arr).uniq!
        end
      end
    end
  end
end
