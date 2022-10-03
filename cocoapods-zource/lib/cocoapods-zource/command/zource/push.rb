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
 # ["--allow-warnings", "Allows pushing even if there are warnings"],
                       # ["--use-libraries", "Linter uses static libraries to install the spec"],
                       # ["--use-modular-headers", "Lint uses modular headers during installation"],
                       # ["--sources=#{Pod::TrunkSource::TRUNK_REPO_URL}", "The sources from which to pull dependent pods " \
                       # "(defaults to all available repos). Multiple sources must be comma-delimited"],
                       # ["--local-only", "Does not perform the step of pushing REPO to its remote"],
                       # ["--no-private", "Lint includes checks that apply only to public repos"],
                       # ["--skip-import-validation", "Lint skips validating that the pod can be imported"],
                       # ["--skip-tests", "Lint skips building and running tests during validation"],
                       # ['--commit-message="Fix bug in pod"', "Add custom commit message. Opens default editor if no commit " \
                       # "message is specified"],
                       # ["--use-json", "Convert the podspec to JSON before pushing it to the repo"],
                       # ["--swift-version=VERSION", "The `SWIFT_VERSION` that should be used when linting the spec. " \
                       # "This takes precedence over the Swift versions specified by the spec or a `.swift-version` file"],
                       # ["--no-overwrite", "Disallow pushing that would overwrite an existing spec"],
                       # ["--update-sources", "Make sure sources are up-to-date before a push"],
            ].concat(super)
        end

        def initialize(argv)
          #   @allow_warnings = argv.flag?("allow-warnings")
          #   @local_only = argv.flag?("local-only")
          #   @repo = argv.shift_argument
          #   @source = source_for_repo
          #   @source_urls = argv.option("sources", config.sources_manager.all.map(&:url).append(Pod::TrunkSource::TRUNK_REPO_URL).uniq.join(",")).split(",")
          #   @update_sources = argv.flag?("update-sources")
          #   @podspec = argv.shift_argument
          #   @use_frameworks = !argv.flag?("use-libraries")
          #   @use_modular_headers = argv.flag?("use-modular-headers", false)
          #   @private = argv.flag?("private", true)
          #   @message = argv.option("commit-message")
          #   @commit_message = argv.flag?("commit-message", false)
          #   @use_json = argv.flag?("use-json")
          #   @swift_version = argv.option("swift-version", nil)
          #   @skip_import_validation = argv.flag?("skip-import-validation", false)
          #   @skip_tests = argv.flag?("skip-tests", false)
          #   @allow_overwrite = argv.flag?("overwrite", true)
          super
          @h = argv.flag?("help")
          @unhandled_args = argv.remainder!
        end

        def validate!
          super
          banner! if @h
        end

        def run
          uploader = CocoapodsZource::Uploader.new
          uploader.upload
        end

        # End
      end
    end
  end
end
