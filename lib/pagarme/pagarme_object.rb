# encoding: utf-8
require 'set'

module PagarMe
  class PagarMeObject

	def initialize(response = {})
	  #init @attributes - which are the attributes in the object
	  @attributes = {}

	  # filters - which are the filters that will be called when appropriate , such as before_set
	  @filters =  {}

	  # Values that were changed in the object but weren't saved
	  @unsaved_values = Set.new

	  #Update object
	  update(response)
	end

	def self.build(attributes)
	  object = self.new(attributes)
	  return object
	end

	def update(attributes)

	  removed = Set.new(@attributes.keys - attributes.keys)
	  added = Set.new(attributes.keys - @attributes.keys)

	  instance_eval do
		remove_attribute(removed)
		add_attribute(added)
	  end

	  removed.each do |key|
		@attributes.delete(key)
		@unsaved_values.delete(key)
	  end

	  attributes.each do |key, value|
		@attributes[key] = Util.convert_to_pagarme_object(value)
		@unsaved_values.delete(key)
	  end
	end

	def each(&block)
	  @attributes.each(&block)
	end

	def []=(key,value)
	  @attributes[key] = value
	end

	def [](key)
	  @attributes[key.to_sym]
	end

	def unsaved_values
	  values = {}
	  @unsaved_values.each do |k|
		if(@attributes[k].kind_of?(PagarMeObject))
		  values[k] = @attributes[k].unsaved_values
		else
		  values[k] = @attributes[k]
		end
	  end
	  values
	end

	def to_hash
	  ret_attributes = {}
	  @attributes.each do |k,v|
		if @attributes[k].kind_of?(PagarMeObject)
		  ret_attributes[k] = @attributes[k].to_hash if @attributes[k].kind_of?(PagarMeObject)
		else
		  ret_attributes[k] = @attributes[k]
		end
	  end
	  return ret_attributes
	end

	protected

	def metaclass
	  class << self; self; end
	end

	def remove_attribute(keys)
	  metaclass.instance_eval do
		keys.each do |key|
		  key_sym = :"#{key}="
		  remove_method(key) if method_defined?(key)
		  remove_method(key_sym) if method_defined?(key_sym)
		end
	  end
	end

	def add_attribute(keys)
	  metaclass.instance_eval do
		keys.each do |key|
		  key_set = "#{key}="
		  define_method(key) { @attributes[key] }
		  define_method(key_set) do |value|
			if @filters[key]
			  @filters[key].each do |meth|
				if methods.include?(meth)
				  @attributes[key] = method(meth).call(value)
				  @unsaved_values.add(key)
				end
			  end
			else
			  @attributes[key] = value
			  @unsaved_values.add(key)
			end
		  end
		end
	  end
	end

	def before_set_filter(attribute, method)
	  @filters[attribute.to_sym] = Array.new unless @filters[attribute.to_sym]
	  @filters[attribute.to_sym] << method.to_sym
	end

	def method_missing(name, *args)
	  if name.to_s.end_with?('=')
		attr = name.to_s[0...-1].to_sym
		add_attribute([attr])
		begin
		  mth = method(name)
		rescue NameError
		  raise NoMethodError.new("O atributo #{name} nao e permitido.")
		end
		return mth.call(args[0])
	  else
		return @attributes[name] if @attributes.has_key?(name)
	  end
	end
  end
end
