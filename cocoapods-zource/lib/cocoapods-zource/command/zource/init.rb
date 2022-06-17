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
          touch_zource_podfile_if_needed
        end

        private

        def touch_zource_podfile_if_needed
          zource_podfile_path = File.join(Dir.pwd, "zource.podfile")
          if File.exist?(zource_podfile_path)
            return
          end
          File.open(zource_podfile_path, "w+") do |f|
            template = <<-EOF
# use zource.podfile to setup Podfile

$ZOURCE_DEFAULT_SOURCE_PODS = [] # source as default in command environment
$ZOURCE_PRIVACY_SOURCE_PODS = [] # source as privacy
$ZOURCE_COCOAPODS_SOURCE_PODS = [] # source as cocoapods

#pre_install do |installer|
#end

target '' do
  
end

#post_install do |installer|
#end
            EOF
            f.write(template)
          end
          print "\n created zource.podfile at: #{zource_podfile_path}"
        end

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
