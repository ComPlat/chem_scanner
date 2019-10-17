# frozen_string_literal: true

module ChemScanner
  module Interpreter
    using Extension

    # Molecule class
    class Molecule
      require "chem_scanner/interpreter/element/atom"

      attr_accessor :text, :text_ids, :label, :boxed, :details,
                    :clone_from, :abbreviation

      attr_reader :polygon, :rw_mol, :fragment, :is_red, :atom_map,
                  :dash_bonds, :dative_bonds, :cano_smiles, :mdl

      RGB_RED = "FF0000"
      CHEMDRAW_RDKIT_BTYPE_MAP = {
        0 => 0,
        1 => 1,
        2 => 2,
        3 => 3,
        4 => 4,
        5 => 5,
        6 => 6,
        1.5 => 7,
        2.5 => 8,
        3.5 => 9,
        4.5 => 10,
        5.5 => 11,
        "ionic" => 13,
        "hydrogen" => 14,
        "dative" => 17,
      }.freeze

      def initialize(fragment = nil)
        @polygon = fragment.polygon unless fragment.nil?
        @text = ""
        @label = ""
        @mdl = ""
        @cano_smiles = ""
        @abbreviation = ""
        @text_ids = []
        @boxed = fragment.boxed unless fragment.nil?
        @details = OpenStruct.new

        @fragment = fragment

        @atom_bookmark_map = {}
        @atom_map = {}
        @rw_mol = RDKitChem::RWMol.new
        @conf = RDKitChem::Conformer.new
        @rw_mol.add_conf(@conf)

        @bond_map = {}

        @dash_bonds = []
        @dative_bonds = []
      end

      def id
        @fragment.id
      end

      def process
        @fragment.node_map.each do |nid, node|
          atom = Atom.new(node, @rw_mol)
          atom.process

          @atom_map[nid] = atom
        end

        @chiral_possible = false
        @fragment.bond_map.each do |k, bond|
          bid = add_bond(bond)
          next if bid.negative?

          @bond_map[k] = bond
        end

        @rw_mol.detect_atom_stereo_chemistry(@conf) if @chiral_possible

        @rw_mol.clear_single_bond_dir_flags
        @rw_mol.detect_bond_stereo_chemistry(@conf)

        @rw_mol.remove_hs(false, false, false)

        begin
          kekulize
          RDKitChem.sanitize_mol(@rw_mol)
        rescue RuntimeError
        end

        try_expand
        check_red
      end

      def get_atom_bonds(atom_id)
        @bond_map.values.select { |b| b.has_endpoint?(atom_id) }
      end

      def add_bond(bond)
        order = bond.order
        return -1 unless CHEMDRAW_RDKIT_BTYPE_MAP.key?(order)

        begin_id = bond.begin_id
        end_id = bond.end_id
        stereo = bond.stereo

        inverse_direction = [4, 7, 10, 12].include?(stereo)
        begin_id, end_id = end_id, begin_id if inverse_direction

        batom = @atom_map[begin_id]
        eatom = @atom_map[end_id]
        bidx = batom.get_idx
        eidx = eatom.get_idx

        bonds = get_atom_bonds(begin_id) + get_atom_bonds(end_id)
        duplicate = bonds.detect do |b|
          b.has_endpoint?(begin_id) && b.has_endpoint?(end_id)
        end
        return -1 unless duplicate.nil?

        if order == "dative"
          bond.order = 1
          order = 1

          if batom.charge.zero? && eatom.charge.zero?
            batom.set_formal_charge(-1)
            eatom.set_formal_charge(1)
          end

          @dative_bonds.push(bond.id)
        end

        if stereo == 1
          @dash_bonds.push(bond.id)
          return -1
        end

        begin
          rd_bond = RDKitChem::Bond.new(order)
          rd_bond.set_begin_atom_idx(bidx)
          rd_bond.set_end_atom_idx(eidx)
          # bid = @rw_mol.add_bond(bidx, eidx, order)

          # Stereo handling
          sdir = { 3 => 2, 4 => 2, 6 => 1, 7 => 1 }
          if sdir.key?(stereo)
            rd_bond.set_bond_dir(sdir[stereo])
            @chiral_possible = true
          end

          rd_bond.set_owning_mol(@rw_mol)
          bid = @rw_mol.add_bond(rd_bond)

          return bid
        rescue RuntimeError
          return -1
        end
      end

      def kekulize
        RDKitChem.kekulize(@rw_mol)
      end

      def try_expand
        list_ids_with_text = []

        @fragment.node_map.each do |nid, node|
          # Node_Type = 8: AnonymousAlternativeGroup
          next if !node.is_alias || node.type == 8 || node.alias_text.empty? \
                  || node.nested_fragment.count.positive? || !node.warning

          atext = node.alias_text
          list_ids_with_text.push(OpenStruct.new(text: atext, id: nid))
        end

        return if list_ids_with_text.empty?

        try_expand_atoms(list_ids_with_text)
        update_output_formats
      end

      def try_expand_atoms(list_expand)
        ref = RDKitChem::RWMol.new(@rw_mol)

        delete_ids = []
        list_expand.each do |info|
          next try_expand_hydrogen(info.id) if info.text == "H"

          smiles = ChemScanner.get_superatom(info.text)
          next if smiles.empty?

          expand_mol = RDKitChem::RWMol.mol_from_smiles(smiles)

          atom = @atom_map[info.id]
          delete_ids.push(info.id)
          idx = atom.get_idx

          target_bonds = get_atom_bonds(info.id)
          first_expand_idx = @rw_mol.get_num_atoms

          @rw_mol.insert_mol(expand_mol)

          target_bonds.each do |bond|
            other_id = bond.other_endpoint(info.id)
            other_idx = @atom_map[other_id].get_idx

            @rw_mol.remove_bond(other_idx, idx)
            # after combined, first atom should be the target to link with
            @rw_mol.add_bond(other_idx, first_expand_idx, bond.order)
          end

          target_bonds.each { |b| @bond_map.delete(b.id) }
        end

        delete_ids.each do |aid|
          atom = @rw_mol.get_atom_with_bookmark(aid)
          @rw_mol.remove_atom(atom)
          @atom_map.delete(aid)
        end

        # Generate added atom coords
        begin
          @rw_mol.compute_2dcoords(ref)
        rescue RuntimeError
          return
        end
      end

      def try_expand_hydrogen(atom_id)
        target_bonds = get_atom_bonds(atom_id)
        return if target_bonds.count == 2

        target_bond = target_bonds.first
        other = target_bond.other_endpoint(atom_id)
        other_atom = @atom_map[other]
        atom = @atom_map[atom_id]

        @rw_mol.remove_bond(other_atom.get_idx, atom.get_idx)
        @rw_mol.remove_atom(atom.get_idx)

        @atom_map.delete(atom_id)
        @bond_map.delete(target_bond.id)
      end

      def min_distance_to_point(point)
        min = 9_999_999

        @fragment.node_map.values.reject(&:expanded).each do |node|
          next if node.x.nil? || node.y.nil?

          npoint = Geometry::Point.new(node.x, node.y)
          dist = npoint.distance_to(point)
          min = dist if dist < min
        end

        min
      end

      def check_red
        ncolors = @fragment.node_map.values.map(&:color).uniq
        bcolors = @fragment.bond_map.values.map(&:color).uniq

        if ncolors.count != 1 || bcolors.count != 1
          @is_red = false
          return
        end

        ncolor = ncolors.first
        bcolor = bcolors.first

        if ncolor != bcolor
          @is_red = false
          return
        end

        color = @fragment.parser.color_table[ncolor].upcase
        color == RGB_RED
      end

      def get_atom(id)
        @atom_map[id]
      end

      def to_hash
        { id: @fragment.id, smiles: @cano_smiles, label: @label, text: @text }
      end

      def charged_atom_ids
        @atom_map.each_with_object([]) do |(key, atom), ids|
          charge = atom.charge
          next ids if charge.zero?

          ids.push(key)
        end
      end

      def clone
        cloned = self.class.new(@fragment.clone)
        cloned.process
        cloned.update_output_formats

        cloned.clone_from = @clone_from.nil? ? id : @clone_from
        cloned.label = @label
        cloned.text_ids = @text_ids
        cloned.text = @text

        cloned
      end

      def get_cano_smiles
        @rw_mol.mol_to_smiles(true)
      end

      def get_mdl
        @dash_bonds.each do |bid|
          bond = @fragment.bond_map[bid]
          bid = bond.begin_id
          eid = bond.end_id
          bidx = @atom_map[bid].get_idx
          eidx = @atom_map[eid].get_idx

          @rw_mol.add_bond(bidx, eidx, 17)
        end

        mdl = @rw_mol.mol_to_mol_block(true, -1, false)

        @dash_bonds.each do |bid|
          bond = @fragment.bond_map[bid]
          bid = bond.begin_id
          eid = bond.end_id
          bidx = @atom_map[bid].get_idx
          eidx = @atom_map[eid].get_idx

          @rw_mol.remove_bond(bidx, eidx)
        end

        mdl.force_encoding(Encoding::UTF_8)
      end

      def update_output_formats
        @cano_smiles = get_cano_smiles
        @mdl = get_mdl
      end

      def add(other)
        @fragment.add(other.fragment)
        @polygon = fragment.polygon

        @text += " #{other.text}"
        @label = ""
        @label += " #{other.label}" unless other.label.empty?
        @text_ids.concat(other.text_ids)
        @boxed |= other.boxed
        odetails = other.details.marshal_dump
        @details = OpenStruct.new(@details.marshal_dump.merge(odetails))

        @atom_map.merge!(other.atom_map)

        combined = RDKitChem.combine_mols(@rw_mol, other.rw_mol)
        @rw_mol = RDKitChem::RWMol.new(combined)

        @dash_bonds.concat(other.dash_bonds)
        @dative_bonds.concat(other.dative_bonds)
      end

      def n_atom_transform(aid, num)
        return false if num == 1

        bonds = @fragment.bond_map.values.select do |b|
          [b.begin_id, b.end_id].include?(aid)
        end
        return false unless bonds.count == 2

        others = bonds.reduce([]) do |arr, bond|
          arr.concat([bond.begin_id, bond.end_id] - [aid])
        end
        return false unless others.count == 2

        ref_mol = RDKitChem::RWMol.new(@rw_mol)

        target_atom = @atom_map[aid]
        target_idx = target_atom.get_idx

        others.each do |other|
          oidx = @atom_map[other].get_idx
          @rw_mol.remove_bond(target_idx, oidx)
        end

        @rw_mol.remove_atom(target_idx)
        @atom_map.delete(aid)

        added_id = []
        (1..num).each do
          catom = target_atom.clone
          @atom_map[catom.id] = catom
          added_id.push(catom.id)
        end

        others.insert(1, *added_id)
        # for n atoms, need n+1 bonds
        (1..num + 1).each do |i|
          begin_idx = @atom_map[others[i - 1]].get_idx
          end_idx = @atom_map[others[i]].get_idx
          @rw_mol.add_bond(begin_idx, end_idx, 1)
        end

        begin
          @rw_mol.compute_2dcoords(ref_mol)
        rescue RuntimeError
        end

        update_output_formats
      end

      def group_transform(aid, group, value)
        text = @atom_map[aid].alias_text.dup
        return unless text.include?(group)

        text.sub!(group, value)
        info = OpenStruct.new(text: text, id: aid)

        try_expand_atoms([info])
        update_output_formats
      end

      def inspect
        (
          "#<Molecule: id=#{fragment.id}, " +
            "polygon: #{polygon}," +
            "text: #{text}, " +
            "label: #{label}, " +
            "mdl: #{mdl}, " +
            "cano_smiles: #{cano_smiles}, " +
            "text_ids: #{text_ids}, " +
            "boxed: #{boxed}, " +
            "details: #{details}, " +
            "dash_bonds: #{dash_bonds}, " +
            "dative_bonds: #{dative_bonds} >"
        )
      end

      def set_rw_mol(rw_mol)
        @rw_mol = rw_mol
      end

      def set_fragment(fragment)
        @fragment = fragment
      end

      def set_output_formats(smiles, mdl)
        @cano_smiles = smiles
        @mdl = mdl
      end

      def self.new_from_smiles(id, smiles)
        mol = new(nil)
        rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)
        mol.set_rw_mol(rw_mol)

        fragment = OpenStruct.new(id: id)
        mol.set_fragment(fragment)

        mdl = rw_mol.mol_to_mol_block(true, -1, false)
        mol.set_output_formats(smiles, mdl)

        mol
      end
    end
  end
end
