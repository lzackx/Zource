require "cocoapods-zource/pod/podfile"

module Pod
  class Command
    class Zource < Command
      class Update < Zource
        include Pod

        self.summary = "pod update hooker, load zource.podfile to Podfile throuth DSL."

        self.description = <<-DESC
            pod update hooker,
            load zource.podfile to Podfile throuth DSL.\n
            zource.podfile:\tSame as Podfle, but has higher priority. 
            original post_install/pre_install will be overwritten if you implemented
        DESC

        def self.options
          [
            ["--sources=#{Pod::TrunkSource::TRUNK_REPO_URL}", "The sources from which to update dependent pods. " \
            "Multiple sources must be comma-delimited"],
            ["--exclude-pods=podName", "Pods to exclude during update. Multiple pods must be comma-delimited"],
            ["--clean-install", "Ignore the contents of the project cache and force a full pod installation. This only " \
            "applies to projects that have enabled incremental installation"],
          ].concat(super)
        end

        def initialize(argv)
          super
          @h = argv.flag?("help")
          @unhandled_args = argv.remainder!
        end

        def validate!
          super
          banner! if @h
        end

        def run
          CocoapodsZource::Podfile.load_podfile_local
          argvs = [
            *@unhandled_args,
          ]
          gen = Pod::Command::Update.new(CLAide::ARGV.new(argvs))
          gen.validate!
          gen.run
        end
      end
    end
  end
end
