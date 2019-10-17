# frozen_string_literal: true

module ChemScanner
  module Interpreter
    using Extension

    N_ATOMS_REGEXES = [
      /\A\( +\) *([nm])\z/,
      /\A\[ +\] *([nm])\z/,
      /\A\{ +\} *([nm])\z/,
    ].freeze

    class TextGroupInterpreter
      def retrieve_n_atoms_info
        @n_atoms = {}

        bracketed_ids = []
        @bracket_map.each_value do |bracket|
          next unless bracket.object_ids.size == 1

          # Bigger bracket could wrap molecule(s) and/or more elements
          # Only process bracket which wrap 1 element id (1 atom)
          bracketed_ids.push(bracket.object_ids.first)
          bracket.attachments.each do |attachment|
            gid = attachment.graphic_id
            next unless @graphic_map.key?(gid)

            graphic = @graphic_map[gid]
            cd_graphic = ChemScanner::ChemDraw::Graphic
            next unless graphic.type == cd_graphic::GRAPHIC_BRACKET_TYPE

            @graphic_map.delete(gid)
          end
        end

        @mol_map.values.each do |m|
          m.text_ids.each do |id|
            text = @text_map[id].value

            N_ATOMS_REGEXES.each do |regex|
              matched = text.match(regex)
              next if matched.nil?

              atom_groups = matched.captures
              next unless atom_groups.count == 1

              bracket_as_text(m, id, atom_groups.first)
            end
          end

          bracket_node(m, bracketed_ids)
        end
      end

      def bracket_as_text(molecule, tid, atom_group)
        text = @text_map[tid]
        box = text.polygon.bounding_box

        aids = []
        molecule.atom_map.each_value do |atom|
          next unless box.contains_point?(atom.point)

          aids.push(atom.id)
        end

        return unless aids.count == 1

        info = { aid: aids.first, group: atom_group }
        molecule.text_ids.delete(tid)
        add_n_atoms_info(molecule.id, info)
      end

      def bracket_node(molecule, bids)
        bracketed_atom_ids = bids & molecule.atom_map.keys
        return if bracketed_atom_ids.empty?

        text_ids = molecule.text_ids.select do |id|
          tval = @text_map[id].value.strip
          /\A *[nm]\z/.match?(tval)
        end

        bracketed_atom_ids.each do |id|
          apoint = molecule.atom_map[id].point

          dist_map = text_ids.map do |tid|
            dist = @text_map[tid].polygon.distance_to_point(apoint)
            { dist: dist, id: tid }
          end
          min_dist_text = dist_map.min_by { |text| text[:dist] }
          next if min_dist_text[:dist] > 0.5

          tid = min_dist_text[:id]
          text = @text_map[tid].value
          info = { aid: id, group: text }
          molecule.text_ids.delete(tid)
          add_n_atoms_info(molecule.id, info)
        end
      end

      def add_n_atoms_info(mid, info)
        cur_info = @n_atoms[mid] || []
        @n_atoms[mid] = cur_info.push(info)
      end
    end
  end
end
