# coding: utf-8
# frozen_string_literal: true

module ChemScanner
  # Util functions for Interpreter
  module Interpreter
    module BoldGroup
      def text_bold_groups(tid)
        all_groups = @alias_info.values.reduce([]) do |arr, infos|
          groups = infos.map { |info| info[:group] }
          arr.concat(groups).uniq
        end

        # In case "** \n", splitting results
        # "[...**], [bold text** ...]"
        # The bold part will be missed for next line
        text = @text_map[tid].markdown.gsub(/ *\*\* *\n/, "\n**")
        lines = text.split("\n")

        bold_arr = []
        group_info = {}

        lines.each do |line|
          bold_info, groups = line_bold_groups(line, all_groups)
          next if bold_info.empty? && groups.empty?

          list_bold = bold_info.reduce([]) do |arr, bold|
            # Remove ":" from "1:", or "2a,b:"
            bold.gsub!(":", "")
            norm = normalize_bold(bold)
            barr = norm.empty? ? bold : norm
            arr.push(barr)
          end

          bold_list = list_bold.flatten.reject { |b| /^[a-z]+$/.match?(b) }
          bold_arr.concat(bold_list)
          group_info.merge!(groups) { |_, old, new| old.concat(new) }
        end

        [bold_arr, group_info]
      end

      def line_bold_groups(line, target_groups)
        bold_regex = /\*\*([^\*\*]*)\*\*/
        bold = line.scan(bold_regex).map(&:first).map(&:strip)
        bold.reject! do |x|
          bold.select { |y| (y.size > x.size) && y.include?(x) }.count > 0
        end

        group_or = "(" + target_groups.join("|") + ")"
        group_regex = /#{group_or} *=/
        res = line.enum_for(:scan, group_regex)
        positions = res.map { Regexp.last_match.begin(0) }

        text_arr = positions.map.with_index do |pos, idx|
          end_pos = idx == (positions.size - 1) ? line.size : positions[idx + 1]
          rtext = line[pos, end_pos - pos]
          regex = /#{group_or} *= *([^\*\*])*(?=$|\n|\.|\z|\Z|\*\*)/
          rtext[regex].strip
        end

        groups = text_arr.reduce({}) do |acc, gtext|
          group_val = gtext.scan(/#{group_or}? ?(?==)/)
          temp = gtext.split("=", 2).last.split(",").map do |t|
            t.strip.gsub(/^-/, "")
          end
          substitutes = temp.compact.uniq.select do |text|
            is_superatom = !ChemScanner.get_superatom(text).empty?
            is_abb = !ChemScanner.get_abbreviation(text).empty?
            is_n_atom = /^\d+$/.match?(text)

            is_superatom || is_abb || is_n_atom
          end
          next acc if group_val.empty? || substitutes.empty?

          info = { group_val.first.first.strip => substitutes }
          acc.merge(info) { |_, cur, new| cur.concat(new).compact.uniq }
        end

        [bold, groups]
      end

      def normalize_bold_groups(bolds, groups)
        normalized = []

        bolds.each_with_index do |bold, idx|
          bgroup = {}
          groups.each { |k, v| bgroup[k] = v[idx] unless v[idx].nil? }
          norm_bolds = bold.split(",").reduce([]) do |arr, b|
            nbold = normalize_bold(b.strip)
            arr.concat(nbold)
          end

          norm_bolds.each do |b|
            normalized.push(bold: b, group: bgroup)
          end
        end

        normalized
      end

      def normalize_bold(bold)
        arr = []

        # 1-3 or 5-10 ... => [1,2,3] or [5,6,7,8,9,10]
        range = extract_range_number(bold)
        return arr.concat(range) unless range.empty?

        # 1a,b or 8a,b,c ... => [1a, 1b] or [8a,8b,8c]
        range = extract_alphabet_number(bold)
        return arr.concat(range) unless range.empty?

        [bold]
      end

      def extract_range_number(text)
        # 3-6 -> 3,4,5,6
        regex = /(\d+)-(\d+)/
        res = text.scan(regex)
        return [] if res.empty?

        bnum, enum = res.first
        return [] if bnum >= enum

        (bnum..enum).to_a
      end

      def extract_alphabet_number(text)
        # 3a,b -> 3a, 3b
        regex = /(\d+)( *[a-z],*)+/
        res = regex =~ text
        return [] if res.nil?

        els = text.split(",")
        anchor = els.first.strip.scan(/\d+/).first
        els[0] = els[0].gsub(anchor, "")

        els.reduce([]) do |arr, char|
          arr.push(anchor + char.strip)
        end
      end

      def group_combinations(rgroup)
        return [] if rgroup.empty?

        combis = []

        key_arr = rgroup.keys
        group_num = key_arr.size

        # keep track of next element in each of the R-groups substitutions
        indices = Array.new(group_num, 0)

        loop do
          combi = {}
          indices.each_with_index.each do |val, idx|
            group = key_arr[idx]
            substitute = rgroup[group][val]

            combi[group] = substitute
          end
          combis.push(combi)

          group_max_idx = group_num - 1

          # rightmost array, has more elements left after the current element
          next_group_idx = group_max_idx
          next_group_size = rgroup[key_arr[next_group_idx]].size
          while next_group_idx >= 0 &&
              (indices[next_group_idx] + 1 >= next_group_size)
            next_group_idx -= 1
            next_group_size = rgroup[key_arr[next_group_idx]].size
          end

          return combis if next_group_idx < 0

          indices[next_group_idx] += 1
          (next_group_idx + 1..group_max_idx).each { |x| indices[x] = 0 }
        end
      end
    end
  end
end
