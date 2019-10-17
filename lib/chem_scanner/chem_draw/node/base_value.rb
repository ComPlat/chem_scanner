# frozen_string_literal: true

module ChemScanner
  module ChemDraw
    # ChemDraw basic Node
    module BaseValue
      TEXT_ATTRIBUTES = %w[font face size color].freeze
      CDXML_CDX_POINT = (1.0e6 / 65536)
      ARROW_NOGO_CROSS = 2

      CDXML_ARROW_TYPE = {
        # "HalfHead" => 1,
        # "FullHead" => 2,
        "Full" => 2,
        # "Resonance" => 4,
        # "Equilibrium" => 8,
        # "Hollow" => 16,
        # "RetroSynthetic" => 32,
        # "NoGo" => 64,
        # "Dipole" => 128,
      }.freeze

      CDXML_GRAPHIC_TYPE = {
        "Line" => 1,
        "Arc" => 2,
        "Rectangle" => 3,
        "Oval" => 4,
        "Orbital" => 5,
      }.freeze

      CDXML_LINE_TYPE = {
        "Dashed" => 1,
      }.freeze

      CDXML_NODE_TYPE = {
        "Unspecified" => 0,
        "Nickname" => 4,
        "Fragment" => 5,
        "GenericNickname" => 7,
        "AnonymousAlternativeGroup" => 8,
        "ExternalConnectionPoint" => 12,
      }.freeze

      CDXML_ATOM_EXTERNAL_CONNECTION_TYPE = {
        "Unspecified" => 0,
        "Diamond" => 1,
        "Star" => 2,
        "PolymerBead" => 3,
        "Wavy" => 4,
      }.freeze

      CDXML_OVAL_TYPE = {
        "Circle" => 1,
        "Shaded" => 2,
        "Circle Shaded" => 3,
        "Filled" => 4,
        "Dashed" => 8,
        "Bold" => 16,
        "Shadowed" => 32,
      }.freeze

      CDXML_ORBITAL_TYPE = {
        "s" => 0,
        "oval" => 1,
        "lobe" => 2,
        "p" => 3,
        "hybridPlus" => 4,
        "hybridMinus" => 5,
        "dz2Plus" => 6,
        "dz2Minus" => 7,
        "dxy" => 8,
        "sShaded" => 256,
        "ovalShaded" => 257,
        "lobeShaded" => 258,
        "pShaded" => 259,
        "sFilled" => 512,
        "ovalFilled" => 513,
        "lobeFilled" => 514,
        "pFilled" => 515,
        "hybridPlusFilled" => 516,
        "hybridMinusFilled" => 517,
        "dz2PlusFilled" => 518,
        "dz2MinusFilled" => 519,
        "dxyFilled" => 520,
      }.freeze

      def read_type(tag, data, cdxml_type)
        return read_value(tag, data) if @parser_type == "cdx"

        cdxml_type[data.text]
      end

      def read_value(prop_name, data)
        data_type = PROPS_DATA_TYPE[@props_ref[prop_name]]

        unless (/U?INT[8(16)(32)]/ =~ data_type).nil?
          return read_int(data, data_type[0] == "U")
        end

        case data_type
        when "CDXObjectID" then read_int(data, true)
        when "CDXPoint2D" then point_2d(data)
        when "CDXPoint3D" then point_3d(data)
        when "CDXRectangle" then polygon_from_bb(data)
        when "CDXObjectIDArray" then read_ids(data)
        end
      end

      # Get polygon based on bounding box data
      def polygon_from_bb(data)
        btop, left, bbottom, right = read_bounding_box(data)
        top = - btop
        bottom = - bbottom

        points = [
          Geometry::Point.new(left, bottom), Geometry::Point.new(left, top),
          Geometry::Point.new(right, top), Geometry::Point.new(right, bottom)
        ]
        Geometry::Polygon.new(points)
      end

      def read_bounding_box(data)
        if @parser_type == "cdxml"
          left, top, right, bottom = data.text.split(" ").map do |x|
            x.to_f / CDXML_CDX_POINT
          end
        else
          top, left, bottom, right = binary_chunks(data, 4).map do |x|
            read_int(x, false) * 1.0e-6
          end
        end

        [top, left, bottom, right]
      end

      def do_unhandled(tag)
        return if @parser_type == "cdxml"

        return unless (tag & CdxReader::TAG_OBJECT).nonzero?

        loop { break if @parser.reader.read_next.positive? }
      end

      def point_2d(data)
        x = 0
        y = 0

        if @parser_type == "cdx"
          y, x = binary_chunks(data, 4).map { |v| read_int(v, false) * 1.0e-6 }
        elsif @parser_type == "cdxml"
          values = data.text.split(" ")
          x, y = values[0..1].map { |v| v.to_f / CDXML_CDX_POINT }
        end

        [x.round(5), -y.round(5)]
      end

      def point_3d(data)
        x = 0
        y = 0

        if @parser_type == "cdx"
          x, y, = binary_chunks(data, 4).map { |v| read_int(v, false) * 1.0e-6 }
        elsif @parser_type == "cdxml"
          values = data.text.split(" ")
          x, y = values[0..1].map { |v| v.to_f / CDXML_CDX_POINT }
        end

        [x.round(5), -y.round(5)]
      end

      def read_int(data, unsigned)
        return data.text.to_i if @parser_type == "cdxml"

        type = case data.length
               when 1 then "c"
               when 2 then "s"
               when 4 then "l"
               end

        unsigned = unsigned || false
        type = unsigned ? type.upcase : type.downcase
        data.unpack(type)[0]
      end

      def binary_chunks(string, size)
        Array.new(((string.length + size - 1) / size)) do |i|
          string.slice(i * size, size)
        end
      end

      def initialize(parser, parser_type, id)
        super(parser, parser_type, id)
      end

      def cdx_text(data)
        style_runs = read_int(data[0, 2], true)
        text_pos = style_runs * 10 + 2
        plain = data[text_pos, data.size - text_pos]

        styles = cdx_styles(data[2..-1], style_runs)
        if styles.empty?
          return [{ text: plain, font: 3, face: 0, size: 8, color: 0 }]
        end

        plain_arr = plain.dup.split("")

        styled_text = []
        styles.each_with_index do |style, idx|
          t_start = style.delete(:start)
          t_end = (styles[idx + 1] || {}).fetch(:start, plain.length)
          text = plain_arr[t_start..t_end - 1].join("")
          style[:text] = text
          style[:size] = style[:size] / 20
          styled_text.push(style)
        end

        styled_text
      end

      # Output example: [{ start: 1, face: 96 }]
      def cdx_styles(data, runs)
        style_list = (0..runs - 1).each_with_object([]) do |sb, list|
          sr = data[sb * 10, 10]
          attr_list = (["start"] + TEXT_ATTRIBUTES)
          style = attr_list.each_with_object({}).with_index do |(attr, acc), id|
            acc[attr.to_sym] = read_int(sr[id * 2, 2], true)
          end

          list.push(style)
        end

        style_list.sort_by { |x| x[:start] }
      end

      def cdxml_text(data)
        styled_text = []
        data.xpath("./s").each do |s|
          style = TEXT_ATTRIBUTES.each_with_object({}) do |attr, acc|
            acc[attr.to_sym] = s.attr(attr).to_i
            acc[:text] = s.text
          end

          styled_text.push(style)
        end

        styled_text
      end

      def read_ids(data)
        return data.text.split(" ").map(&:to_i) if @parser_type == "cdxml"

        binary_chunks(data, 4).map { |v| read_int(v, false) }
      end
    end
  end
end
