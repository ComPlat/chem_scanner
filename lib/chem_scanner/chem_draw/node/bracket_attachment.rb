# frozen_string_literal: true

module ChemScanner
  module ChemDraw
    # CDX Bracket parser
    class BracketAttachment < BaseNode
      attr_reader :graphic_id

      def parse_node(tag, _id, data)
        ref = @props_ref[tag] || @obj_ref[tag]
        return unless ref == "Bracket_GraphicID"

        @graphic_id = read_value(tag, data)
      end
    end
  end
end
