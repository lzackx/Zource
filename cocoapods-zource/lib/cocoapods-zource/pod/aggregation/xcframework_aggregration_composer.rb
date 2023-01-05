require "cocoapods"

module CocoapodsZource
  class ZourcePod
    class XCFrameworkAggregrationComposer
      attr_reader :zource_pod
      attr_reader :xcframework_output_path

      def initialize(zource_pod)
        @zource_pod = zource_pod
      end

      def compose
        Pod::Config.instance.zource_pods.each {
          |zource_pod_name, zource_pod|
          module_name = zource_pod_name
          if !zource_pod.podspec&.module_name.nil?
            module_name = zource_pod.podspec.module_name
          end
          if JSON.parse(@zource_pod.binary_podspec.dependencies.to_json).include?(module_name)
            next
          end
          ios_archived_path = @zource_pod.zource_pod_archived_directory.join("#{@zource_pod.podspec.name}.ios.xcarchive").join("Products").join("Library").join("Frameworks").join("#{module_name}.framework")
          ios_simulator_archived_path = @zource_pod.zource_pod_archived_directory.join("#{@zource_pod.podspec.name}.ios.simulator.xcarchive").join("Products").join("Library").join("Frameworks").join("#{module_name}.framework")
          if !ios_archived_path.exist? || !ios_simulator_archived_path.exist?
            next
          end
          output = @zource_pod.zource_pod_binary_directory.join("#{module_name}.xcframework")
          Pod::UI.message("#{zource_pod_name} => #{output}")
          if output.exist?
            # Some podspec may use [header_dir] of Pod::Specification to specify module_name, which let themselves have no framework product
            next
          end
          compose_xcframeworks_of_archived(output, ios_archived_path, ios_simulator_archived_path)
        }
      end

      #   OVERVIEW: Utility for packaging multiple build configurations of a given library or framework into a single xcframework.
      #   USAGE:
      #   xcodebuild -create-xcframework -framework <path> [-framework <path>...] -output <path>
      #   xcodebuild -create-xcframework -library <path> [-headers <path>] [-library <path> [-headers <path>]...] -output <path>
      #   OPTIONS:
      #   -archive <path>                 Adds a framework or library from the archive at the given <path>. Use with -framework or -library.
      #   -framework <path|name>          Adds a framework from the given <path>.
      #                                   When used with -archive, this should be the name of the framework instead of the full path.
      #   -library <path|name>            Adds a static or dynamic library from the given <path>.
      #                                   When used with -archive, this should be the name of the library instead of the full path.
      #   -headers <path>                 Adds the headers from the given <path>. Only applicable with -library.
      #   -debug-symbols <path>           Adds the debug symbols (dSYMs or bcsymbolmaps) from the given <path>. Can be applied multiple times. Must be used with -framework or -library.
      #   -output <path>                  The <path> to write the xcframework to.
      #   -allow-internal-distribution    Specifies that the created xcframework contains information not suitable for public distribution.
      #   -help                           Show this help content.
      def compose_xcframeworks_of_archived(output,
                                           ios_archived_path,
                                           ios_simulator_archived_path)
        executable = "xcodebuild"
        command = Array.new
        command << "-create-xcframework"
        command << "-output"
        command << "#{output}"
        command << "-framework"
        command << "#{ios_archived_path}"
        command << "-framework"
        command << "#{ios_simulator_archived_path}"
        raise_on_failure = true
        begin
          Pod::Executable.execute_command(executable, command, raise_on_failure)
        rescue Exception => e
          abort("Constitute Xcframeworks exception:\n#{e}")
        end
      end
    end
  end
end
