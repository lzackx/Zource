require "cocoapods-zource/pod/podfile"

module Pod
  class Command
    class Zource < Command
      class Install < Zource
        include Pod

        self.summary = "pod install hooker, load zource.podfile to Podfile throuth DSL."

        self.description = <<-DESC
            pod install hooker,
            load zource.podfile to Podfile throuth DSL.\n
            zource.podfile:\tSame as Podfle, but has higher priority. 
            original post_install/pre_install will be overwritten if you implemented
        DESC

        def self.options
          [
            ["--repo-update", "Force running `pod repo update` before install"],
            ["--deployment", "Disallow any changes to the Podfile or the Podfile.lock during installation"],
            ["--clean-install", "Ignore the contents of the project cache and force a full pod installation. This only " \
            "applies to projects that have enabled incremental installation"],
          ].concat(super).reject { |(name, _)| name == "--no-repo-update" }
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
          gen = Pod::Command::Install.new(CLAide::ARGV.new(argvs))
          gen.validate!
          gen.run
        end
      end
    end
  end
end
