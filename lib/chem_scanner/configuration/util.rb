require "singleton"
require "yaml"

# ChemScanner main module
module ChemScanner
  CONFIG_PATH = File.join(__dir__)

  # Abbreviation management Singleton
  module ConfigurationUtil
    def self.hash_downcase(hash)
      Hash[hash.map { |key, value| [key.downcase, value] }]
    end

    def self.read_superatom(path, range = Range.new(0, -1))
      hash = {}

      File.readlines(path)[range].map do |line|
        fields = line.strip.split(/\s+/)
        next if fields.empty?

        first_char = fields[0][0]
        next if first_char.empty? || first_char == "#"

        first_col = fields.first
        second_col = fields[1]
        hash[first_col.to_sym] = fields[2]
        hash[second_col.to_sym] = fields[2]
      end

      hash
    end

    def self.hash_to_lines(hash)
      lines = [""]
      hash.each { |key, value| lines.push("#{key} #{key} #{value}") }

      lines.join("\n")
    end
  end
end
