require "cocoapods-zource/configuration/asker"

module Pod
  class Command
    class Zource < Command
      class Init < Zource
        self.summary = "configuration guide."
        self.description = <<-DESC
        guide to set configuration.
        DESC

        def initialize(argv)
          super
          @url = argv.option("url")
          @h = argv.flag?("help")
        end

        def self.options
          [
            ["--url=URL", "URL of configuration file"],
          ].concat(super)
        end

        def validate!
          super
          banner! if @h
        end

        def run
          puts "run init"
          puts Dir.pwd
          if @url.nil?
            configure_with_asker
          else
            configure_with_url(@url)
          end
        end

        private

        def configure_with_url(url)
          require "open-uri"

          UI.puts "Downloading...\n"
          file = open(url)
          contents = YAML.safe_load(file.read)

          UI.puts "Synchronizing...\n"
          CocoapodsZource::Configuration::configuration.sync_configuration(contents.to_hash)

          UI.puts "\n\nConfigruation file: #{CocoapodsZource::Configuration::configuration.configuration_file}\n".cyan
          UI.puts "\n#{CocoapodsZource::Configuration::configuration.configuration.to_yaml}\n".green
          UI.puts "\nDone.\n".green
        rescue Errno::ENOENT => e
          raise Informative, "Invalid URL: #{url}, \nplease retry it with valid URL."
        end

        def configure_with_asker
          asker = CocoapodsZource::Configuration::Asker.new
          asker.wellcome_message

          configuration = {}
          template_hash = CocoapodsZource::Configuration::configuration.template_hash
          template_hash.each do |k, v|
            default = begin
                CocoapodsZource::Configuration::configuration.send(k)
              rescue StandardError
                nil
              end
            configuration[k] = asker.ask_with_answer(v[:description], default)
          end

          CocoapodsZource::Configuration::configuration.sync_configuration(configuration)
          asker.done_message
        end
      end
    end
  end
end
