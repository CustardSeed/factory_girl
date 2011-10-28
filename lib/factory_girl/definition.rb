module FactoryGirl
  class Definition
    attr_reader :callbacks, :defined_traits, :attribute_list

    def initialize(name = nil)
      @attribute_list = AttributeList.new(name)
      @callbacks      = []
      @defined_traits = []
      @to_create      = nil
    end

    delegate :declare_attribute, :to => :attribute_list

    def add_callback(callback)
      @callbacks << callback
    end

    def to_create(&block)
      if block_given?
        @to_create = block
      else
        @to_create
      end
    end

    def define_trait(trait)
      @defined_traits << trait
    end
  end
end
