require "cocoapods"
require "cocoapods-zource/configuration/configuration"

module CocoapodsZource
  class ZourcePod
    class BinaryPodPublisher
      attr_reader :zource_pod
      attr_reader :zip_file_path

      def initialize(zource_pod)
        @zource_pod = zource_pod
        @configuration = CocoapodsZource::Configuration::configuration.configuration
      end

      def publish
        upload
        push
      end

      # curl http://host:port/frameworks -F "name=xxx" -F "version=xx.xx" -F "checksum=xxx" -F "file=path/to/pod.zip"
      def upload
        return if !@zource_pod.zip_path.exist?
        executable = "curl"
        command = Array.new
        command << "#{CocoapodsZource::Configuration::configuration.binary_upload_url}"
        command << "-F"
        command << "'name=#{@zource_pod.binary_podspec.name}'"
        command << "-F"
        command << "'version=#{@zource_pod.binary_podspec.version}'"
        command << "-F"
        command << "'checksum=#{@zource_pod.binary_podspec.checksum}'"
        command << "-F"
        command << "'file=\@#{@zource_pod.zip_path}'"
        full_command = "#{executable} #{command.join(" ")}"
        begin
          system("#{full_command}")
        rescue Exception => e
          abort("Upload zip exception:\n#{e}")
        end
      end

      def push
        source = "#{@configuration.repo_binary_url},#{CocoapodsZource::Configuration::configuration.repo_privacy_urls_string},https://github.com/CocoaPods/Specs.git,https://cdn.cocoapods.org/"
        repo = @configuration.repo_binary_name
        argvs = [
          repo,
          @zource_pod.binary_podspec_path,
          *@unhandled_args,
          "--allow-warnings",
          "--use-libraries",
          "--use-modular-headers",
          "--sources=#{source}",
          "--skip-import-validation",
          "--skip-tests",
          "--use-json",
          "--verbose",
        ]

        push = Pod::Command::Repo::Push.new(CLAide::ARGV.new(argvs))
        push.instance_eval do
          def run
            open_editor if @commit_message && @message.nil?
            check_if_push_allowed
            update_sources if @update_sources
            # validate_podspec_files
            check_repo_status
            update_repo
            add_specs_to_repo
            push_repo unless @local_only
          end
        end
        push.validate!
        push.run
      end
    end
  end
end
