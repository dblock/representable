module Representable
  class CollectionDeserializer < Array # always is the targeted collection, already.
    def initialize(binding) # TODO: get rid of binding dependency
      @binding = binding
      # should be call to #default:
      collection = []

      super collection
    end

    def deserialize(fragment)
      # next step: get rid of collect.
      fragment.enum_for(:each_with_index).collect do |item_fragment, i|
        @deserializer = ObjectDeserializer.new(@binding)

        @deserializer.call(item_fragment, i) # FIXME: what if obj nil?
      end
    end
  end


  class ObjectDeserializer
    # dependencies: Def#options, Def#create_object
    def initialize(binding)
      @binding = binding
    end

    def call(fragment, *args)
      return fragment unless @binding.typed? # customize with :extend. this is not really straight-forward.

      # what if create_object is responsible for providing the deserialize-to object?
      object = @binding.create_object(fragment, *args) # customize with :instance and :class.

      # DISCUSS: what parts should be in this class, what in Binding?
      representable = prepare(object) # customize with :prepare and :extend.

      deserialize(representable, fragment, @binding.user_options) # deactivate-able via :representable => false.
    end

  private
    def deserialize(object, fragment, options) # TODO: merge with #serialize.
      return object unless @binding.representable?

      object.send(@binding.deserialize_method, fragment, options)
    end

    def prepare(object)
      @binding.send( :evaluate_option,:prepare, object) do
        mod = @binding.representer_module_for(object)

        return object unless mod

        mod = mod.first if mod.is_a?(Array) # TODO: deprecate :extend => [..]
        mod.prepare(object)
      end
    end
    # in deserialize, we should get the original object?
  end
end