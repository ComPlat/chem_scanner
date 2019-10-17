# coding: utf-8
# frozen_string_literal: true

module ChemScanner
  # Interpreter of extracted/scanned information
  module Interpreter
    using Extension

    JOIN_WORDS = %w[and with plus].freeze

    START_REGEX = '(?<=\s|,|;|\n|\r|\[|\(|\.|\A|^)+'
    ENDING_REGEX = '(?=\s|,|;|\n|\r|\]|\)|\.|\z|$)+'

    DEGREE_REGEX = '((°\s*[CF])|(℃|℉))'
    RANGE_REGEX = "(-|−|–|—|~|to|till|until)"

    module PostProcess
      def process_reaction_info(reaction)
        descs = []
        reaction.text_ids.each do |tid|
          text_obj = @text_map[tid]
          text = text_obj.value
          descs.push(text)

          mgroup = @mol_group_map[tid]
          if mgroup.nil?
            abb_mol = name_to_struct(text)
            reaction.reagent_smiles.concat(abb_mol.values)
            reaction.reagent_abbs.concat(abb_mol.keys)
          else
            mtext = mgroup.title.value

            if mtext == text
              merge_chemdraw_with_predefined(mgroup, reaction)
            else
              descs.push(mtext)
              reaction.reagents.concat(mgroup.molecules)

              abb_mol = name_to_struct(mtext)
              reaction.reagent_smiles.concat(abb_mol.values)
            end
          end
        end

        temperature, ryield, time = extract_reaction_info(descs)
        pyield = extract_product_yield(reaction)

        reaction.temperature = temperature
        reaction.yield = pyield.empty? ? ryield : pyield
        reaction.time = time
        reaction.description = descs.reject { |e| e.to_s.empty? }.join("\n")
      end

      def split_text(text)
        text.split(ABB_DELIM).select { |t| t.length > 1 }
      end

      def name_to_struct(text)
        smis = {}
        remain = []
        text_arr = split_text(text)

        text_arr.each do |t|
          smi = ChemScanner.get_abbreviation(t)

          if smi.empty?
            remain.push(t)
          else
            smis[t] = smi
          end
        end

        unless remain.empty?
          tmp = remain.join(" ")

          ChemScanner.all_abbreviations.keys.select do |key|
            key.include?(" ")
          end.each do |abb|
            next unless tmp.include?(abb)

            tmp.slice!(abb)
            smis[abb] = ChemScanner.get_abbreviation(abb)
          end
        end

        smis
      end

      def merge_chemdraw_with_predefined(mgroup, reaction)
        mtext = mgroup.title.value
        abb_hash = name_to_struct(mtext)

        text_arr = split_text(mtext)
        text_arr.each_with_index do |text, idx|
          abb_smi = abb_hash[text]

          if abb_smi.nil?
            mol = mgroup.molecules[idx]
            reaction.reagents.push(mol) unless mol.nil?
          else
            reaction.reagent_smiles.push(abb_smi)
          end
        end
      end

      def extract_reaction_info(descs)
        ryield = []
        temperatures = []
        times = []

        descs.each do |desc|
          dyield = extract_yield_info(desc)
          ryield.push(dyield) unless dyield.empty?

          temp = extract_temperature(desc)
          temperatures.push(temp) unless temp.empty?

          time = extract_time_info(desc)
          times.push(time) unless time.empty?
        end

        [
          temperatures.join(";"),
          ryield.join(";"),
          times.join(";"),
        ]
      end

      def extract_product_yield(reaction)
        pyields = []

        reaction.products.each do |mol|
          next if mol.text.strip.empty?

          pyield = extract_yield_info(mol.text.strip)
          pyields.push(pyield)
        end

        pyields.join(";")
      end

      def range_number_regex(unit_regex, can_negative)
        sign = can_negative ? "(-|−|–|—)?\\s*" : ""
        real_number = "(\\d+|\\d+\.\\d+)"

        "#{sign}(#{real_number}\\s*#{unit_regex}?\\s*" \
        "#{RANGE_REGEX})?#{real_number}\\s*#{unit_regex}"
      end

      def time_duration_range_regex
        day = "days?|dy|d"
        hour = "hours?|hrs?|h"
        minute = "minutes?|mins?|m"
        second = "seconds?|secs?|s"
        real_number = '(\d+|\d+\.\d+)'

        time_unit = "(#{day}|#{hour}|#{minute}|#{second})"
        time_regex = "#{real_number}\\s*#{time_unit}"
        join_words = JOIN_WORDS.join("|")
        linker_regex = "(#{RANGE_REGEX}|(#{join_words}))"

        %r{
          #{START_REGEX}
          (#{time_regex}?\s*(#{linker_regex}\s*)?(#{real_number}\s*#{time_unit}))
          #{ENDING_REGEX}
        }x
      end

      def extract_yield_info(text)
        yield_regex_str = range_number_regex("%", false)
        yield_regex = %r{
          #{START_REGEX}
          #{yield_regex_str}(?!\s*ee)
          #{ENDING_REGEX}
        }x

        text_regex(text, yield_regex)
      end

      def extract_time_info(text)
        time = []
        text.scan(time_duration_range_regex) { |m| time << m[0] }

        ovn_regex = "overnight|ovn|o/n"
        ovn_regex = %r{
          #{START_REGEX}
          (#{ovn_regex}?)
          #{ENDING_REGEX}
        }xi
        ovn = text_regex(text, ovn_regex)
        time.push("12h ~ 20h") unless ovn.empty?

        time.join(";")
      end

      def extract_temperature(text)
        temp_regex_str = range_number_regex(DEGREE_REGEX, true)
        temperature_regex = %r{
          #{START_REGEX}
          #{temp_regex_str}
          #{ENDING_REGEX}
        }x
        temp = text_regex(text, temperature_regex)

        rt_regex = %r{
          #{START_REGEX}
          r\.?t\.?
          #{ENDING_REGEX}
        }xi
        m = text.match(rt_regex)
        return temp if m.nil? || m[0].empty?

        rt = "20°C ~ 25°C"
        temp.empty? ? rt : "#{temp}; #{rt}"
      end

      def text_regex(text, regex)
        m = text.match(regex)
        return "" if m.nil?

        m[0].strip
      end
    end
  end
end
