# frozen_string_literal: true

# Main module
module ChemScanner
  require "nokogiri"
  require "chem_scanner/chem_draw/parser"

  # Read and Parse CDXML
  class Cdxml < ChemDraw::Parser
    attr_accessor :version, :reader

    CDXML_DOCTYPE = "http://www.cambridgesoft.com/xml/cdxml.dtd"

    def initialize
      super

      @type = "cdxml"
    end

    def read(file, is_path = true)
      fs = is_path ? File.open(file) : file
      @cdxml = Nokogiri::XML(fs)
      return false if @cdxml.internal_subset.system_id != CDXML_DOCTYPE

      read_global

      @cdxml.xpath("//page").each do |page|
        @reader = page
        read_objects
      end

      rebuild_objects_map

      @scheme = Interpreter::Scheme.new(self)
      @scheme.interpret

      @molecules = @scheme.molecules
      @reactions = @scheme.reactions

      true
    end

    def raw_data
      @cdxml.to_xml
    end

    def read_global
      @version = @cdxml.xpath("//CDXML/@CreationProgram").text.split(" ").last

      ct = @cdxml.xpath("//CDXML/colortable").first
      @color_table = read_colortable(ct, "cdxml")

      ft = @cdxml.xpath("//CDXML/fonttable").first
      @font_table = read_fonttable(ft, "cdxml")
    end

    def read_objects
      nodes = @reader.element_children

      nodes.each do |node|
        @reader = node
        nid = (node.attr("id") || 0).to_i

        if ChemDraw::CDXML_OBJ[node.name] == "Group"
          read_objects
        else
          parse_object(node.name, nid)
        end
      end
    end
  end
end
