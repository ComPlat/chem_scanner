# frozen_string_literal: true

# Main module
module ChemScanner
  require "ole/storage"

  # Read and Parse DOC
  class Doc
    attr_reader :reactions, :molecules, :cdx_map

    def initialize
      @reactions = []
      @molecules = []
      @cdx_map = {}
    end

    def read(path)
      extract_cdx_data(path).each do |cdx_content|
        cdx = Cdx.new
        cdx.read(cdx_content, false)

        @molecules.concat(cdx.molecules)
        @reactions.concat(cdx.reactions)

        length = cdx_content.length
        uuid = "#{length}#{reactions.count}#{molecules.count}"
        @cdx_map[uuid] = cdx
      end

      true
    end

    def extract_cdx_data(path)
      ole = Ole::Storage.open(path).root["ObjectPool"]

      cdx_arr = []
      ole.children.each do |obj|
        contents = obj["CONTENTS"]
        next if contents.nil?

        content_data = contents.read
        next unless content_data[0, 8] == "VjCD0100"

        cdx_arr.push(content_data)
      end

      cdx_arr
    end

    def to_cml(molecule_only = false)
      objs = molecule_only ? @molecules : @reactions
      cml = ChemScanner::Export::CML.new(objs, molecule_only)
      cml.process
    end
  end
end
