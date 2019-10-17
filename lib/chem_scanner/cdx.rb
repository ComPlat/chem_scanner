# frozen_string_literal: true

# Top module
module ChemScanner
  require "chem_scanner/chem_draw/parser"
  require "chem_scanner/chem_draw/cdx_reader"

  # Class which traverse the tree in CDX binary files and parse
  class Cdx < ChemDraw::Parser
    attr_accessor :version

    CREATIONPROGRAM = 0x0003
    COLORTABLE = 0x0300
    FONTTABLE = 0x0100

    def initialize
      super

      @type = "cdx"
    end

    def read(file, is_path = true)
      @reader = ChemDraw::CdxReader.new(file, is_path)
      return false unless @reader.valid

      read_global
      read_objects until @reader.end?
      rebuild_objects_map

      @scheme = Interpreter::Scheme.new(self)
      @scheme.interpret

      @molecules = @scheme.molecules
      @reactions = @scheme.reactions

      true
    end

    def raw_data
      @reader.bin
    end

    private

    def read_global
      tag = @reader.read_next until tag == CREATIONPROGRAM
      @version = @reader.data.split(" ").last

      tag = @reader.read_next until tag == COLORTABLE
      @color_table = read_colortable(@reader.data, "cdx")

      tag = @reader.read_next until tag == FONTTABLE
      @font_table = read_fonttable(@reader.data, "cdx")
    end

    def read_objects
      tag = @reader.read_next(true)

      while tag.positive?
        cid = @reader.current_id
        parse_object(tag, cid)

        tag = @reader.read_next(true)
      end
    end
  end
end
