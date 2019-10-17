# frozen_string_literal: true

module ChemScanner
  module Interpreter
    # Reaction
    class Reaction
      attr_accessor :reactant_ids, :reagent_ids, :product_ids,
                    :text_ids, :arrow_id, :arrow,
                    :reactants, :products, :reagents,
                    :reagent_smiles, :reagent_abbs,
                    :description, :temperature, :yield, :time,
                    :steps, :details, :clone_from

      def initialize
        @arrow = nil

        @reactant_ids = []
        @reagent_ids = []
        @product_ids = []
        @text_ids = []

        @reactants = []
        @reagents = []
        @products = []
        @reagent_smiles = []
        @reagent_abbs = []

        @description = ""
        @temperature = ""
        @yield = ""
        @time = ""
        @details = OpenStruct.new

        @steps = []
      end

      def reaction_smiles
        reactant_smiles = @reactants.map(&:cano_smiles).join(".")
        product_smiles = @products.map(&:cano_smiles).join(".")

        reagent_smiles = @reagents.map(&:cano_smiles).compact
        reagent_smiles = reagent_smiles.concat(@reagent_smiles).join(".")

        "#{reactant_smiles}>#{reagent_smiles}>#{product_smiles}"
      end

      def reactant_molfiles
        @reactants.map { |r| r[:mdl] }
      end

      def reagent_molfiles
        @reagents.map { |r| r[:mdl] }
      end

      def product_molfiles
        @products.map { |r| r[:mdl] }
      end

      def debug_print
        "reaction #{@arrow_id}: "\
        "#{reactant_ids} > #{reagent_ids} > #{product_ids}"
      end

      def debug_print_smiles
        "reaction #{@arrow_id}: "\
        "#{reactant_ids} - #{reagent_ids} - #{product_ids}: #{reaction_smiles}"
      end

      def molecule_ids
        @reactant_ids + @product_ids
      end

      def all_ids
        @reagent_ids + molecule_ids
      end

      def delete_id(id)
        [@reactant_ids, @reagent_ids, @product_ids].each do |group|
          group.delete(id) if group.include?(id)
        end
      end

      def replace_id(old_id, new_id)
        [@reactant_ids, @reagent_ids, @product_ids].each do |group|
          next unless group.include?(old_id)

          group.delete(old_id)
          group.push(new_id)
        end
      end

      def replace_molecule(old_id, new_mol)
        oid = old_id

        [@reactants, @reagents, @products].each do |group|
          idx = group.index { |m| [m.id, m.clone_from].include?(old_id) }
          next if idx.nil?

          m = group[idx]
          oid = m.clone_from unless m.clone_from.nil?
          group[idx] = new_mol
        end

        replace_id(oid, new_mol.id)
      end

      def delete_molecule_by_id(id)
        [@reactants, @reagents, @products].each do |group|
          group.delete_if { |mol| mol.id == id }
        end
      end

      def status
        return "Failed" if @arrow.cross
        return "Planned" if @arrow.line_type == 1

        return "Failed" unless @products.detect(&:check_red).nil?

        "Succesful"
      end

      def clone
        cloned = self.class.new
        unless @arrow.nil?
          cloned.arrow_id = @arrow.get_tempid
          cloned.arrow = @arrow.clone
        end

        %w[reactant reagent product].each do |group|
          cloned_groups = cloned.send("#{group}s")
          groups = instance_variable_get("@#{group}s")

          groups.each { |m| cloned_groups.push(m.clone) }
          cloned.send("#{group}_ids=", cloned_groups.map(&:id))
        end

        cloned.reagent_smiles = @reagent_smiles.dup

        cloned.description = @description.dup
        cloned.temperature = @temperature.dup
        cloned.yield = @yield.dup
        cloned.time = @time.dup
        cloned.details = @details.dup

        cloned.clone_from = @clone_from.nil? ? arrow_id : @clone_from

        cloned
      end

      def to_hash
        {
          id: arrow_id,
          reactants: @reactants.sort_by(&:cano_smiles).map(&:to_hash),
          reagents: @reagents.sort_by(&:cano_smiles).map(&:to_hash),
          products: @products.sort_by(&:cano_smiles).map(&:to_hash),
          steps: @steps.map(&:to_hash),
          reagent_smiles: reagent_smiles.sort,
          description: @description,
          temperature: @temperature,
          yield: @yield,
          time: @time,
          details: @details.to_h,
        }
      end

      def inspect
        (
          "#<Reaction: id=#{@arrow.id}, " +
          "reactant_ids=#{@reactant_ids}, " +
          "reagent_ids=#{@reagent_ids}, " +
          "product_ids=#{@product_ids}, " +
          "text_ids=#{@text_ids}, " +
          "reactants=#{@reactants}, " +
          "reagents=#{@reagents}, " +
          "products=#{@products}, " +
          "reagent_smiles=#{@reagent_smiles}, " +
          "description=#{@description}, " +
          "temperature=#{@temperature}, " +
          "yield=#{@yield}, " +
          "time=#{@time}, " +
          "details=#{@details} >"
        )
      end
    end
  end
end
