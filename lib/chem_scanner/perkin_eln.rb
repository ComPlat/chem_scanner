# frozen_string_literal: true

module ChemScanner
  # Read and Parse ChemDraw ELN XML
  class PerkinEln
    attr_accessor :version, :reactions, :molecules, :scheme_list

    def initialize
      super

      @molecules = []
      @reactions = []
      @scheme_list = []

      @resolved_ids = []
    end

    def read(file, is_path = true)
      fs = is_path ? File.open(file) : file
      xml = Nokogiri::XML(fs)

      infos = []
      sections = xml.xpath("//section")
      sections.each do |section|
        info = do_section(section)
        infos.push(info)
      end

      refine_data(infos)
      true
    end

    def do_section(section)
      section_info = {}
      section_type = section.at_xpath("sectionType")["name"]

      section.xpath("./object").each do |child|
        obj_info = do_object(child)

        if obj_info.key?("Preparation")
          prep = obj_info.delete("Preparation")
          key = "Reaction Conditions"
          section_info[key] = {} unless section_info.key?(key)
          section_info[key]["Preparation"] = prep
        else
          section_info.merge!(obj_info)
        end
      end

      { "type" => section_type, "details" => section_info }
    end

    def do_object(object)
      obj_type = object.at_xpath("field")["name"]
      details = do_object_detail(object)

      obj_details = case obj_type
                    when "Preparation" then details["styledText"]
                    when "Reaction Conditions" then details["propertyInstances"]
                    when "Reaction" then details["chemicalStructure"]
                    else details["tableSection"]
                    end

      { obj_type => obj_details }
    end

    def do_object_detail(object)
      details = {}
      object.element_children.each do |child|
        cname = child.name
        val = case cname
              when "styledText" then child.at_xpath("./text").text
              when "chemicalStructure" then do_cdxml(child.content)
              when "propertyInstances" then do_property_instances(child)
              when "tableSection" then do_table_section(child)
              end

        details[cname] = val unless val.nil?
      end

      details
    end

    def do_property_instances(prop_instances)
      props = {}

      prop_instances.xpath("./propertyInstance").each do |prop|
        pname = prop.at_xpath("property")["name"]
        val = read_value(prop["minValue"], prop["maxValue"], prop["value"])
        props[pname] = val unless val.nil?
      end

      props
    end

    def do_table_section(table)
      infos = []

      tprops = do_table_props(table.xpath("./tableProperty"))
      props = %w[ID parentID].concat(tprops)
      values = do_table_rows(table.xpath("./tableRow"))

      values.each do |rvalue|
        info = {}
        rvalue.each_with_index do |val, idx|
          info[props[idx]] = val
        end

        infos.push(info)
      end

      infos
    end

    def do_table_props(cols)
      props = []
      cols.each do |col|
        pname = col.at_xpath("property")["name"]
        props.push(pname)
      end

      props
    end

    def do_table_rows(rows)
      rows_values = []
      rows.each do |row|
        tags = row.at_xpath("./tags")
        tags = { "ID" => nil, "parentID" => nil } if tags.nil?
        values = row.xpath("./tableCell").map { |x|
          read_value(x["minValue"], x["maxValue"], x["value"])
        }
        rows_values.push([tags["ID"], tags["parentID"]].concat(values))
      end

      rows_values
    end

    def do_cdxml(cdxml)
      cp = Cdxml.new
      cp.read(cdxml, false)

      cp
    end

    def read_value(min, max, val)
      mm = min.nil? && max.nil?
      return nil if mm && val.nil?
      return val if mm

      min == max ? val : `${min} ~ ${max}`
    end

    def refine_data(infos)
      infos.each do |section|
        section_details = section["details"]
        cp = section_details["Reaction"]

        oscheme = OpenStruct.new(
          cdxml: cp,
          molecules: cp.molecules,
          reactions: cp.reactions,
        )
        @scheme_list.push(oscheme)

        @molecules.concat(cp.molecules)
        @reactions.concat(cp.reactions)

        section_details.each do |key, details|
          next if key == "Reaction"

          add_details(key, details)
        end
      end
    end

    def add_details(key, details)
      return if details.nil? || details.empty?

      if details.class == Array
        unresolved = []

        details.each do |detail|
          mol = try_add_molecule_details(key, detail)
          unresolved.push(detail) if mol.nil?
        end

        unresolved.each do |detail|
          mol = try_match_smi_with_mol(detail)
          add_reaction_details(key, detail) if mol.nil?
        end
      else
        add_reaction_details(key, details)
      end
    end

    def try_add_molecule_details(key, detail)
      id_str = detail["ID"]
      if id_str.nil?
        if key == "Solvents"
          return try_add_solvent(detail)
        else
          return add_reaction_details(key, detail)
        end
      end

      id = id_str.to_i
      mol = @molecules.detect { |m| m.id == id }
      return nil if mol.nil?

      @resolved_ids.push(id)

      detail.delete("Chemical Structure")
      mol.details = detail
    end

    def try_add_solvent(detail)
      name = detail["Name"]
      return if name.nil? || name.empty?

      smiles = ChemScanner.get_abbreviation(name)
      return if smiles.empty?

      rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)
      mdl = rw_mol.mol_to_mol_block(true, -1, false)

      mol = OpenStruct.new(
        text: "",
        label: "",
        mdl: mdl,
        cano_smiles: smiles,
        details: detail.merge("Solvent": true),
      )
      @molecules.push(mol)
      @reactions.first.reagents.push(mol)
    end

    def try_match_smi_with_mol(detail)
      return nil if !detail.key?("Name") || detail["Name"].empty?

      name = detail["Name"].gsub(/\[.*\]/, "").strip
      return nil if name.nil? || name.empty?

      smiles = ChemScanner.get_abbreviation(name)
      return if smiles.empty?

      rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)
      cano_smiles = rw_mol.mol_to_smiles(true)
      smiles_arr = cano_smiles.split(".")

      fragments = []
      @molecules.reject { |m| @resolved_ids.include?(m.id) }.each do |m|
        next unless smiles_arr.include?(m.cano_smiles)

        fragments.push(m)
      end
      return nil if fragments.empty? || fragments.size != smiles_arr.size

      mol = fragments.first
      fragments.each do |frag|
        next if frag.id == mol.id

        @molecules.delete_if { |m| frag.id == m.id }
        @reactions.each { |reaction| reaction.delete_molecule_by_id(frag.id) }

        mol.add(frag)
      end
      mol.update_output_formats
      mol.details = detail
      @molecules.push(mol)
    end

    def add_reaction_details(group, detail)
      group = "Reaction Description" if %w[Reactants Products].include?(group)

      reaction = @reactions.last
      reaction.details[group] = [] if reaction.details[group].nil?
      reaction.details[group].push(detail)
    end

    def to_cml(molecule_only = false)
      objs = molecule_only ? @molecules : @reactions
      cml = ChemScanner::Export::CML.new(objs, molecule_only)
      cml.process
    end
  end
end
