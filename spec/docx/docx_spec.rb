require "spec_helper"
require "json"

describe "DOCX tests" do
  Dir["spec/docx/*.docx"].each do |file|
    docx = ChemScanner::Docx.new
    docx.read(file)
    filename = File.basename(file, ".docx")
    edocx = JSON.parse(File.read("spec/json/#{filename}_docx.json"))

    context filename do
      docx.cdx_map.each do |key, cdx_info|
        cdx = cdx_info[:cdx]
        areactions = cdx.reactions.map(&:to_hash)
        ereactions = (edocx[key.to_s] || []).map(&:to_hash)

        it "docx #{key} has same number of reaction" do
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
