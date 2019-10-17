require "singleton"
require "yaml"

# ChemScanner main module
module ChemScanner
  # Abbreviation management Singleton
  class Abbreviation
    require "chem_scanner/configuration/util"
    include Singleton

    attr_reader :predefined, :solvents, :custom

    Util = ChemScanner::ConfigurationUtil

    CUSTOM_PATH = "#{CONFIG_PATH}/yaml/custom_abbreviations.yaml".freeze

    def initialize
      @predefined = YAML.load_file("#{CONFIG_PATH}/yaml/abbreviations.yaml")
      @solvents = YAML.load_file("#{CONFIG_PATH}/yaml/solvents.yaml")
      @solvents_downcase = Util.hash_downcase(@solvents)
      @predefined.merge!(@solvents)
      @predefined_downcase = Util.hash_downcase(@predefined)

      FileUtils.touch(CUSTOM_PATH) unless File.exist?(CUSTOM_PATH)
      @custom = YAML.load_file(CUSTOM_PATH) || {}
      @custom_downcase = Util.hash_downcase(@custom)
      @custom_fs = File.open(CUSTOM_PATH, "a")
    end

    def all
      @predefined.merge(@custom)
    end

    def get_abbreviation(abb)
      @predefined_downcase.merge(@custom_downcase)[abb.downcase] || ""
    end

    def add(abb, smi)
      add_hash(abb => smi)
    end

    def add_hash(hash)
      hash.delete_if { |key, _| @custom.has_key?(key) }
      @custom.merge!(hash)
      @custom_downcase.merge!(Util.hash_downcase(hash))

      @custom_fs.puts(hash.to_yaml)
      @custom_fs.fsync

      hash
    end

    def remove(abb)
      return nil if @predefined.has_key?(abb)

      removed = @custom.delete(abb)
      return nil if removed.nil?

      sync_custom(@custom)

      [abb]
    end

    private

    def sync_custom(hashes)
      @custom_fs.close

      File.open(CUSTOM_PATH, "w") do |file|
        file.write(hashes.to_yaml)
      end

      @custom_fs = File.open(CUSTOM_PATH, "a")
    end
  end
end
