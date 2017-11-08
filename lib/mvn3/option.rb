require 'everyday-cli-utils'
include EverydayCliUtils
import :maputil

module Mvn3
  class OptionType
    def initialize(default_value_block, value_determine_block, value_transform_block = nil)
      @default_value_block   = default_value_block
      @value_determine_block = value_determine_block
      @value_transform_block = value_transform_block
    end

    def default_value(settings = {})
      @default_value_block.call(settings)
    end

    def updated_value(current_value, new_value, settings = {})
      new_value = @value_transform_block.call(new_value, settings) unless @value_transform_block.nil?
      @value_determine_block.call(current_value, new_value, settings)
    end
  end

  class OptionTypes
    def self.def_type(type, default_value_block, value_determine_block, value_transform_block = nil)
      @types       ||= {}
      @types[type] = OptionType.new(default_value_block, value_determine_block, value_transform_block)
    end

    def self.default_value(type, settings = {})
      @types ||= {}
      @types.has_key?(type) ? @types[type].default_value(settings) : nil
    end

    def self.updated_value(type, current_value, new_value, settings = {})
      @types ||= {}
      @types.has_key?(type) ? @types[type].updated_value(current_value, new_value, settings) : current_value
    end

    def_type(:option,
             ->(_) {
               false
             },
             ->(current_value, new_value, settings) {
               new_value ? !current_value : current_value
             },
             ->(new_value, _) {
               !(!new_value)
             })
    def_type(:option_with_param,
             ->(settings) {
               settings[:append] ? [] : nil
             },
             ->(current_value, new_value, settings) {
               settings[:append] ? (current_value + new_value) : ((new_value.nil? || new_value == '') ? current_value : new_value)
             },
             ->(new_value, settings) {
               new_value.is_a?(Array) ? (settings[:append] ? new_value : new_value[0]) : (settings[:append] ? [new_value] : new_value)
             })
  end

  class OptionDef
    attr_reader :value, :desc, :type

    def initialize(type, desc, settings = {}, &block)
      @type     = type
      @desc     = desc
      @settings = settings
      @block    = block
      @value    = OptionTypes.default_value(type, settings)
      @values   = {}
    end

    def set(value)
      @value  = value
      @values = {}
    end

    def update(value, layer)
      @values[layer] = OptionTypes.default_value(@type, @settings) unless @values.has_key?(layer)
      @values[layer] = OptionTypes.updated_value(@type, @values[layer], value, @settings)
    end

    def reset(layer = nil)
      if layer.nil?
        @values = {}
      else
        @values.delete(layer)
      end
    end

    def run
      @block.call unless @block.nil? || !@block
    end

    def composite(*layers)
      value = @value
      layers.each { |layer| value = OptionTypes.updated_value(@type, value, @values[layer], @settings) if @values.has_key?(layer) }
      value
    end

    def self.register(options, type, opt_name, desc, settings = {}, default_settings = {}, &block)
      settings          = EverydayCliUtils::MapUtil.extend_hash(default_settings, settings)
      opt               = OptionDef.new(type, desc, settings, &block)
      options[opt_name] = opt
    end
  end

  class OptionList
    attr_accessor :default_settings, :help_str

    def initialize
      @options          = {}
      @default_settings = {}
    end

    def []=(opt_name, opt)
      @options[opt_name] = opt
    end

    def set(opt_name, value)
      @options[opt_name].set(value) if @options.has_key?(opt_name)
    end

    def set_all(opts)
      opts.each { |opt| set(opt[0], opt[1]) }
    end

    def update(opt_name, value, layer)
      @options[opt_name].update(value, layer) if @options.has_key?(opt_name)
    end

    def update_all(layer, opts)
      opts.each { |opt| update(opt[0], opt[1], layer) }
    end

    def reset_all(layer = nil)
      @options.each { |v| v[1].reset(layer) }
    end

    def register(type, opt_name, desc, settings = {}, &block)
      OptionDef.register(self, type, opt_name, desc, settings, @default_settings, &block)
    end

    def options
      sort_options
    end

    def composite(*layers)
      hash = {}
      options.each { |v| hash[v[0]] = v[1].composite(*layers) }
      hash
    end

    def sort_options
      @options = Hash[@options.to_a.sort_by { |v| v[0].to_s }]
    end

    def show_defaults
      script_defaults = composite
      global_defaults = composite(:global)
      local_defaults  = composite(:global, :local)
      global_diff     = EverydayCliUtils::MapUtil.hash_diff(global_defaults, script_defaults)
      local_diff      = EverydayCliUtils::MapUtil.hash_diff(local_defaults, global_defaults)
      str             = "Script Defaults:\n#{options_to_str(script_defaults)}\n"
      str << "Script + Global Defaults:\n#{options_to_str(global_diff)}\n" unless global_diff.empty?
      str << "Script + Global + Local Defaults:\n#{options_to_str(local_diff)}\n" unless local_diff.empty?
      str
    end

    def options_to_str(options, indent = 4)
      str          = ''
      max_name_len = @options.values.map { |v| v.names.join(', ').length }.max
      options.each { |v|
        opt       = @options[v[0]]
        val       = v[1]
        names_str = opt.names.join(', ')
        str << "#{' ' * indent}#{names_str}#{' ' * ((max_name_len + 4) - names_str.length)}#{val_to_str(val)}\n"
      }
      str
    end

    def val_to_str(val)
      if val.nil?
        'nil'
      elsif val.is_a?(TrueClass)
        'true'
      elsif val.is_a?(FalseClass)
        'false'
      elsif val.is_a?(Enumerable)
        "[#{val.map { |v| val_to_str(v) }.join(', ')}]"
      elsif val.is_a?(Numeric)
        val.to_s
      else
        "'#{val.to_s}'"
      end
    end
  end

  module OptionUtil
    def option(opt_name, desc, settings = {}, &block)
      @options ||= OptionList.new
      @options.register(:option, opt_name, desc, settings, &block)
    end

    def option_with_param(opt_name, desc, settings = {}, &block)
      @options ||= OptionList.new
      @options.register(:option_with_param, opt_name, desc, settings, &block)
    end

    def default_settings(settings = {})
      @options                  ||= OptionList.new
      @options.default_settings = settings
    end

    def default_options(opts = {})
      @options ||= OptionList.new
      @options.set_all(opts)
    end

    def apply_options(layer, opts = {})
      @options ||= OptionList.new
      @options.update_all(layer, opts)
    end

    def reset_all(layer = nil)
      @options.reset_all(layer)
    end

    def desc(opt_name = nil, indent = 4)
      opts = @options.options
      if opt_name.nil?
        str          = ''
        max_name_len = opts.keys.map { |v| v.to_s.length }.max
        opts.each { |v|
          opt  = v[1]
          name = v[0].to_s
          str << "#{' ' * indent}#{name}#{' ' * ((max_name_len + 4) - name.length)}#{opt.desc}\n"
        }
        str
      else
        sym = opt_name.to_sym
        if opts.has_key?(sym)
          opt = opts[sym]
          "#{' ' * indent}#{opt_name.to_s}#{' ' * 4}#{opt.desc}\n"
        else
          "#{' ' * indent}Option '#{opt_name.to_s}' not known"
        end
      end
    end

    def options
      @options.composite(:global, :local, :arg)
    end

    def option_list
      @options
    end

    def defaults_path(file_path, global = false)
      if global
        @global_path = file_path.nil? ? nil : File.expand_path(file_path)
      else
        @local_path = file_path.nil? ? nil : File.expand_path(file_path)
      end
    end

    def update_defaults(global = false, save = true)
      load_defaults(global) if save
      yield
      save_defaults(global) if save
    end

    def save_defaults(global = false)
      IO.write(global ? @global_path : @local_path, @options.composite(global ? :global : :local, :arg).to_yaml)
    end

    def load_defaults(global = false)
      unless (global ? @global_path : @local_path).nil? || !File.exist?(global ? @global_path : @local_path)
        @options.update_all global ? :global : :local, YAML::load_file(global ? @global_path : @local_path)
      end
    end
  end
end