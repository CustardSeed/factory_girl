require "active_support/core_ext/hash/keys"
require "active_support/core_ext/module/delegation"
require "active_support/inflector"

module FactoryGirl
  class Factory
    attr_reader :name #:nodoc:

    def initialize(name, options = {}) #:nodoc:
      assert_valid_options(options)
      @name             = name.to_s.underscore.to_sym
      @parent           = options[:parent]
      @aliases          = options[:aliases] || []
      @traits           = options[:traits]  || []
      @class_name       = options[:class]
      @default_strategy = options[:default_strategy]
      @defined_traits   = []
      @attribute_list   = build_attribute_list
      @compiled         = false
    end

    delegate :overridable?, :declarations, :declare_attribute, :define_attribute, :add_callback, :to => :@attribute_list

    def factory_name
      $stderr.puts "DEPRECATION WARNING: factory.factory_name is deprecated; use factory.name instead."
      name
    end

    def build_class #:nodoc:
      @build_class ||= class_name.to_s.camelize.constantize
    end

    def default_strategy #:nodoc:
      @default_strategy || (parent && parent.default_strategy) || :create
    end

    def allow_overrides
      @compiled = false
      @attribute_list.overridable
      self
    end

    def define_trait(trait)
      @defined_traits << trait
    end

    def run(proxy_class, overrides, &block) #:nodoc:
      ensure_compiled

      runner_options = {
        :attributes  => attributes,
        :callbacks   => callbacks,
        :to_create   => @to_create_block,
        :build_class => build_class,
        :proxy_class => proxy_class
      }

      result = Runner.new(runner_options).run(overrides)

      block ? block.call(result) : result
    end

    def human_names
      names.map {|name| name.to_s.humanize.downcase }
    end

    def associations
      attributes.select {|attribute| attribute.association? }
    end

    def trait_by_name(name)
      if existing_attribute = trait_for(name)
        existing_attribute
      elsif parent
        parent.trait_by_name(name)
      else
        FactoryGirl.trait_by_name(name)
      end
    end

    # Names for this factory, including aliases.
    #
    # Example:
    #
    #   factory :user, :aliases => [:author] do
    #     # ...
    #   end
    #
    #   FactoryGirl.create(:author).class
    #   # => User
    #
    # Because an attribute defined without a value or block will build an
    # association with the same name, this allows associations to be defined
    # without factories, such as:
    #
    #   factory :user, :aliases => [:author] do
    #     # ...
    #   end
    #
    #   factory :post do
    #     author
    #   end
    #
    #   FactoryGirl.create(:post).author.class
    #   # => User
    def names
      [name] + @aliases
    end

    def to_create(&block)
      @to_create_block = block
    end

    def ensure_compiled
      compile unless @compiled
    end

    protected

    def class_name #:nodoc:
      @class_name || (parent && parent.class_name) || name
    end

    def attributes
      ensure_compiled
      build_attribute_list.tap do |list|
        @traits.reverse.map { |name| trait_by_name(name) }.each do |trait|
          list.apply_attributes(trait.attributes)
        end

        list.apply_attributes(@attribute_list)
        list.apply_attributes(parent.attributes) if parent
      end
    end

    private

    def callbacks
      attributes.callbacks
    end

    def compile
      inherit_factory(parent) if parent

      declarations.each do |declaration|
        declaration.to_attributes.each do |attribute|
          define_attribute(attribute)
        end
      end

      @compiled = true
    end

    def inherit_factory(parent) #:nodoc:
      parent.ensure_compiled
      allow_overrides if parent.overridable?
    end

    def assert_valid_options(options)
      options.assert_valid_keys(:class, :parent, :default_strategy, :aliases, :traits)

      if options[:default_strategy]
        Proxy.ensure_strategy_exists!(options[:default_strategy])
        $stderr.puts "DEPRECATION WARNING: default_strategy is deprecated."
        $stderr.puts "Override to_create if you need to prevent a call to #save!."
      end
    end

    def trait_for(name)
      @defined_traits.detect {|trait| trait.name == name }
    end

    def parent
      return unless @parent
      FactoryGirl.factory_by_name(@parent)
    end

    def build_attribute_list
      AttributeList.new(@name)
    end

    class Runner
      def initialize(options = {})
        @attributes  = options[:attributes]
        @callbacks   = options[:callbacks]
        @to_create   = options[:to_create]
        @build_class = options[:build_class]
        @proxy_class = options[:proxy_class]

        @overrides   = {}
      end

      def run(overrides = {})
        @overrides = overrides.symbolize_keys

        apply_attributes
        apply_remaining_overrides

        proxy.result(@to_create)
      end

      private

      def apply_attributes
        @attributes.each do |attribute|
          if overrides_for_attribute(attribute).any?
            handle_attribute_with_overrides(attribute)
          else
            handle_attribute_without_overrides(attribute)
          end
        end
      end

      def apply_remaining_overrides
        @overrides.each { |attr, val| proxy.set(attr, val) }
      end

      def overrides_for_attribute(attribute)
        @overrides.select { |attr, val| attribute.aliases_for?(attr) }
      end

      def handle_attribute_with_overrides(attribute)
        overrides_for_attribute(attribute).each do |attr, val|
          if attribute.ignored
            proxy.set_ignored(attr, val)
          else
            proxy.set(attr, val)
          end

          @overrides.delete(attr)
        end
      end

      def handle_attribute_without_overrides(attribute)
        attribute.add_to(proxy)
      end

      def proxy
        @proxy ||= @proxy_class.new(@build_class, @callbacks)
      end
    end
  end
end
