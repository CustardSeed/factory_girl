module FactoryGirl

  class AttributeGroup
    attr_reader :name
    attr_reader :attributes
    
    def initialize(name, &block) #:nodoc:
      @name = name
      @attributes = []
      proxy = FactoryGirl::DefinitionProxy.new(self)
      proxy.instance_eval(&block) if block_given?
    end

    def define_attribute(attribute)
      name = attribute.name
      if attribute_defined?(name)
        raise AttributeDefinitionError, "Attribute already defined: #{name}"
      end
      @attributes << attribute
    end
    
    def add_callback(name, &block)
      unless [:after_build, :after_create, :after_stub].include?(name.to_sym)
        raise InvalidCallbackNameError, "#{name} is not a valid callback name. Valid callback names are :after_build, :after_create, and :after_stub"
      end
      @attributes << Attribute::Callback.new(name.to_sym, block)
    end
    
    def names
      [@name]
    end
    
    private
    
    def attribute_defined? (name)
      !@attributes.detect {|attr| attr.name == name && !attr.is_a?(Attribute::Callback) }.nil?
    end

  end
end