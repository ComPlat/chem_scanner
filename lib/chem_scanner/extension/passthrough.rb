module Passthrough
  def passthrough(object)
    object.instance_variables.each do |iv|
      instance_variable_set(iv, object.instance_variable_get(iv))
    end
  end
end
