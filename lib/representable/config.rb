module Representable
  # Config contains three independent, inheritable directives: features, options and definitions.
  # Inherit from parent with Config#inherit!(parent).
  class Config
    # Keep in mind that performance doesn't matter here as 99.9% of all representers are created
    # at compile-time.

    # child.inherit(parent)
    module Inheritable
    end

    class InheritableArray < Array
      include Inheritable

      def inherit!(parent)
        puts "before push: #{self.inspect}"
        push(*parent.clone)
      end
    end

    class InheritableHash < Hash
      include Inheritable

      def inherit!(parent)
        #merge!(parent.clone)
        for key in (parent.keys + keys).uniq
          next unless parent_value = parent[key]

          self[key].inherit!(parent_value) and next if self[key].is_a?(Inheritable)
          self[key] = parent_value.clone and next if parent_value.is_a?(Inheritable)

          self[key] = parent_value # merge! behaviour
        end

        self
      end

      def clone
        self.class[ collect { |k,v| [k, clone_value(v)] } ]
      end

      def clone_value(value)
        return value.clone if value.is_a?(Inheritable)
        value
      end
    end

    # Stores Definitions from ::property. It preserves the adding order (1.9+).
    # Same-named properties get overridden, just like in a Hash.
    class Definitions < InheritableHash
      def <<(definition)
        warn "[Representable] Deprecation Warning: `representable_attrs <<` is deprecated and will be removed in 1.10. Please use representable_attrs[:title] = {} and keep it real."
        store(definition.name, definition)
      end

      def clone
        # we can't use InheritableHash#clone here as we override #each :(

        # compile {title: definition.clone, ..}. this is a bit cryptic but makes it work with rubinius.
        rbx_compatible_hash = values.inject({}) { |memo, dfn| memo[dfn.name] = dfn.clone; memo }
        self.class[rbx_compatible_hash]
      end
      # public :[]=

      def [](name)
        super(name.to_s)
      end

      def []=(name, options)
        if options.delete(:inherit) # i like that: the :inherit shouldn't be handled outside.
          return self[name].merge!(options)
        end

        super(name.to_s, Definition.new(name, options))
      end

      extend Forwardable
      def_delegators :values, :each # so we look like an array.
    end


    def initialize
      @directives = {
        :features    => @features     = InheritableHash.new,
        :definitions => @definitions  = Definitions.new,
        :options     => @options      = InheritableHash.new
      }
    end
    attr_reader :directives, :options

    def features
      @features.keys
    end

    def inherit!(parent)
      for name, dir in directives
        # this should be parent.clone, not accessing the directives.
        dir.inherit!(parent.directives[name])
      end
    end

    # delegate #collect etc to Definitions instance.
    extend Forwardable
    def_delegators :@definitions, :[], :[]=, :<<, :size, :each
    include Enumerable


    def wrap=(value)
      value = value.to_s if value.is_a?(Symbol)
      @wrap = Uber::Options::Value.new(value)
    end

    # Computes the wrap string or returns false.
    def wrap_for(name, context, *args)
      return unless @wrap

      value = @wrap.evaluate(context, *args)

      return infer_name_for(name) if value === true
      value
    end

  private
    def infer_name_for(name)
      name.to_s.split('::').last.
       gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
       gsub(/([a-z\d])([A-Z])/,'\1_\2').
       downcase
    end
  end
end
