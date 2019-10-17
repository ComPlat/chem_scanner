require "spec_helper"
require "json"

describe "CDX tests" do
  Dir["spec/cdx/*.cdx"].each do |file|
    cdx = ChemScanner::Cdx.new
    cdx.read(file)

    areactions = cdx.reactions.map(&:to_hash).sort_by { |r| r[:id] }
    amolecules = cdx.molecules.map(&:to_hash).sort_by { |r| r[:id] }

    filename = File.basename(file, ".cdx")
    expected = JSON.parse(File.read("spec/json/#{filename}.json"))
    expected.map!(&:to_hash)

    actual = areactions.empty? ? amolecules : areactions

    context filename do
      it "has same number of element" do
        expect(actual.count).to equal(expected.count)
      end

      expected.each do |er|
        eid = er["id"]

        describe "Element #{eid}" do
          r = actual.detect { |react| react[:id] == eid }

          if er["reagent_smiles"].nil?
            it "has same molecule #{eid}" do
              expect(er).to be_same_molecule_as(r)
            end

            next
          end

          it "has same reaction #{eid}" do
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

          it "has same reaction step info" do
            r[:steps].each do |step|
              esteps = er["steps"].select { |s| s["number"] == step[:number] }
              expect(esteps.count).to eq(1)

              estep = esteps.first
              expect(estep["description"]).to eq(step[:description])
              expect(estep["temperature"]).to eq(step[:temperature])
              expect(estep["reagents"]).to eq(step[:reagents])
            end
          end
        end
      end
    end
  end
end
