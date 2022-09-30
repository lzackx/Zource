require "cocoapods"

module CocoapodsZource
  class ZourcePod
    class BinaryPodPublisher
      attr_reader :zource_pod
      attr_reader :zip_file_path

      def initialize(zource_pod)
        @zource_pod = zource_pod
        @zip_file_path = File.join(@zource_pod.zip_path, "#{@zource_pod.binary_podspec.name}.zip")
      end

      def publish
        upload
        push
      end

      # curl http://host:port/frameworks -F "name=xxx" -F "version=xx.xx" -F "checksum=xxx" -F "file=path/to/pod.zip"
      def upload
        executable = "curl"
        command = "#{CocoapodsZource::Configuration::configuration.binary_upload_url}"
        command += "-F 'name=#{@zource_pod.binary_podspec.name}'"
        command += "-F 'version=#{@zource_pod.binary_podspec.version}'"
        command += "-F 'checksum=#{@zource_pod.binary_podspec.checksum}'"
        command += "-F 'file=@#{@zip_file_path}'"
        raise_on_failure = true
        begin
          Pod.Executable.execute_command(executable, command, raise_on_failure)
        rescue Exception => e
          abort("Upload zip exception:\n#{e}")
        end
      end

      def push
        source = "#{@configuration.repo_binary_url},#{@configuration.repo_privacy_url},https://github.com/CocoaPods/Specs.git,https://cdn.cocoapods.org/"
        repo = @configuration.repo_binary_name
        argvs = [
          repo,
          @zource_pod.path,
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
        push.validate!
        push.run
      end
    end
  end
end
