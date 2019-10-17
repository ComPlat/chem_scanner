require "spec_helper"
require "json"

describe "DOC tests" do
  Dir["spec/doc/*.doc"].each do |file|
    doc = ChemScanner::Doc.new
    doc.read(file)
    filename = File.basename(file, ".doc")
    edoc = JSON.parse(File.read("spec/json/#{filename}_doc.json"))

    context filename do
      doc.cdx_map.each do |key, cdx|
        areactions = cdx.reactions.map(&:to_hash)
        ereactions = (edoc[key.to_s] || []).map(&:to_hash)

        it "cdx #{key} has same number of reaction" do
          expect(areactions.count).to equal(ereactions.count)
        end

        ereactions.each do |er|
          eid = er["id"]

          describe "Reaction #{eid}" do
            r = areactions.detect { |react| react[:id] == eid }

            it "has same reaction id" do
              expect(r).to be_truthy
            end

            it "has same reagent_smiles" do
              expect(er["reagent_smiles"]).to match_array(r[:reagent_smiles])
            end

            it "has same reaction info" do
              expect(er["description"]).to eq(r[:description])
              expect(er["temperature"]).to eq(r[:temperature])
              expect(er["time"]).to eq(r[:time])
              expect(er["yield"]).to eq(r[:yield])
            end

            %w[reactants reagents products].each do |group|
              context group do
                egroup = er[group]
                rgroup = (r || {})[group.to_sym]

                it "has same number of molecule" do
                  expect(egroup.count).to equal(rgroup.count)
                end

                it "has same molecules" do
                  egroup.each do |emol|
                    rmol = rgroup.detect { |m| m[:smiles] == emol["smiles"] }
                    expect(rmol).to be_truthy
                    expect(emol).to be_same_molecule_as(rmol)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
