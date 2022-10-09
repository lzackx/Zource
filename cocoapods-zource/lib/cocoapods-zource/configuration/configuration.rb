require "yaml"
require "cocoapods"

module CocoapodsZource
  class Configuration

    # attr_accessor :environment
    # attr_accessor :repo_privacy_urls
    # attr_accessor :repo_binary_name
    # attr_accessor :repo_binary_url
    # attr_accessor :binary_url

    def self.configuration
      @@configuration ||= Configuration.new
    end

    # def initialize()
    #   @environment = ""
    #   @repo_privacy_urls = ""
    #   @repo_binary_name = ""
    #   @repo_binary_url = ""
    #   @binary_url = ""
    #   super
    # end

    def template_hash
      {
        # "environment" => { description: "Environment for building", default: "Development" },
        "repo_privacy_urls" => { description: "Privacy cocoapods repo url, divide with comma", default: "" },
        "repo_binary_name" => { description: "Binary cocoapods repo name", default: "" },
        "repo_binary_url" => { description: "Binary cocoapods repo url", default: "" },
        "binary_url" => { description: "URL of binary", default: "http://localhost:9687" },
      }
    end

    def default_configuration
      @default_configuration ||= Hash[template_hash.map { |k, v| [k, v[:default]] }]
    end

    def configuration
      @configuration ||= begin
          puts "====== cocoapods-zource #{CocoapodsZource::VERSION} version ======== \n"
          @configuration = OpenStruct.new load_configuration
          @configuration
        end
    end

    def repo_privacy_urls_string
      string = ""
      if repo_privacy_urls.is_a?(String)
        string = repo_privacy_urls
      elsif repo_privacy_urls.is_a?(Array)
        string = repo_privacy_urls.join(",")
      else
        string = repo_privacy_urls.to_s
      end
      string
    end

    def repo_privacy_urls_array
      array = Array.new
      if repo_privacy_urls.is_a?(Array)
        array = repo_privacy_urls
      else
        array = repo_privacy_urls.split(",")
      end
      array
    end

    def load_configuration
      if File.exist?(configuration_file)
        YAML.load_file(configuration_file)
      else
        default_configuration
      end
    end

    def configuration_file
      configuration_file_with_environment(@environment)
    end

    def configuration_file_with_environment(environment)
      file = "zource.yml"
      # if !environment.nil? && !environment.empty?
      #   file = "zource" + ".#{environment}" + ".yml"
      # end
      Pod::Config.instance.project_root.join(file)
    end

    def binary_download_url(name, version)
      @binary_download_url = binary_url + "/frameworks/#{name}/#{version}/.zip"
    end

    def binary_upload_url
      @binary_upload_url = binary_url + "/frameworks"
    end

    def sync_configuration(configuration)
      @configuration = configuration
      File.open(configuration_file_with_environment(@configuration["environment"]), "w+") do |f|
        f.write(configuration.to_yaml)
      end
    end

    #   private
    def respond_to_missing?(method, include_private = false)
      configuration.respond_to?(method) || super
    end

    def method_missing(method, *args, &block)
      if configuration.respond_to?(method)
        configuration.send(method, *args)
      elsif template_hash.keys.include?(method.to_s)
        raise Pod::Informative, "#{method} key has to configured in #{configuration_file} , please init command or D.I.Y".red
      else
        super
      end
    end
  end
end
