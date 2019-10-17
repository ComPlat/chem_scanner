# frozen_string_literal: true

module ChemScanner
  module Interpreter
    # Atom class
    class Atom
      attr_accessor :is_alias, :alias_text, :charge
      attr_reader :type, :ext_type, :warning, :warning_data, :point, :is_polymer

      def initialize(node, rw_mol)
        @rw_mol = rw_mol

        @node = node

        @type = node.type
        @ext_type = node.ext_type
        @atnum = node.atnum
        @num_hydrogens = node.num_hydrogens
        @charge = node.charge
        @iso = node.iso
        @x = node.x || 0
        @y = node.y || 0
        @point = node.point

        @is_alias = node.is_alias
        @alias_text = node.alias_text.strip
        @warning = node.warning
        @warning_data = node.warning_data

        @is_polymer = node.is_polymer
      end

      def process
        # Set default to Carbon
        @atnum.negative? && @atnum = 6
        @rw_mol.add_atom(RDKitChem::Atom.new(@atnum), false)
        rd_atom = @rw_mol.get_last_atom
        @rw_mol.set_atom_bookmark(rd_atom, @node.id)

        @num_hydrogens >= 0 && rd_atom.set_num_explicit_hs(@num_hydrogens)
        rd_atom.set_formal_charge(@charge)
        rd_atom.set_isotope(@iso)
        conf = @rw_mol.get_conformer(0)
        conf.set_atom_pos(rd_atom.get_idx, RDKitChem::Point3D.new(@x, @y, 0))

        process_alias
      end

      def get_rd_atom
        @rw_mol.get_atom_with_bookmark(@node.id)
      end

      def get_idx
        get_rd_atom.get_idx
      end

      def id
        @node.id
      end

      def inspect
        (
          "#<Atom: id=#{@node.id}, " +
            "type: #{@type}, " +
            "external_type: #{@ext_type}, " +
            "atnum: #{@atnum}, " +
            "num_hydrogens: #{@num_hydrogens}, " +
            "charge: #{charge}, " +
            "iso: #{@iso}, " +
            "x: #{@x}, " +
            "y: #{@y}, " +
            "is_alias: #{is_alias}, " +
            "is_polymer: #{is_polymer}, " +
            "alias_text: #{alias_text}, " +
            "warning_data: #{@warning_data}, " +
            "warning: #{@warning} >"
        )
      end

      def clone
        cnode = @node.clone
        clone = self.class.new(cnode, @rw_mol)
        clone.process

        clone
      end

      def set_2d(coord_x, coord_y)
        @x = coord_x
        @y = coord_y

        conf = @rw_mol.get_conformer(0)
        conf.set_atom_pos(get_idx, RDKitChem::Point3D.new(@x, @y, 0))
      end

      def set_formal_charge(charge)
        @charge = charge
        rd_atom = get_rd_atom
        rd_atom.set_formal_charge(charge)
      end

      def set_polymer
        @is_alias = true
        @is_polymer = true
      end

      private

      def process_alias
        alias_groups = ChemScanner::Interpreter::ALIAS_GROUP
        is_alias_group = alias_groups.include?(@alias_text)
        if is_alias_group
          @type = 5
          @is_alias = true
          @warning = false
          @warning_data = ""
        end

        sbase = ChemScanner::Interpreter
        @is_alias ||= begin
          !@alias_text.empty? && sbase.rgroup_atom?(@alias_text) && @type >= 0
        end

        # Polymer handling
        set_polymer if @ext_type === 3

        return unless @is_alias

        rd_atom = get_rd_atom
        rd_atom.set_atomic_num(0)
      end
    end
  end
end
