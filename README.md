
# Introduction

The `ChemScanner` library attempts to extract and interpret reactions/molecules information from ChemDraw-related files format: CDX, CDXML, embedded CDX within DOC and DOCX, [Perkin Elmer ELN](http://www.perkinelmer.com/category/notebook).

# Installation

## Prerequisites

The gem is using [rdkit_chem](https://github.com/CamAnNguyen/rdkit_chem) gem, therefore it requires dependencies of [rdkit_chem](https://github.com/CamAnNguyen/rdkit_chem) gem
  * cmake 3.8 or later
  * curl
  * tar, sed, make (those should be present anyway)
  * SWIG 2 or later
  * python header (`python-dev`)
  * sqlite (`sqlite3-dev`)
  * boost > 1.58 (`libboost-all-dev`)
  * gcc -  **no later than 9.3.0, current code does not work with gcc-10**

## Install
Add this line to your application's Gemfile:

```ruby
gem 'chem_scanner'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install chem_scanner

# UI for ChemScanner
You can try the `ChemScanner` at https://eln.chemotion.net/ or https://eln.chemotion.net/chemscanner. The UI is more user-friendly which some additional features:

 - Export to Excel and CML.
 - Preview of the original scheme.
 - Import directly to [Chemotion ELN](https://eln.chemotion.net)
 - Add comment for each extracted scheme. These comments would also appear in the export and Chemotion ELN imported molecules/reactions.
 - ...

# Usage

To scan/extract a single CDX file

```ruby
require 'chem_scanner'

cdx = ChemScanner::Cdx.new
cdx.read('/path/to/cdx/file')
# Get array of scanned Canonical SMILES
cdx.molecules.map(&:get_cano_smiles)
# Get array of scanned Reactions in SMILES
cdx.reactions.map(&:reaction_smiles)
```
There are 5 classes correspond to 5 supported file formats: CDX, CDXML, DOC, DOCX, PerkinELN.

# API

## Molecule

 - Access "scanned" molecules

  ```ruby
# Molecules - array of scanned molecules
cdx.molecules
# Get array of scanned Canonical SMILES
cdx.molecules.map(&:get_cano_smiles)
# Get one  molecule
molecule = cdx.molecules.first
# Number of scanned molecules
cdx.molecules.count
```

- Molecule class: 

```ruby
# Canonical SMILES
molecule.get_cano_smiles
# Molfile
molecule.get_mdl
# RDKIT RWMol (https://www.rdkit.org/docs/cppapi/classRDKit_1_1RWMol.html)
molecule.rw_mol
# Molecule label (bold text near molecule)
molecule.label
# Molecule text (molecule description)
molecule.text
# Molecule details (additional information from Perkin Elmer ELN)
molecule.details
```
We are using a [ruby-binding version](https://github.com/CamAnNguyen/rdkit_chem) of `RDKit` as  a dependency of `ChemScanner`.

## Reaction

Reaction consist of 3 groups of molecules: `reactants`, `reagents` and `products`. Each group is and array of molecules, which each element is an object of `Molecule` class. In addition, some abbreviations belong to the reaction are represented by SMILES. Those could be access via `reagent_smiles`

```ruby
reaction = cdx.reactions.first
# Access extracted structure group
reactants = reaction.reactants
reagents = reaction.reagents
products = reaction.products
reagent_smiles = reaction.reagent_smiles
```

Further manipulation of each group would be similar to `Molecule` class.

 - **Reaction properties**

Reaction itself has `description`, `yield`, `time`, `temperature` and `details` properties. All these properties are extracted from the ChemDraw scheme, excep `details` field are additional information from `PerkinELN`.

 - **Reaction step**

Some multi-step reactions can also be recognized. If a reaction is a multi-step reaction, the "steps" could be accessed via:

```ruby
# Get first scanned reaction
reaction = cdx.reactions.first
# Access first step
step = reaction.steps.first
step.number # Should be 1 
step.description
step.time
step.temperature
# List reagents SMILES
step.reagents
```

Each step has these following properties: `description`, `time`, `temperature`, and `reagents`

## Supported File Formats

CDX, CDXML, PerkinELN usage and API are described above. Their outputs are simple `molecules` and `reactions`.

DOC and DOCX classes are little bit different. Since DOC and DOCX file can contain more than 1 embedded ChemDraw schemes, which each embedded scheme is 1 CDX scheme. 
`ChemScanner` attempts to extract all of them and put into one `Hash` map, called `cdx_map`.

```ruby
require 'chem_scanner'

doc = ChemScanner::Doc.new
doc.read('/path/to/doc/file')
doc.cdx_map.each do |key, cdx|
  puts cdx.reactions.map(&:reaction_smiles)
end

# Access all molecules in all CDXs
doc.molecules.map(&:get_cano_smiles)
# Access all reactions in all CDXs
doc.reactions.map(&:get_cano_smiles)
```

DOCX is a bit different, `ChemScanner` can extract the CDX together with its preview image within the documents.

```ruby
require 'chem_scanner'

docx = ChemScanner::Docx.new
docx.read('/path/to/docx/file')
docx.cdx_map.each do |key, cdx_info|
  # Get the CDX scheme
  cdx = cdx_info[:cdx]
  puts cdx.reactions.map(&:reaction_smiles)
  
  # Preview images, used for ChemScanner UI
  img_ext = cdx_info[:img_ext] # Could be '.png', '.emf'
  img_b64 = cdx_info[:img_b64] # Base64 encoded of image
end

# Access all molecules in all CDXs
docx.molecules.map(&:get_cano_smiles)
# Access all reactions in all CDXs
docx.reactions.map(&:get_cano_smiles)
```

# Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

# Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ComPlat/chem_scanner. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

# License

The gem is available as open source under the terms of the [GNU AGPLv3 License](https://www.gnu.org/licenses/agpl-3.0.en.html).
