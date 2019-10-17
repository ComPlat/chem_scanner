# coding: utf-8
# frozen_string_literal: true

module ChemScanner
  module Export
    require "chronic_duration"

    class CML
      CML_ATTR = {
        "xmlns" => "http://www.xml-cml.org/schema",
        "xmlns:convention" => "http://www.xml-cml.org/convention",
        "convention" => "convention:molecular",
        "version" => "ChemScanner v0.0.1",
      }.freeze

      def initialize(objects, molecule_only)
        @objects = objects
        @molecule_only = molecule_only
        @output = ""
      end

      def process
        return false unless @objects.class == Array

        builder = Nokogiri::XML::Builder.new do |cml|
          cml.cml(CML_ATTR) {
            @molecule_only ? molecules_cml(cml) : reactions_cml(cml)
          }
        end

        @output = builder.to_xml

        @output
      end

      def molecules_cml(cml)
        @objects.each do |mol|
          cml.parent << molecule_cml(mol)
        end
      end

      def molecule_cml(molecule)
        rw_mol = if molecule.class == OpenStruct
                   RDKitChem::RWMol.mol_from_mol_block(molecule[:mdl])
                 else
                   molecule.rw_mol
                 end
        molecule_cml_from_rw_mol(rw_mol)
      end

      def molecule_cml_from_rw_mol(rw_mol)
        builder = Nokogiri::XML::Builder.new do |cml|
          cml.molecule("spinMultiplicity" => "2") {

            cml.atomArray {
              (0..rw_mol.get_num_atoms - 1).each do |idx|
                rd_atom = rw_mol.get_atom_with_idx(idx)
                pos = rw_mol.get_conformer.get_atom_pos(0)

                cml.atom(
                  id: idx,
                  elementType: rd_atom.get_symbol,
                  hydrogenCount: rd_atom.get_total_num_hs,
                  x3: pos.x,
                  y3: pos.y,
                  z3: 0,
                )
              end
            }
            cml.bondArray {
              (0..rw_mol.get_num_bonds - 1).each do |idx|
                rd_bond = rw_mol.get_bond_with_idx(idx)

                bidx = rd_bond.get_begin_atom_idx
                eidx = rd_bond.get_end_atom_idx
                atom_refs = "#{bidx} #{eidx}"

                cml.bond(
                  atomRefs2: atom_refs,
                  order: rd_bond.get_bond_type_as_double,
                )
              end
            }
          }
        end

        builder.doc.root.to_s
      end

      def mdl_from_smiles(smiles)
        rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)
        rw_mol.mol_to_mol_block(true, -1, false)
      end

      def reactions_cml(cml)
        cml.send("reactionList") {
          @objects.each do |r|
            reaction_attr = {
              "id" => r.arrow_id
            }
            reaction_attr["yield"] = r.yield unless r.yield.empty?
            cml.reaction(reaction_attr) {
              cml.reactantList {
                r.reactants.each do |reactant|
                  cml.reactant {
                    cml.parent << molecule_cml(reactant)
                  }
                end
                r.reagents.each do |reagent|
                  cml.reactant("role" => "reagents") {
                    cml.parent << molecule_cml(reagent)
                  }
                end
                r.reagent_smiles.each do |smi|
                  cml.reactant("role" => "reagents") {
                    mdl = mdl_from_smiles(smi)
                    cml.parent << molecule_cml(OpenStruct.new(mdl: mdl))
                  }
                end
              }
              cml.productList {
                r.products.each do |prod|
                  cml.product {
                    cml.parent << molecule_cml(prod)
                  }
                end
              }

              reaction_condition_cml(cml, r)
              cml.description r.description unless r.description.empty?
            }
          end
        }
      end

      def reaction_condition_cml(cml, reaction)
        no_cond = (
          reaction.temperature.empty? &&
          reaction.time.empty?
        )
        return if no_cond

        temp = nil
        temp_unit = nil
        unless reaction.temperature.empty?
          temp = reaction.temperature.scan(/\d+/).first
          check_f = (
            reaction.temperature.include?("F") ||
            reaction.temperature.include?("℉")
          )
          temp_unit = check_f ? "cml:Fahrenheit" : "cml:Celsius"
        end

        duration = nil
        unless reaction.time.empty?
          time = ChronicDuration.parse(reaction.time)
          duration = ChronicDuration.output(time, :format => :chrono)
        end

        cml.conditionList {
          unless temp.nil? || temp_unit.nil?
            cml.scalar("dictRef" => "cml:temp", "units" => temp_unit) {
              cml.parent << temp
            }
          end

          unless duration.nil?
            cml.scalar("dictRef" => "cml:timeDuration", "units" => "xsd:date") {
              cml.parent << duration
            }
          end
        }
      end
    end
  end
end
