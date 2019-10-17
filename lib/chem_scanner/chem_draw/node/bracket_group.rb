# frozen_string_literal: true

module ChemScanner
  module ChemDraw
    # CDX Bracket parser
    class BracketGroup < BaseNode
      require "chem_scanner/chem_draw/node/bracket_attachment"

      attr_reader :attachments, :object_ids

      def initialize(parser, parser_type, id)
        super(parser, parser_type, id)

        @attachments = []
        @object_ids = []
      end

      def parse_node(tag, id, data)
        if @props_ref[tag] == "BracketedObjects"
          @object_ids = read_value(tag, data)
          return
        end

        return do_unhandled(tag) unless @obj_ref[tag] == "BracketAttachment"

        attachment = BracketAttachment.new(@parser, @parser_type, id)
        attachment.read
        @attachments.push(attachment)
      end
    end
  end
end
