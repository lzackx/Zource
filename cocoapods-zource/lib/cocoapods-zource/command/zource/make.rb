require "cocoapods"
require "cocoapods-zource/pod/maker"

module Pod
  class Command
    class Zource < Command
      class Make < Zource
        include Pod

        self.summary = "Make xcframework pod of each dependencies"

        self.description = <<-DESC
            Make xcframework pod of each dependencies
        DESC

        def self.options
          [
            ["--configuration=Configuration", "Configuration for building, default to: Release"],
            ["--update-dependency", "Execute 'pod update' before make zource pods"],
            ["--backup", "Backup the project directory"],
            ["--remake", "remake zource directory"],
            ["--not-generate-project", "Not generate project"],
            ["--not-construct-project", "Not construct project"],
            ["--not-combine-xcframework", "Not combine xcframework"],
            ["--not-compress-binary", "Not compress binary"],
          ].concat(super)
        end

        def initialize(argv)
          super
          @h = argv.flag?("help")
          @configuration = argv.option("configuration", "Release")
          @update_dependency = argv.flag?("update-dependency", false)
          @backup = argv.flag?("backup", false)
          @remake = argv.flag?("remake", false)
          @not_generate_project = argv.flag?("not-generate-project", false)
          @not_construct_project = argv.flag?("not-construct-project", false)
          @not_combine_xcframework = argv.flag?("not-combine-xcframework", false)
          @not_compress_binary = argv.flag?("not-compress-binary", false)
          @unhandled_args = argv.remainder!
        end

        def validate!
          super
          banner! if @h
        end

        def run
          UI.message "\nStart Making ...\n".green
          if @update_dependency
            general_update
          end
          if @backup
            CocoapodsZource::Maker.backup_project
          end
          CocoapodsZource::Maker.make_zource_directory(@remake)
          make_pods
        end

        def general_update
          UI.message "\npod update as general ...\n".green
          argvs = [
            *@unhandled_args,
          ]
          gen = Pod::Command::Update.new(CLAide::ARGV.new(argvs))
          gen.validate!
          gen.run
        end

        def make_pods
          UI.message "\nMaking pods ...\n".green
          maker = CocoapodsZource::Maker.new(:configuration => @configuration,
                                             :should_generate_project => !@not_generate_project,
                                             :should_construct_project => !@not_construct_project,
                                             :should_combine_xcframework => !@not_combine_xcframework,
                                             :should_compress_binary => !@not_compress_binary)
          maker.setup_zource_pods!
          maker.make_zource_pods
          UI.message "\nDone\n".green
        end
      end
    end
  end
end
