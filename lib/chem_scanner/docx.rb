# frozen_string_literal: true

# Main module
module ChemScanner
  require "open3"
  require "nokogiri"
  require "base64"

  require "chem_scanner/doc"

  # Read and Parse DOCX
  class Docx < Doc
    def initialize
      super
    end

    def read(file)
      dir = Dir.mktmpdir
      unzip_docx(file, dir)

      cdx_infos = retrieve_cdx_info(dir)

      cdx_infos.each do |cdx_info|
        ole_path = cdx_info[:ole_path]
        ole_contents = Ole::Storage.open(ole_path).root["CONTENTS"]
        next if ole_contents.nil?

        cdx_content = ole_contents.read
        next unless cdx_content[0, 8] == "VjCD0100"

        cdx = Cdx.new
        cdx.read(cdx_content, false)

        @molecules.concat(cdx.molecules)
        @reactions.concat(cdx.reactions)

        base_name = File.basename(ole_path, ".bin")
        @cdx_map[base_name] = {
          cdx: cdx,
          img_ext: cdx_info[:img_ext],
          img_b64: cdx_info[:img_b64],
        }
      end

      FileUtils.remove_entry_secure dir
      true
    end

    def unzip_docx(file, dir)
      cmd = "unzip #{file} -d #{dir}"
      Open3.popen3(cmd) { |_, _, _, wait| wait.value }
    end

    def retrieve_cdx_info(dir)
      rels = Nokogiri::XML(File.open("#{dir}/word/_rels/document.xml.rels"))
      rels.remove_namespaces!

      doc = Nokogiri::XML(File.open("#{dir}/word/document.xml"))
      ole_list = doc.xpath('//o:OLEObject[contains(@ProgID, "ChemDraw")]')

      cdx_infos = []
      ole_list.each do |ole_el|
        images = ole_el.parent.xpath(".//v:imagedata")
        next if images.empty?

        imagedata = images.first
        rid = ole_el.attr("r:id")
        img_id = imagedata.attr("r:id")

        ole_rel = rels.at("//Relationship[@Id=\"#{rid}\"]")
        img_rel = rels.at("//Relationship[@Id=\"#{img_id}\"]")
        ole_target = ole_rel.attr("Target")
        img_target = img_rel.attr("Target")

        b64_png = Base64.strict_encode64(IO.binread("#{dir}/word/#{img_target}"))
        cdx_infos.push(
          ole_path: "#{dir}/word/#{ole_target}",
          img_ext: File.extname(img_target),
          img_b64: b64_png,
        )
      end

      cdx_infos
    end
  end
end
