require "cocoapods"
require "xcodeproj"
require "cocoapods-zource/configuration/configuration"

module CocoapodsZource
  class ZourcePod
    class ProjectGenerator
      attr_reader :zource_pod
      attr_reader :generated_app_project_path
      attr_reader :generated_app_sandbox_path
      attr_reader :consumer
      attr_reader :sandbox
      attr_reader :podfile
      attr_reader :installer

      def initialize(zource_pod)
        @zource_pod = zource_pod
        @generated_app_project_path = @zource_pod.generated_project_path.join("App.xcodeproj")
        @generated_app_sandbox_path = @zource_pod.generated_project_path.join("Pods")
        @consumer = @zource_pod.podspec.consumer(:ios)
        @sandbox = sandbox_for_zource_pod_project
        @podfile = podfile_from_zource_pod_spec
        @installer = Pod::Installer.new(sandbox, podfile)
      end

      def generate
        begin
          setup_environments
          create_app_project
          download_pod
          install_pod
          add_app_project_import
          reset_environments
        rescue Exception => e
          abort("Generate project exception:\n#{e}")
        end
      end

      private

      def sandbox_for_zource_pod_project
        sandbox = Pod::Sandbox.new(@generated_app_sandbox_path)
        zource_pods_hash = JSON.parse(Pod::Config.instance.zource_pods_json_path.read,
                                      { symbolize_names: true })
        zource_pods_hash.each {
          |zource_pod_name, zource_pod_hash|
          zp = ZourcePod.from_hash(zource_pod_hash)
          if !zp.meta[:path].nil?
            sandbox.store_local_path(zp.podspec.name,
                                     zp.meta[:path],
                                     true)
          end
        }
        sandbox
      end

      # @param  [Boolean] use_frameworks
      #         whether frameworks should be used for the installation
      #
      # @param [Array<String>] test_spec_names
      #         the test spec names to include in the podfile.
      #
      # @return [Podfile] a podfile that requires the specification on the
      #         current platform.
      #
      # @note   The generated podfile takes into account whether the linter is
      #         in local mode.
      #
      def podfile_from_zource_pod_spec(use_frameworks = true,
                                       use_modular_headers = true,
                                       use_static_frameworks = true)
        urls = Array.new()
        if !CocoapodsZource::Configuration::configuration.configuration.repo_privacy_url.nil?
          urls << CocoapodsZource::Configuration::configuration.configuration.repo_privacy_url
        end
        urls << Pod::TrunkSource::TRUNK_REPO_URL
        zource_pod = @zource_pod
        platform_name = @consumer.platform_name
        Pod::Podfile.new do
          install! "cocoapods",
                   :deterministic_uuids => false,
                   :warn_for_unused_master_specs_repo => false,
                   :preserve_pod_file_structure => true
          # By default inhibit warnings for all pods, except the one being validated.
          inhibit_all_warnings!
          urls.each { |u| source(u) }
          target "App" do
            if use_static_frameworks
              use_frameworks!(:linkage => :static)
            else
              use_frameworks!(use_frameworks)
            end
            use_modular_headers! if use_modular_headers
            platform(platform_name, zource_pod.project_deployment_target)
            # pod
            if !zource_pod.meta[:podspec].nil?
              pod zource_pod.podspec.name,
                  :podspec => "#{zource_pod.meta[:podspec]}",
                  :inhibit_warnings => false
            elsif !zource_pod.meta[:path].nil?
              pod zource_pod.podspec.name,
                  :path => "#{zource_pod.meta[:path]}",
                  :inhibit_warnings => false
            elsif !zource_pod.meta[:git].nil?
              pod zource_pod.podspec.name,
                  :git => "#{zource_pod.meta[:git]}",
                  :branch => "#{zource_pod.meta[:version]}",
                  :inhibit_warnings => false
            else
              pod zource_pod.podspec.name, :inhibit_warnings => false
            end
            # dependency pod
            zource_pods_hash = JSON.parse(Pod::Config.instance.zource_pods_json_path.read,
                                          { symbolize_names: true })
            zource_pods_hash = zource_pods_hash.each {
              |zource_pod_name, zource_pod_hash|
              next if zource_pod_name.to_s == zource_pod.podspec.name
              dependency_zource_pod = ZourcePod.from_hash(zource_pod_hash)
              if !dependency_zource_pod.meta[:path].nil? # include
                pod dependency_zource_pod.podspec.name,
                    :path => "#{dependency_zource_pod.meta[:path]}",
                    :inhibit_warnings => false
              elsif !dependency_zource_pod.meta[:podspec].nil? # external
                pod dependency_zource_pod.podspec.name,
                    :podspec => "#{dependency_zource_pod.meta[:podspec]}",
                    :inhibit_warnings => false
              end
            }
          end
          # Xcode14 & CocoaPods1.11.3 issue: https://github.com/CocoaPods/CocoaPods/issues/11402
          def post_install_xcode14_pods_project_code_sign(installer)
            installer.pods_project.targets.each do |target|
              if target.respond_to?(:product_type) and target.product_type == "com.apple.product-type.bundle"
                target.build_configurations.each do |config|
                  config.build_settings["CODE_SIGNING_ALLOWED"] = "NO"
                end
              end
            end
          end

          post_install do |installer|
            # =================== Xcode14 & CocoaPods1.11.3 issue =================
            post_install_xcode14_pods_project_code_sign(installer)
          end
        end
      end

      def setup_environments
        # setup Pod::Config.instance
        @original_config = Pod::Config.instance.clone
        Pod::Config.instance.installation_root = Pathname.new(@zource_pod.generated_project_path)
      end

      def reset_environments
        Pod::Config.instance = @original_config
      end

      def create_app_project
        app_project = Xcodeproj::Project.new(@generated_app_project_path)
        app_target = Pod::Generator::AppTargetHelper.add_app_target(app_project,
                                                                    @consumer.platform_name,
                                                                    @zource_pod.project_deployment_target)
        info_plist_path = app_project.path.dirname.+ "App/App-Info.plist"
        Pod::Installer::Xcode::PodsProjectGenerator::TargetInstallerHelper
          .create_info_plist_file_with_sandbox(@sandbox,
                                               info_plist_path,
                                               app_target,
                                               "1.0.0",
                                               Pod::Platform.new(@consumer.platform_name),
                                               :appl,
                                               :build_setting_value => "$(SRCROOT)/App/App-Info.plist")
        Pod::Generator::AppTargetHelper.add_swift_version(app_target, derived_swift_version)
        app_target.build_configurations.each do |config|
          # Lint will fail if a AppIcon is set but no image is found with such name
          # Happens only with Static Frameworks enabled but shouldn't be set anyway
          config.build_settings.delete("ASSETCATALOG_COMPILER_APPICON_NAME")
          # Ensure this is set generally but we have seen an issue with ODRs:
          # see: https://github.com/CocoaPods/CocoaPods/issues/10933
          config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "org.cocoapods.${PRODUCT_NAME:rfc1034identifier}"
        end
        app_project.save
        app_project.recreate_user_schemes
      end

      # @return [String] The derived Swift version to use for validation. The order of precedence is as follows:
      #         - The `--swift-version` parameter is always checked first and honored if passed.
      #         - The `swift_versions` DSL attribute within the podspec, in which case the latest version is always chosen.
      #         - The Swift version within the `.swift-version` file if present.
      #         - If none of the above are set then the `#DEFAULT_SWIFT_VERSION` is used.
      #
      def derived_swift_version
        derived_swift_version ||= begin
            if version = @zource_pod.podspec.swift_versions.max
              version.to_s
            else
              "5.0".freeze
            end
          end
      end

      def download_pod
        @installer.use_default_plugins = false
        @installer.has_dependencies = !@zource_pod.podspec.dependencies.empty?
        %i[prepare
           resolve_dependencies
           download_dependencies
           write_lockfiles].each {
          |m|
          @installer.send(m)
        }
      end

      # It creates a podfile in memory and builds a library containing the pod
      # for all available platforms with xcodebuild.
      #
      def install_pod
        %i(validate_targets generate_pods_project integrate_user_project
           perform_post_install_actions).each { |m| @installer.send(m) }

        configure_pod_targets(@installer.target_installation_results)
        validate_dynamic_framework_support(@installer.aggregate_targets,
                                           @zource_pod.project_deployment_target)
        @installer.pods_project.save
      end

      # @param [Array<Hash{String, TargetInstallationResult}>] target_installation_results
      #        The installation results to configure
      #
      def configure_pod_targets(target_installation_results)
        target_installation_results.first.values.each do |pod_target_installation_result|
          pod_target = pod_target_installation_result.target
          native_target = pod_target_installation_result.native_target
          native_target.build_configuration_list.build_configurations.each do |build_configuration|
            (build_configuration.build_settings["OTHER_CFLAGS"] ||= "$(inherited)") << " -Wincomplete-umbrella"
            if pod_target.uses_swift?
              # The Swift version for the target being validated can be overridden by `--swift-version` or the
              # `.swift-version` file so we always use the derived Swift version.
              #
              # For dependencies, if the derived Swift version is supported then it is the one used. Otherwise, the Swift
              # version for dependencies is inferred by the target that is integrating them.
              swift_version = if pod_target == validation_pod_target
                  derived_swift_version
                else
                  pod_target.spec_swift_versions.map(&:to_s).find do |v|
                    v == derived_swift_version
                  end || pod_target.swift_version
                end
              build_configuration.build_settings["SWIFT_VERSION"] = swift_version
            end
          end
          pod_target_installation_result.test_specs_by_native_target.each do |test_native_target, test_spec|
            if pod_target.uses_swift_for_spec?(test_spec)
              test_native_target.build_configuration_list.build_configurations.each do |build_configuration|
                swift_version = pod_target == validation_pod_target ? derived_swift_version : pod_target.swift_version
                build_configuration.build_settings["SWIFT_VERSION"] = swift_version
              end
            end
          end
        end
      end

      # Produces an error of dynamic frameworks were requested but are not supported by the deployment target
      #
      # @param [Array<AggregateTarget>] aggregate_targets
      #        The aggregate targets installed by the installer
      #
      # @param [String,Version] deployment_target
      #        The deployment target of the installation
      #
      def validate_dynamic_framework_support(aggregate_targets, deployment_target)
        return unless consumer.platform_name == :ios
        return unless deployment_target.nil? || Pod::Version.new(deployment_target).major < 8
        aggregate_targets.each do |target|
          if target.pod_targets.any?(&:uses_swift?)
            uses_xctest = target.spec_consumers.any? { |c| (c.frameworks + c.weak_frameworks).include? "XCTest" }
            error("swift", "Swift support uses dynamic frameworks and is therefore only supported on iOS > 8.") unless uses_xctest
          end
        end
      end

      def add_app_project_import
        app_project = Xcodeproj::Project.open(@generated_app_project_path)
        app_target = app_project.targets.first
        pod_target = validation_pod_target
        Pod::Generator::AppTargetHelper.add_app_project_import(app_project, app_target, pod_target, @consumer.platform_name)
        Pod::Generator::AppTargetHelper.add_empty_swift_file(app_project, app_target) if @installer.pod_targets.any?(&:uses_swift?)
        app_project.save
        Xcodeproj::XCScheme.share_scheme(app_project.path, "App")
        # Share the pods xcscheme only if it exists. For pre-built vendored pods there is no xcscheme generated.
        Xcodeproj::XCScheme.share_scheme(@installer.pods_project.path, pod_target.label) if shares_pod_target_xcscheme?(pod_target)
      end

      # Returns the pod target for the pod being validated. Installation must have occurred before this can be invoked.
      #
      def validation_pod_target
        @installer.pod_targets.find { |pt| pt.pod_name == @zource_pod.podspec.root.name }
      end

      def shares_pod_target_xcscheme?(pod_target)
        Pathname.new(@installer.pods_project.path + pod_target.label).exist?
      end

      # Class End
    end
  end
end
