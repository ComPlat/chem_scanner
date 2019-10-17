# frozen_string_literal: true

module ChemScanner
  class ElementMap < Hash
    def except(id)
      reject { |key, _| key == id }
    end
  end
end
