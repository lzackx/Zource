require "cocoapods"
require "cocoapods-zource/maker/maker"

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
          ].concat(super)
        end

        def initialize(argv)
          super
          @h = argv.flag?("help")
          @configuration = argv.option("configuration", "Release")
          @unhandled_args = argv.remainder!
        end

        def validate!
          super
          banner! if @h
        end

        def run
          UI.message "\nStart Making ...\n".green
          general_update
          CocoapodsZource::Maker.backup_project
          CocoapodsZource::Maker.make_zource_directory
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
          UI.message "\nmaking pods ...\n".green
          maker = CocoapodsZource::Maker.new(@configuration)
          maker.setup_zource_pods!
          maker.make_zource_pods
          UI.message "\nDone\n".green
        end
      end
    end
  end
end
