# coding: utf-8
# frozen_string_literal: true

module ChemScanner
  module Interpreter
    Gem.find_files("chem_scanner/interpreter/*/*.rb").each { |f| require f }

    using Extension

    # General scheme, contains all graphics (molecules, text, arrows ...)
    class Scheme
      attr_reader :mol_map, :text_map, :bracket_map, :reactions,
                  :n_atoms, :fragment_as_line

      include PreProcess
      include ReactionDetection
      include PostProcess

      def initialize(parser)
        fragment_map = parser.fragment_map.map { |k, v| [k, Fragment.new(v)] }
        @fragment_map = fragment_map.to_h
        @fragment_group_map = parser.fragment_group_map

        @geometry_map = parser.geometry_map
        @graphic_map = parser.graphic_map

        @text_map = parser.text_map
        @bracket_map = parser.bracket_map

        @mol_map = ElementMap.new
        @mol_group_map = ElementMap.new

        @arrow_map = ElementMap.new
        # Segment or headless arrow
        @segment_map = ElementMap.new

        @mol_substitutes = {}
        @reaction_substitutes = {}

        @fragment_as_line = 0

        @reactions = []
      end

      def interpret
        pre_process
        reaction_detection
        post_process

        tgi = TextGroupInterpreter.new(self)
        # Detect if molecule has any n-atom, save those infos
        tgi.retrieve_n_atoms_info

        @n_atoms = tgi.n_atoms

        # Retrieve rgroups, alias-groups of molecules
        tgi.retrieve_alias_info

        # - Find R-groups ("R1", "R2", "R", ...)
        # - Find alias-groups ("X", "Y", "Ar", "M")
        # - Detect label set ("2a,b" "3-6" ...)
        # tgi.retrieve_labels_and_groups

        # - Combine corresponding addition info detected molecule/reaction text
        #   e.g., "3: m = 1, R = H"
        # - Interpret previouse retrieved data
        # - Save those infos to generate molecules/reactions later
        # interpret_labels_and_groups

        # Try generate new molecules/reactions
        #   based on R-groups, alias-groups, n-atoms ...
        tgi.generate_elements

        @mol_group_map.each do |_, mgroup|
          mgroup.molecules.each do |m|
            @mol_map[m.id] = m unless @mol_map.key?(m.id)
          end
        end
      end

      def molecules
        @mol_map.values
      end

      private

      def pre_process
        # Retrieve fragments which are covered by a rectangle
        find_fragment_inside_rectangle

        # - Attach detected above to arrow
        # - Try to detect cross arrow ( --//-->  or --X--> )
        #
        # -----|
        #      |
        #      V
        # - Extend arrows if possible
        #
        #      |------>
        #      |
        # -----|
        #      |
        #      |------>
        # - Split extend arrows if possible
        refine_arrow

        extract_fragment_graphic
        refine_molecules
      end

      def reaction_detection
        # Adding molecules based on molecules and arrow position
        assign_to_reaction

        # (1): A ---> C
        #
        # (2): B ---> D
        #             |
        #             |
        #             V
        #             E
        # Remove C from (2)
        #
        # Remove if one molecule is seperated against other in the same group
        # If it is too far, will consider it not a part of the reaction
        remove_separated_mol

        # Following current algorithm, reagents could belongs to multiple
        # reactions. Only take the nearest one
        refine_duplicate_reagents

        # Attach text to molecule or arrow
        # Process molecule label
        assign_text

        # Text can also be reactants/products.
        # Process these ONLY IF text does not belong to any reaction or molecule
        assign_molecule_group

        # NOTE: Handle some specific scenario from here

        # A -> B ->
        # C- > D -> E
        # For this case, we will have an extra implicit reaction: B -> C
        # For now, only deal with this case if all arrows are horizontal
        multi_line_chain_reaction
      end

      def post_process
        # Check if there is any label inside reagents
        # which is not assigned to any molecule
        refine_reagents_label

        # Label usually present a molecule, process those in reagents text
        replace_label_by_molecule

        # Text-as-label, e.g. "ligand = ", "amide = "
        refine_text_label

        refine_text_as_molecule

        # From id => molecule
        assemble_reaction

        # - Extract reaction-related information: temperature, time, yield
        # - Try interpret abbreviations
        @reactions.each { |r| process_reaction_info(r) }

        process_reactions_step
      end
    end
  end
end
