# frozen_string_literal: true

module ChemScanner
  # ChemDraw related file formats handling
  module ChemDraw
    # Base class for ChemDraw format parser
    require "chem_scanner/chem_draw/node/base_node"

    yaml_path = File.join(__dir__, "yaml")
    CDX_OBJ = YAML.load_file("#{yaml_path}/cdx_objects.yaml")
    CDX_PROPS = YAML.load_file("#{yaml_path}/cdx_props.yaml")
    CDXML_OBJ = YAML.load_file("#{yaml_path}/cdxml_objects.yaml")
    CDXML_PROPS = YAML.load_file("#{yaml_path}/cdxml_props.yaml")
    PROPS_DATA_TYPE = YAML.load_file("#{yaml_path}/props_data_type.yaml")

    class Parser
      Gem.find_files("chem_scanner/chem_draw/node/*.rb").each { |f| require f }
      require "chem_scanner/interpreter/scheme"

      attr_reader :reader, :tempid, :color_table, :font_table,
                  :fragment_map, :fragment_group_map, :geometry_map,
                  :graphic_map, :text_map, :bracket_map,
                  :reactions, :molecules

      def initialize
        # Start a new tempid to avoid duplicate with existed id
        @tempid = 10_000_000

        # Value from ChemDraw file, no OBMol yet
        @fragment_map = ElementMap.new
        @fragment_group_map = ElementMap.new

        @geometry_map = ElementMap.new
        @graphic_map = ElementMap.new

        @text_map = ElementMap.new
        @bracket_map = ElementMap.new

        # Real output
        @reactions = []
        @molecules = []

        # parser type (cdx, cdxml)
        @type = ""
      end

      def read; end

      def get_tempid
        @tempid += 1
        @tempid - 1
      end

      def n_atoms
        @scheme&.n_atoms
      end

      def fragment_as_line
        @scheme&.fragment_as_line
      end

      private

      def parse_object(tag, nid)
        node_name = @type == "cdx" ? CDX_OBJ[tag] : CDXML_OBJ[tag]

        case node_name
        when "Fragment" then build_object(@fragment_map, nid, Fragment)
        when "Text" then build_object(@text_map, nid, Text)
        when "Geometry", "Arrow"
          build_object(@geometry_map, nid, ChemGeometry)
        when "Graphic" then build_object(@graphic_map, nid, Graphic)
        when "BracketedGroup" then build_object(@bracket_map, nid, BracketGroup)
        end
      end

      def build_object(object_map, oid, klass)
        id = object_map.key?(oid) ? get_tempid : oid
        parsed = klass.new(self, @type, id)
        parsed.read
        object_map[parsed.id] = parsed
      end

      def read_colortable(data, type)
        ct = ColorTable.new(type, data)
        ct.read

        ct.table
      end

      def read_fonttable(data, type)
        ft = FontTable.new(type, data)
        ft.read

        ft.table
      end

      def molecule_smiles
        @mol_map.values.map(&:cano_smiles)
      end

      # Rebuild the node list
      #  - Split to new molecule(s)
      #  - Update bond id for Nickname/Fragment
      # rubocop:disable Methods/PerceivedComplexity
      def rebuild_objects_map
        delete_frags = []

        # rubocop:disable Methods/BlockLength
        @fragment_map.each_value do |fragment|
          node_map = {}
          bond_map = {}
          delete_nodes = []

          fragment.node_map.reject { |_, n| n.type.negative? }.each do |nid, node|
            if node.nested_fragment.count > 1
              @fragment_group_map.merge!(fetch_fragment_group(node))
              @text_map.merge!(node.nested_text)
              delete_frags.push(fragment.id)
              delete_nodes.push(nid)

              next
            end

            if node.nested_fragment.count == 1
              if node.type.zero? && node.nested_text.count == 1 && node.warning
                text = node.nested_text.values.first.value
                unless (text =~ /^[OSN]R\d+$/).nil?
                  node.set_type(7)
                  next
                end
              end

              delete_nodes.push(nid)
              _, nfragment = node.nested_fragment.first

              if nfragment.get_external_point.count.zero?
                @fragment_group_map.merge!(fetch_fragment_group(node))
                delete_frags.push(fragment.id)
                @text_map.merge!(node.nested_text)
              else

                delete_nodes.concat(nfragment.get_external_point.keys)
                nnode_map, nbond_map = fetch_node_map(fragment, nfragment, nid)
                node_map.merge!(nnode_map)
                bond_map.merge!(nbond_map)
              end

              next
            end

            frag_text = (
              fragment.node_map.count == 1 &&
              node.nested_text.count.positive? &&
              node.nested_fragment.count.zero?
            )
            if frag_text
              delete_frags.push(fragment.id)
              @text_map.merge!(node.nested_text)
            end
          end

          # NOTE: Same molecule, save node and bond map to merge
          if node_map.count.positive? && bond_map.count.positive?
            fragment.node_map.merge!(node_map)
            fragment.bond_map.merge!(bond_map)
          end

          delete_nodes.each { |id| fragment.node_map.delete(id) }
        end
        # rubocop:enable Methods/BlockLength

        delete_frags.each { |id| @fragment_map.delete(id) }
      end
      # rubocop:enable Methods/PerceivedComplexity

      # External Node handling
      def fetch_node_map(fragment, nested_fragment, nid)
        # NOTE: Currently implement for 1 bond
        ext_ids, internal_ids = nested_fragment.get_internal_nids
        return if ext_ids.count.zero? || internal_ids.count.zero?

        ext_ids.each_with_index do |ext_id, idx|
          _, outer_bond = fragment.bond_has_endpoint(nid)
          outer_id = outer_bond.other_endpoint(nid)
          _, nbond = nested_fragment.bond_has_endpoint(ext_id)

          outer_bond.replace_endpoint(nid, internal_ids[idx])
          nbond.replace_endpoint(ext_id, outer_id)
        end

        nested_fragment.node_map.each_value(&:set_expanded)
        [nested_fragment.node_map, nested_fragment.bond_map]
      end

      def fetch_fragment_group(node)
        fgmap = {}
        group_id, group_title = node.nested_text.first
        fgmap[group_id] = {
          title: group_title,
          fragment_map: node.nested_fragment,
        }

        fgmap
      end

      def to_cml(molecule_only = false)
        objs = molecule_only ? @molecules : @reactions
        cml = ChemScanner::Export::CML.new(objs, molecule_only)
        cml.process
      end
    end
  end
end
