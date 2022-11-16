require "cocoapods"
require "cocoapods-zource/pod/uploader.rb"

module Pod
  class Command
    class Zource < Command
      class Push < Zource
        include Pod

        self.summary = "push zource pods to binary server"

        self.description = <<-DESC
            push zource to binary server.
        DESC

        def self.options
          [
            ["--aggregation", "push a zource pod that aggregated with all pod in Pod.xcodeproj"],
          ].concat(super)
        end

        def initialize(argv)
          super
          @h = argv.flag?("help")
          @aggregation = argv.flag?("aggregation", false)
          @unhandled_args = argv.remainder!
        end

        def validate!
          super
          banner! if @h
        end

        def run
          uploader = CocoapodsZource::Uploader.new
          if @aggregation
            uploader.upload_aggregation
          else
            uploader.upload
          end
        end

        # End
      end
    end
  end
end
