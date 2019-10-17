require "yaml"
require "rdkit_chem"
require "ostruct"
require "forwardable"

# ChemScanner main module
module ChemScanner
  (
    Gem.find_files("chem_scanner/extension/*/*.rb") +
    Gem.find_files("chem_scanner/extension/*.rb") +
    Gem.find_files("chem_scanner/configuration/*.rb")
  ).each { |file| require file }

  @superatom = Superatom.instance
  @abbreviation = Abbreviation.instance

  def self.sync_custom_superatom
    @superatom.sync_custom
  end

  def self.all_superatoms
    @superatom.all
  end

  def self.predefined_superatoms
    @superatom.predefined
  end

  def self.custom_superatoms
    @superatom.custom
  end

  def self.get_superatom(superatom)
    @superatom.get_superatom(superatom)
  end

  def self.add_superatom(satom, smi)
    @superatom.add(satom, smi)
  end

  def self.remove_superatom(satom)
    @superatom.remove(satom)
  end

  def self.predefined_abbreviations
    @abbreviation.predefined
  end

  def self.solvents
    @abbreviation.solvents
  end

  def self.all_abbreviations
    @abbreviation.all
  end

  def self.get_abbreviation(abb)
    if @superatom.get_superatom(abb).empty?
      @abbreviation.get_abbreviation(abb)
    else
      ""
    end
  end

  def self.add_abbreviation(abb, smi)
    @abbreviation.add(abb, smi)
  end

  def self.add_abbreviation_hash(hash)
    @abbreviation.add_hash(hash)
  end

  def self.remove_abbreviation(abb)
    @abbreviation.remove(abb)
  end
end

Gem.find_files("chem_scanner/*.rb").each { |file| require file }
Gem.find_files("chem_scanner/export/*.rb").each { |file| require file }
