# frozen_string_literal: true

module ChemScanner
  module Interpreter
    # MoleculeGroup - molecules represented as text
    class MoleculeGroup
      attr_accessor :title
      attr_reader :polygon, :molecules, :molecule_ids

      def initialize(title = nil)
        @title = title
        @molecules = []
        @molecule_ids = []
      end

      def add_fragment(fragment)
        mol = Molecule.new(fragment)
        mol.process
        mol.abbreviation = title.value
        molecules.push(mol)
        @molecule_ids.push(fragment.id)
      end

      def inspect
        (
          "#<MoleculeGroup: id=#{@title.id}, " +
            "text: #{@title}, " +
            "molecule_ids: #{@molecule_ids}, " +
            "molecules: #{@molecules} >"
        )
      end
    end
  end
end
