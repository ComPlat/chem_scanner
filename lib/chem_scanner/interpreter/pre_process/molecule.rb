# frozen_string_literal: true

module ChemScanner
  module Interpreter
    using Extension

    module PreProcess
      def refine_molecules
        process_orbital_as_polymer
        fragment_to_molecules
        populate_molecule_info

        assemble_ionic_molecule
      end

      def process_orbital_as_polymer
        @graphic_map.each_value do |graphic|
          next unless graphic.orbital_type == 256 && graphic.oval_type == 3

          gpoly = graphic.polygon
          next if gpoly.nil?

          @fragment_map.each_value do |fragment|
            fragment.node_map.each_value do |node|
              next unless gpoly.contains?(node.point)

              node.set_is_polymer
              fragment.polygon = fragment.polygon.merge_polygon(gpoly)
            end
          end
        end
      end

      def fragment_to_molecules
        @fragment_map.each do |k, fragment|
          next if fragment.node_map.count.zero?

          mol = Molecule.new(fragment)
          mol.process
          @mol_map[k] = mol
        end

        @fragment_group_map.each do |k, fgroup|
          mgroup = MoleculeGroup.new
          mgroup.title = fgroup[:title]

          fgroup[:fragment_map].each do |_, fragment|
            # NOTE: nested fragment should not contain any special type.
            # For instance, there are some cases that
            # DMF is implicitly converted to C-C-C with nickname D-M-F
            node_type = fragment.node_map.detect { |_, n| n.type.positive? }
            mgroup.add_fragment(fragment) if node_type.nil?
          end

          @mol_group_map[k] = mgroup
        end
      end

      def populate_molecule_info
        list_mol = @mol_map.values
        list_mol_group = @mol_group_map.values.reduce([]) do |acc, mgroup|
          acc.concat(mgroup.molecules)
        end

        (list_mol + list_mol_group).each(&:update_output_formats)
      end

      def assemble_ionic_molecule
        charged_mol = @mol_map.each_with_object([]) do |(k, mol), arr|
          charged_ids = mol.charged_atom_ids
          next arr unless charged_ids.size == 1

          aid = charged_ids.first
          charge = mol.atom_map[aid].charge
          arr.push(mol: mol, aid: aid, charge: charge, mid: k)
        end

        charged_group = @mol_group_map.each_with_object([]) do |(k, group), arr|
          next arr unless group.molecules.count == 1

          mol = group.molecules.first
          charged_ids = mol.charged_atom_ids
          next arr unless charged_ids.count == 1

          aid = charged_ids.first
          charge = mol.atom_map[aid].charge
          arr.push(mol: mol, aid: aid, charge: charge, mid: k)
        end

        list_mol = charged_mol.concat(charged_group)
        grouped = {}
        list_mol.each do |charged_info|
          mol = charged_info[:mol]
          charge = charged_info[:charge]
          center = mol.polygon.bounding_box.center

          others = list_mol.select { |ocharged| ocharged[:charge] == -charge }
          opposite_mol = others.each_with_object(dist: 99999) do |minfo, obj|
            ocenter = minfo[:mol].polygon.bounding_box.center
            dist = Geometry.distance(center, ocenter)

            if dist < obj[:dist]
              obj[:dist] = dist
              obj.merge!(mol: minfo[:mol], mid: minfo[:mid])
            end
          end
          # Estimated value, could change later
          next if opposite_mol[:mol].nil? || opposite_mol[:dist] > 4

          mid = charged_info[:mid]
          next if grouped.key?(mid) || grouped.value?(mid)

          grouped[mid] = opposite_mol[:mid]
        end

        # { a1 => b, a2 => b, a3 => c } then remove both a1 and a2
        values = []
        dup_hash = {}
        grouped.each do |key, okey|
          values.push(okey) unless values.include?(okey)
          dup_hash[okey] = (dup_hash[okey] || []).push(key)
        end
        dup_keys = dup_hash.values.select { |x| x.size > 1 }.flatten
        grouped.delete_if { |k, _| dup_keys.include?(k) }

        grouped.each do |key, okey|
          get_mol = lambda do |id|
            if @mol_map.key?(id)
              @mol_map[id]
            else
              @mol_group_map[id].molecules.first
            end
          end

          mol = get_mol.call(key)
          omol = get_mol.call(okey)

          mol.add(omol)
          mol.update_output_formats
          @mol_map.delete(okey)
          mgid = @mol_group_map.delete(okey)
          next if mgid.nil?

          tid = mgid.title.id
          @text_map.delete(tid)
        end
      end
    end
  end
end
