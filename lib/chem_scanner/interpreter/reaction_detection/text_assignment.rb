# frozen_string_literal: true

module ChemScanner
  module Interpreter
    using Extension

    module ReactionDetection
      # Attach/bind text to molecule or arrow
      def assign_text
        tgroup_ids = @mol_group_map.keys
        text_as_mol_ids = []

        @text_map.each do |k, text|
          group = try_detect_label_position(text)
          center = text.polygon.center

          min_mol = nearest_molecule(center)
          min_arrow = nearest_arrow(text)
          arrow = @arrow_map[min_arrow.key]

          if arrow.nil?
            mol_key = min_mol.key

            if group.nil?
              @mol_map[mol_key].text_ids.push(k)
            else
              text_as_mol_ids.push(id: k, mol: mol_key, group: group)
            end

            next
          end

          if min_mol.key.zero?
            arrow.text_arr.push(min_arrow.key)
            next
          end

          to_arrow = (
            min_arrow.value < min_mol.value * 2.5 &&
            text_around_arrow?(arrow, text, min_arrow.value)
          )

          if to_arrow
            arrow.text_arr.push(k)
            next
          end

          # Do not add a molecule-group text to molecule as description
          @mol_map[min_mol.key].text_ids.push(k) unless tgroup_ids.include?(k)
        end

        text_as_mol_ids.each do |tinfo|
          tid = tinfo[:id]
          text = @text_map[tid]
          mid = tinfo[:mol]
          mol = @mol_map.values.detect { |m| m.label == text.bold_text }

          if mol.nil?
            @mol_map[mid].text_ids.push(tid)
          else
            rid = tinfo[:group].keys.first
            group = tinfo[:group][rid]
            reaction = @reactions.detect { |r| r.arrow_id == rid }
            rgroup = reaction.send("#{group[0..-2]}_ids")
            rgroup.push(mol.id).uniq!
          end
        end

        @mol_map.each_value { |mol| assemble_molecule_text(mol) }
      end

      def try_detect_label_position(text)
        return nil if text.value != text.bold_text

        group_pos = {}
        @reactions.each do |reaction|
          rid = reaction.arrow_id
          arrow = @arrow_map[rid]
          group = detect_position(arrow, text.polygon)
          next if group.nil?

          group_pos[rid] = group
        end

        return nil unless group_pos.size == 1

        pos = group_pos.values.first
        return nil unless %w[reactants products].include?(pos)

        group_pos
      end

      def nearest_molecule(point)
        min_mol = OpenStruct.new(key: 0, value: 9_999_999)

        @mol_map.each do |okey, mol|
          dist = mol.min_distance_to_point(point)

          if dist < min_mol.value
            min_mol.key = okey
            min_mol.value = dist
          end
        end

        min_mol
      end

      def nearest_arrow(text)
        min_arrow = OpenStruct.new(key: 0, value: 9_999_999)
        tpoly = text.polygon

        @arrow_map.each do |okey, arrow|
          arrow.segments.each do |segment|
            ppoint = segment.to_line.point_projection(tpoly.center)
            seg_contains = segment.contains_point?(ppoint)
            next unless seg_contains

            dist = segment.distance_to_boundingbox(tpoly)

            if dist < min_arrow.value
              min_arrow.key = okey
              min_arrow.value = dist
            end
          end
        end

        min_arrow
      end

      def text_around_arrow?(arrow, text, dist)
        tpoly = text.polygon
        is_middle = arrow.poly_in_middle?(text.polygon)
        return false unless is_middle

        pheight = [tpoly.width, tpoly.height].max
        arrow.build_polygons(pheight + dist)
        cur_height = arrow.height
        arrow.build_polygons(cur_height)

        tcenter = tpoly.center
        reaction = @reactions.detect { |r| r.arrow_id == arrow.id }
        arrow.segments.each do |aseg|
          pseg = aseg.perpen_segment_via_point(tcenter)
          check_contains = (
            aseg.contains_point?(pseg.point1) ||
            aseg.contains_point?(pseg.point2)
          )
          mol_ids = molecules_intersects_with_segment(pseg)
          mol_ids = mol_ids - reaction.reagent_ids
          return true if mol_ids.empty? && check_contains
        end

        false
      end

      def molecules_intersects_with_segment(segment)
        ids = []
        @mol_map.each do |key, mol|
          ids.push(key) if segment.intersects_with_polygon?(mol.polygon)
        end

        ids
      end
    end
  end
end
