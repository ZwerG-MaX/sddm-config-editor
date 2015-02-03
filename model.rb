require 'qml'
require_relative 'example-config-parser'
require_relative 'config-parser'
require_relative 'version'

module SDDMConfigurationEditor
  class Section
    include QML::Access
    register_to_qml

    ATTRIBUTES = [:section, :settings]
    ATTRIBUTES.each do |attribute|
      property(attribute) {instance_variable_get "@#{attribute}"}
    end

    def initialize(hash)
      populate(hash)
      super()
    end

    def populate(hash)
      ATTRIBUTES.each do |attribute|
        self.instance_variable_set "@#{attribute}", hash[attribute]
      end
    end
  end

  class Setting
    include QML::Access
    register_to_qml

    ATTRIBUTES = [:key, :value, :default_value, :label, :type, :description]
    ATTRIBUTES.each do |attribute|
      property(attribute) {instance_variable_get "@#{attribute}"}
    end

    def initialize(hash)
      populate(hash)
      super()
    end

    def populate(hash)
      ATTRIBUTES.each do |attribute|
        self.instance_variable_set "@#{attribute}", hash[attribute]
      end
    end

    def isDefined
      value || value == false
    end
  end

  module Model
    def self.find_counterparts(array1, array2, key, &block)
      array1.each do |item1|
        found = array2.find do |item2|
          item2[key] == item1[key]
        end
        yield [item1, found]
      end
    end

    def self.create
      config_schema = ExampleConfigParser.new.parse(File.read('data/example.conf'))
      config_values = ConfigParser.new.parse(File.read('/etc/sddm.conf'))

      # Merge values into schema
      find_counterparts(config_schema, config_values, :section) do
        |(schema_section, value_section)|
        if value_section
          value_settings = value_section[:settings]
          schema_settings = schema_section[:settings]
          find_counterparts(schema_settings, value_settings, :key) do
            |schema_setting, value_setting|
            if value_setting
              schema_setting[:value] = value_setting[:value]
            end
          end
        end
      end

      # Replace the setting hashes with Setting objects
      config_schema.each do |section|
        settings = section[:settings]
        settings.map! do |setting_data|
          Setting.new(setting_data)
        end
      end

      config_schema.map! do |section_data|
        Section.new(section_data)
      end

      config_schema
    end

    def self.generate_file(model)
      ''.tap do |content|
        content << "# Generated by SDDM Configuration Editor\n"
        model.each do |section|
          changed_settings = section.settings.select do |setting|
            setting.isDefined
          end
          unless changed_settings.empty?
            content << "[#{section.section}]\n"
            changed_settings.each do |setting|
              content << "#{setting.key}=#{setting.value}\n"
            end
            content << "\n"
          end
        end
      end
    end
  end
end

