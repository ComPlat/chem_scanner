require "chem_scanner"

RSpec::Matchers.define :be_same_molecule_as do |actual|
  match do |expected|
    @smiles_check = actual[:smiles] == expected["smiles"]
    @label_check = actual[:label] == expected["label"]
    @text_check = actual[:text] == expected["text"]

    @smiles_check && @label_check && @text_check
  end

  failure_message do |amol|
    errs = []
    %w[smiles label text].each do |prop|
      check = instance_variable_get("@#{prop}_check")
      next if check

      errs.push(prop)
    end

    error_fields = errs.join(", ")
    asmiles = amol["smiles"]

    "Unexpected value of molecule #{asmiles} on: #{error_fields}"
  end
end
