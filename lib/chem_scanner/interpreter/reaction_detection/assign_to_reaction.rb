# frozen_string_literal: true

module ChemScanner
  module Interpreter
    using Extension

    require "chem_scanner/interpreter/scheme_base"

    module ReactionDetection
      include ChemScanner::Interpreter::SchemeBase

      def assign_to_reaction
        undetected_molecules = {}

        @arrow_map.each do |key, arrow|
          reaction = Reaction.new
          reaction.arrow_id = key
          undetected = []

          @mol_map.reject { |_, mol| mol.boxed }.each do |kmol, mol|
            mpoly = mol.polygon

            @arrow_map.each_value do |a|
              dist = a.min_distance_to_polygon(mpoly)
              a.build_polygons(mpoly.height + dist)
            end

            group = detect_position(arrow, mpoly)

            case group
            when "reagents" then reaction.reagent_ids.push(kmol)
            when "reactants" then reaction.reactant_ids.push(kmol)
            when "products" then reaction.product_ids.push(kmol)
            else undetected.push(kmol)
            end
          end

          @reactions.push(reaction)
          undetected_molecules[key] = undetected unless undetected.empty?
        end

        # Molecules which are both reagents and reactants/products
        # If reagent -> arrow distance in range, then consider as reagent
        # Otherwise, consider as reactant/product
        @reactions.each do |r|
          reagent_ids = r.reagent_ids
          arrow = @arrow_map[r.arrow_id]

          others = @reactions.reject { |oreact| oreact.arrow_id == r.arrow_id }
          others.each do |o|
            common = reagent_ids & o.reactant_ids
            common += reagent_ids & o.product_ids
            common.each do |cid|
              mol = @mol_map[cid]
              dist = arrow.min_distance_to_polygon(mol.polygon)
              target = dist > 2 ? r : o
              target.delete_id(cid)
            end
          end
        end

        auto_fit_arrow_polygons

        undetected_molecules.each do |rkey, ids|
          reaction = @reactions.detect { |r| r.arrow_id == rkey }
          arrow = @arrow_map[rkey]

          ids.each do |id|
            mol = @mol_map[id]
            mpoly = mol.polygon
            group = detect_position(arrow, mpoly)

            case group
            when "reagents" then reaction.reagent_ids.push(id)
            when "reactants" then reaction.reactant_ids.push(id)
            when "products" then reaction.product_ids.push(id)
            end
          end
        end
      end

      def detect_position(arrow, mol_poly)
        mcenter = mol_poly.center

        check_pos = check_position(mol_poly, arrow)
        return "products" if check_pos && arrow.product_side?(mcenter)

        check_pos = check_position(mol_poly, arrow, false)
        return "reactants" if check_pos && arrow.reactant_side?(mcenter)

        return "reagents" if arrow.polygon_around?(mol_poly)

        nil
      end

      # Check if molecule belong to reaction
      def check_position(mol_poly, arrow, prod_side = true)
        arrow_segment = ->(larrow) do
          prod_side ? larrow.head_segment : larrow.tail_segment
        end

        segment = arrow_segment.call(arrow)
        sline = segment.to_line
        inter = sline.intersects_with_polygon?(mol_poly)
        return false unless inter

        inter_point = sline.intersection_points_with_polygon(mol_poly).first
        inter_seg = Geometry::Segment.new(segment.point2, inter_point)

        @arrow_map.except(arrow.id).each_value do |oarrow|
          other_hseg = oarrow.head_segment
          check_contains = (
            other_hseg.contains_segment?(segment) ||
            segment.contains_segment?(other_hseg)
          )
          next if check_contains

          osegment = arrow_segment.call(oarrow)
          check = osegment.to_line.intersects_with_polygon?(mol_poly) && \
            oarrow.all_intersects_with_segment?(inter_seg)

          return false if check
        end

        true
      end
    end
  end
end
