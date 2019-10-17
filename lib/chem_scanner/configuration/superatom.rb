require "singleton"
require "yaml"

# ChemScanner main module
module ChemScanner
  # Abbreviation management Singleton
  class Superatom
    require "chem_scanner/configuration/util"
    include Singleton

    Util = ChemScanner::ConfigurationUtil

    attr_reader :all, :custom, :predefined

    PREDEFINED_PATH = "#{CONFIG_PATH}/superatom.txt".freeze
    CUSTOM_PATH = "#{CONFIG_PATH}/custom_superatom.txt".freeze

    def initialize
      FileUtils.touch(CUSTOM_PATH) unless File.exist?(CUSTOM_PATH)
      @custom = Util.read_superatom(CUSTOM_PATH) || {}
      @predefined = Util.read_superatom(PREDEFINED_PATH)
      @all = @custom.merge(@predefined)

      @custom_fs = File.open(CUSTOM_PATH, "a")
    end

    def get_superatom(superatom)
      @all[superatom.to_sym] || ""
    end

    def add(satom, smi)
      return if predefined.has_key?(satom)

      added_hash = {}

      sym = satom.to_sym
      @custom[sym] = smi
      @all[sym] = smi
      added_hash[satom] = smi

      lines = Util.hash_to_lines(added_hash)
      @custom_fs.puts(lines)
      @custom_fs.fsync

      added_hash
    end

    def remove(satom)
      return nil if predefined.has_key?(satom)

      sym = satom.to_sym
      is_removed = @custom.delete(sym)
      removed = is_removed.nil? ? nil : satom
      @all.delete(sym)

      sync_custom

      [removed].compact
    end

    def sync_custom
      @custom_fs.close
      File.open(CUSTOM_PATH, "w+") do |file|
        file.puts(Util.hash_to_lines(custom))
      end

      @custom_fs = File.open(CUSTOM_PATH, "a")
    end

    private

    def check_smi(smi)
      @conv.read_string(@mol, smi)
    end
  end
end
