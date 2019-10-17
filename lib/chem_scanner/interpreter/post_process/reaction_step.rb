# frozen_string_literal: true

module ChemScanner
  module Interpreter
    using Extension

    module ReactionDetection
      def process_reactions_step
        @reactions.each { |r| detect_reaction_step(r) }
      end

      def detect_reaction_step(reaction)
        number_ref = [
          ["1", "2", "3", "4", "5", "6", "7", "8", "9"],
          ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"],
          ["i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix"],
          ["A", "B", "C", "D", "E", "F", "G", "H", "J"],
        ]

        regex_list = [
          /(^|\A)(([1-9a-z]{0,3}) *[)\.] *(.*))($|\z)/i,
          /(^|\A)\((([1-9a-z]{0,3}) *\) *(.*))($|\z)/i,
        ]
        check = false

        list_matched = []
        list_numbered = []
        regex_list.each do |regex|
          next if check

          list_matched = reaction.description.enum_for(:scan, regex).map {
            Regexp.last_match
          }
          list_numbered = list_matched.map { |x| x[3] }
          next if list_numbered.empty?

          number_ref.each do |ref|
            check = true if ref & list_numbered == list_numbered
          end
        end

        return unless check && list_numbered.count >= 2

        flatten_ref = number_ref.flatten
        check_temperature = false
        check_time = false
        list_position = list_matched.map { |x| x.begin(0) }

        list_matched.each_with_index.map do |matched, idx|
          next_pos = list_position[idx + 1] || -1
          next_pos = next_pos.negative? ? next_pos : (next_pos - 1)
          description = reaction.description[list_position[idx]..next_pos]
          text_start_pos = if matched[4].empty?
                             m2 = matched[2]
                             description.index(m2) + m2.size
                           else
                             description.index(matched[4]) || 0
                           end
          description = description[text_start_pos..-1]
          temperature, _, time = extract_reaction_info([description])

          step = ReactionStep.new
          step.temperature = temperature
          step.time = time
          step.description = description
          step.number = (flatten_ref.index(matched[3]) % 9) + 1

          check_time = !time.empty?
          check_temperature = !temperature.empty?

          reaction.reagent_abbs.each do |abb|
            next unless description.include?(abb)

            step.reagents.push(ChemScanner.get_abbreviation(abb))
          end

          reaction.steps.push(step)
        end

        reaction.time = "" if check_time
        reaction.temperature = "" if check_temperature

        # NOTE: tempo tricky assign reagents to empty step
        return if reaction.reagents.count != 1

        empty_steps = reaction.steps.select do |s|
          s.description.empty? || s.description == "\n"
        end
        return if empty_steps.count != 1

        empty_steps.first.reagents.push(reaction.reagents.first.cano_smiles)
      end
    end
  end
end
