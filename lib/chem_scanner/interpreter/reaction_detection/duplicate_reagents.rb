# frozen_string_literal: true

module ChemScanner
  # Interpret the parsed/extracted geometry block
  module Interpreter
    using Extension

    module ReactionDetection
      def refine_duplicate_reagents
        delete_info = []

        @reactions.each do |r|
          arrow = @arrow_map[r.arrow_id]
          rremain = @reactions.reject { |other| other.arrow_id == r.arrow_id }

          rremain.each do |other|
            other_rps = other.reactant_ids + other.product_ids
            r.reagent_ids -= other_rps

            dup_ids = r.reagent_ids & other.reagent_ids
            next if dup_ids.empty?

            dup_ids.each do |id|
              obj = @mol_map.key?(id) ? @mol_map[id] : @text_map[id]

              polygon = obj.polygon
              pcenter = polygon.center
              apoint = arrow.contains_point?(pcenter)
              opoint = @arrow_map[other.arrow_id].contains_point?(pcenter)
              next if apoint.nil? || opoint.nil?

              rdist = pcenter.distance_to(apoint)
              odist = pcenter.distance_to(opoint)

              if rdist > odist
                info = OpenStruct.new(rid: r.arrow_id, id: id)
                delete_info.push(info)
              end
            end
          end
        end

        delete_info.each do |info|
          reaction = @reactions.detect { |r| r.arrow_id == info.rid }
          reaction.delete_id(info.id)
        end
      end
    end
  end
end
