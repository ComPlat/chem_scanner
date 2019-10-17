# coding: utf-8
# frozen_string_literal: true

module ChemScanner
  module ChemDraw
    # Text parser
    class Text < BaseNode
      attr_accessor :warning, :warning_data, :x, :y, :styled_text, :value,
                    :center, :polygon, :bold_text, :non_bold_text

      GREEK_CHARS = {
        "A" => "Α",
        "a" => "α",
        "B" => "Β",
        "b" => "β",
        "G" => "Γ",
        "g" => "γ",
        "D" => "Δ",
        "d" => "δ",
        "E" => "Ε",
        "e" => "ε",
        "Z" => "Ζ",
        "z" => "ζ",
        "H" => "Η",
        "h" => "η",
        "Q" => "Θ",
        "q" => "θ",
        "I" => "Ι",
        "i" => "ι",
        "K" => "Κ",
        "k" => "κ",
        "L" => "Λ",
        "l" => "λ",
        "M" => "Μ",
        "m" => "μ",
        "N" => "Ν",
        "n" => "ν",
        "C" => "Ξ",
        "c" => "ξ",
        "O" => "Ο",
        "o" => "ο",
        "P" => "Π",
        "p" => "π",
        "R" => "Ρ",
        "r" => "ρ",
        "S" => "Σ",
        "s" => "σ",
        "T" => "Τ",
        "t" => "τ",
        "U" => "Υ",
        "u" => "υ",
        "F" => "Φ",
        "f" => "φ",
        "X" => "Χ",
        "x" => "χ",
        "Y" => "Ψ",
        "y" => "ψ",
        "W" => "Ω",
        "w" => "ω",
      }.freeze

      BOLD_VAL = 0x01
      FONT_KEY = "face"
      COLOR_KEY = "color"

      def initialize(parser, parser_type, id, is_alias = false)
        super(parser, parser_type, id)

        @warning = false
        @is_alias = is_alias

        @bold_text = ""
        @value = ""
      end

      def parse_node(tag, _id, data)
        # NOTE: CDXML text does not have tag
        # "Text" below only happens for CDX
        case @props_ref[tag]
        when "Text" then @styled_text = cdx_text(data)
        when "2DPosition" then @x, @y = read_value(tag, data)
        when "BoundingBox" then @polygon = read_value(tag, data)
        when "ChemicalWarning"
          @warning = true
          @warning_data = data
        else do_unhandled(tag)
        end
      end

      def pre_parse_node
        return if @parser_type == "cdx"

        @styled_text = cdxml_text(@parser.reader)
      end

      def post_parse_node
        process_style
        retrieve_bold_text

        @center = Geometry::Point.new(@x, @y)
      end

      def remove_bold
        @styled_text.delete_if { |s| (s[:face] & 1) == 1 }
        process_style
      end

      def markdown
        @styled_text.reduce("") do |md, style|
          md += style[:bold] ? "**#{style[:text]}**" : style[:text]
          md
        end
      end

      def bolded_styles
        @styled_text.select { |s| s[:bold] }
      end

      private

      def process_style
        pos_cur = 0
        @styled_text.each do |style|
          style[:text] = to_unicode(style[:text])
          style[:text].gsub!(/\r\n?/, "\n")

          style[:position] = pos_cur
          tlength = style[:text].size
          style[:length] = tlength
          pos_cur += tlength

          fidx = @parser.font_table.find_index { |f| f[:id] == style[:font] }
          next if fidx.nil?

          font = @parser.font_table[fidx]
          if font[:name] == "Symbol" && style[:face] & 1 != 1
            t = style[:text].gsub(Regexp.union(GREEK_CHARS.keys), GREEK_CHARS)
            style[:text] = t + " "
          end

          # User use superscript "_" as minus
          style[:text] = "-" if style[:face] == 64 && style[:text] == "_"
          style[:text] = style[:text].gsub("–", "-")

          style[:bold] = (style[:face] & 1) == 1
        end

        # If "3-6" bold, "-" is originally not BOLD. Same for bolded "2a,b"
        # Set bold for single "middle" character
        set_special_bold

        # Merge previous continuous bold text
        merge_bold
      end

      def set_special_bold
        return if @styled_text.count < 2

        bold_ids = []
        @styled_text.each_with_index do |style, idx|
          next unless style[:bold]

          prev_idx = bold_ids.last
          bold_ids.push(idx)
          next if idx.zero?

          prev = @styled_text[idx - 1]
          check = (
            style[:position] == (prev[:position] + prev[:length]) &&
            prev[:text].strip.length == 1 &&
            prev_idx == idx - 2
          )
          next unless check

          prev[:bold] = true
        end
      end

      def merge_bold
        bold_ids = @styled_text.each_with_index.reduce([]) do |arr, (s, idx)|
          arr.push(idx) if s[:bold]

          arr
        end
        return if bold_ids.empty?

        consecutive = [[bold_ids.last]]
        bold_ids.reverse[1..-1].each do |idx|
          sub_arr = consecutive.last

          if sub_arr.last == idx + 1
            sub_arr.push(idx)
          else
            consecutive.push([idx])
          end
        end
        consecutive.reject! { |arr| arr.count == 1 }

        consecutive.each do |ids|
          ids[0..-2].each do |idx|
            @styled_text[idx - 1][:text] += @styled_text[idx][:text]
            @styled_text.delete_at(idx)
          end
        end
      end

      def to_unicode(text)
        return text if text.encoding == Encoding::UTF_8

        text.force_encoding(Encoding::CP1252)
        text.encode(
          Encoding::UTF_8,
          invalid: :replace,
          undef: :replace,
          replace: "??",
        )
      end

      def retrieve_bold_text
        bold_arr, non_bold_arr = @styled_text.partition { |s| s[:bold] }
        @bold_text = bold_arr.map { |x| x[:text] }.join(" ")
        @bold_text.gsub!(/[,:\.] *$/, "")
        @non_bold_text = non_bold_arr.map { |x| x[:text] }.join("")
        @value = @styled_text.reduce("") { |mem, obj| "#{mem}#{obj[:text]}" }

        # NOTE: Replace U+2219 to U+00B7
        @bold_text = @bold_text.strip.gsub(/\r|\r\n/, "\n").gsub("∙", "·")
        @non_bold_text = @non_bold_text.strip.
          gsub(/\r|\r\n/, "\n").gsub("∙", "·")
        @value = @value.strip.gsub(/\r|\r\n/, "\n").gsub("∙", "·")
      end

      def inspect
        (
          "#<Text: id=#{@id}, " +
            "bold: #{@bold_text}, " +
            "value: #{@value} >"
        )
      end
    end
  end
end
