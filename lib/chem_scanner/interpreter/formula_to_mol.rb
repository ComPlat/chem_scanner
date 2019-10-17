# coding: utf-8
# frozen_string_literal: true

module ChemScanner
  module Interpreter
    OPEN_MARK = '[\(\[\{]'.freeze
    CLOSE_MARK = '[\)\]\}]'.freeze

    # NOTE: WIP file
    def mol_from_inorganic_formula(text)
      return nil unless text.class == String

      string = text.dup
      iter = string =~ /#{OPEN_MARK}/
      return parse_formula(text) if iter.nil?

      reverse_string = string.reverse
      reverse_iter = reverse_string =~ /#{CLOSE_MARK}/

      math_data = text.match(formula_regex)
    end

    def parse_formula(formula, out_valence = 0)
      # NOTE: sort alphabetically then by length,
      # so that C will not be catched first in Ca
      el_names = ELEMENTS.map { |x| x["name"] }
      els = el_names.sort_by { |a| [a[0], -a.size] }.join("|")
      num = "[1-9]"
      charge = "[-+]"
      return nil unless formula.split(/#{els}|#{num}|#{charge}/).empty?

      el_arr = formula.scan(/(#{els})(#{num}{0,2})/).map do |el, elnum|
        el_info = ELEMENTS.detect { |e| e["name"] == el }
        return nil if el_info.nil? || el_info["valences"][2].first.zero?

        {
          name: el,
          num: elnum.empty? ? 1 : elnum.to_i,
          valences: el_info["valences"][2],
        }
      end
      return nil if el_arr.size == 1

      # el_arr.sort_by! { |el| el[:valences].max }
      fel = el_arr.first
      others = el_arr[1..-1]

      valence_combination = []
      idx_map = others.map { |el| el[:valences].count - 1 }

      fel[:valences].each do |fvalen|
        idx_iter = Array.new(idx_map.size, 0)
        iter = idx_iter.size - 1
        stop = false

        until stop do
          vasum = idx_iter.reduce(0) do |sum, idx|
            el_valence = others[idx][:valences]
            cur_val = idx_iter[idx]
            sum += el_valence[cur_val]
          end

          valence_combination.push(idx_iter) if (vasum + fvalen) == out_valence

          if idx_iter[iter] == idx_map[iter]
            stope = true if iter.zero?
            iter -= 1
          else
            idx_iter[iter] += 1
          end
        end
      end
    end
  end
end
