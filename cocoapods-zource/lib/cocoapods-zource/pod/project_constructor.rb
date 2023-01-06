require "cocoapods"

module CocoapodsZource
  class ZourcePod
    class ProjectConstructor
      attr_reader :zource_pod
      attr_reader :sandbox_directory
      attr_reader :scheme

      def initialize(zource_pod)
        @zource_pod = zource_pod
        @sandbox_directory = @zource_pod.zource_pod_project_directory.join("Pods")
        @scheme = Pod::Config.instance.podfile.target_definitions["Pods"].children.first.label
      end

      # xcodebuild [-project <projectname>] -scheme <schemeName> [-destination <destinationspecifier>]... [-configuration <configurationname>] [-arch <architecture>]... [-sdk [<sdkname>|<sdkpath>]] [-showBuildSettings [-json]] [-showdestinations] [<buildsetting>=<value>]... [<buildaction>]...
      def construct(should_arm64_simulator)
        construct_ios
        construct_ios_simulator(should_arm64_simulator)
      end

      def construct_ios
        executable = "xcodebuild"
        command = Array.new
        command << "clean"
        command << "archive"
        command << "-showBuildTimingSummary"
        command << "-verbose"
        command << "-project"
        command << "#{@sandbox_directory.join("Pods.xcodeproj")}"
        command << "-scheme"
        command << "#{@scheme}"
        command << "-destination"
        command << "generic/platform=iOS"
        command << "-configuration"
        command << "Release"
        command << "-archivePath"
        command << "#{@zource_pod.zource_pod_archived_directory.join("#{@zource_pod.podspec.name}.ios.xcarchive")}"
        command << "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
        command << "SKIP_INSTALL=NO"
        raise_on_failure = true
        begin
          Pod::Executable.execute_command(executable, command, raise_on_failure)
        rescue Exception => e
          abort("construct project exception:\n#{e}")
        end
      end

      def construct_ios_simulator(should_arm64_simulator)
        executable = "xcodebuild"
        command = Array.new
        command << "clean"
        command << "archive"
        command << "-showBuildTimingSummary"
        command << "-verbose"
        command << "-project"
        command << "#{@sandbox_directory.join("Pods.xcodeproj")}"
        command << "-scheme"
        command << "#{@scheme}"
        command << "-destination"
        command << "generic/platform=iOS Simulator"
        command << "-configuration"
        command << "Release"
        command << "-archivePath"
        command << "#{@zource_pod.zource_pod_archived_directory.join("#{@zource_pod.podspec.name}.ios.simulator.xcarchive")}"
        command << "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
        command << "SKIP_INSTALL=NO"
        if should_arm64_simulator == false
          command << "EXCLUDED_ARCHS=arm64"
        end
        raise_on_failure = true
        begin
          Pod::Executable.execute_command(executable, command, raise_on_failure)
        rescue Exception => e
          abort("construct project exception:\n#{e}")
        end
      end

      # End
    end
  end
end
