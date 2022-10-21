require "cocoapods"

module CocoapodsZource
  class ZourcePod
    class BinaryCompressor
      attr_reader :zource_pod

      def initialize(zource_pod)
        @zource_pod = zource_pod
      end

      def compress
        Dir::chdir(@zource_pod.zource_pod_binary_directory)
        executable = "zip"
        command = Array.new
        command << "-r"
        command << "#{@zource_pod.zip_path}"
        command << "./*"
        # raise_on_failure = true
        full_command = "#{executable} #{command.join(" ")}"
        begin
          system("#{full_command}")
        rescue Exception => e
          abort("compress exception:\n#{e}")
        end
      end

      # End Class
    end
  end
end
