require "cocoapods"

module CocoapodsZource
  class ZourcePod
    class ProjectConstructor
      attr_reader :zource_pod
      attr_reader :generated_app_project_path
      attr_reader :generated_app_sandbox_path

      def initialize(zource_pod)
        @zource_pod = zource_pod
        @generated_app_project_path = @zource_pod.generated_project_path.join("App.xcodeproj")
        @generated_app_sandbox_path = @zource_pod.generated_project_path.join("Pods")
      end

      # xcodebuild [-project <projectname>] -scheme <schemeName> [-destination <destinationspecifier>]... [-configuration <configurationname>] [-arch <architecture>]... [-sdk [<sdkname>|<sdkpath>]] [-showBuildSettings [-json]] [-showdestinations] [<buildsetting>=<value>]... [<buildaction>]...
      def construct
        construct_ios
        construct_ios_simulator
      end

      def construct_ios
        executable = "xcodebuild"
        command = Array.new
        command << "clean"
        command << "archive"
        command << "-showBuildTimingSummary"
        command << "-verbose"
        command << "-project"
        command << "#{@generated_app_sandbox_path.join("Pods.xcodeproj")}"
        command << "-scheme"
        command << "Pods-App"
        command << "-destination"
        command << "generic/platform=iOS"
        command << "-configuration"
        command << "Release"
        command << "-archivePath"
        command << "#{@zource_pod.archived_path.join("#{@zource_pod.podspec.name}.ios.xcarchive")}"
        command << "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
        command << "SKIP_INSTALL=NO"
        raise_on_failure = true
        begin
          Pod::Executable.execute_command(executable, command, raise_on_failure)
        rescue Exception => e
          abort("construct project exception:\n#{e}")
        end
      end

      def construct_ios_simulator
        executable = "xcodebuild"
        command = Array.new
        command << "clean"
        command << "archive"
        command << "-showBuildTimingSummary"
        command << "-verbose"
        command << "-project"
        command << "#{@generated_app_sandbox_path.join("Pods.xcodeproj")}"
        command << "-scheme"
        command << "Pods-App"
        command << "-destination"
        command << "generic/platform=iOS Simulator"
        command << "-configuration"
        command << "Release"
        command << "-archivePath"
        command << "#{@zource_pod.archived_path.join("#{@zource_pod.podspec.name}.ios.simulator.xcarchive")}"
        command << "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
        command << "SKIP_INSTALL=NO"
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
