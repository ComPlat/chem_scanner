# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "chem_scanner/version"

# rubocop:disable Metrics/BlockLength
Gem::Specification.new do |spec|
  spec.name          = "chem_scanner"
  spec.version       = ChemScanner::VERSION
  spec.authors       = ["an.nguyen"]
  spec.email         = ["an.nguyen@kit.edu"]

  spec.summary       = "Extraction of chemical information"
  spec.description   = "ChemScanner is a chemical utiliy to extract " \
                       "chemical information from various scientific formats"
  spec.homepage      = "https://chemotion.net"
  spec.license       = "MIT"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.3"

  spec.add_development_dependency "bundler", ">= 1.16"
  spec.add_development_dependency "rake", ">= 10.0"
  spec.add_development_dependency "rspec", ">= 3.0"

  spec.add_dependency "chronic_duration", ">= 0.10"
  spec.add_dependency "nokogiri", ">= 1.8"
  spec.add_dependency "rdkit_chem"
  spec.add_dependency "ruby-geometry", ">= 0.0.6"
  spec.add_dependency "ruby-ole", ">= 1.2"
end
# rubocop:enable Metrics/BlockLength
