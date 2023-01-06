require "cocoapods"
require "xcodeproj"

require "cocoapods-zource/pod/zource_pod.rb"
require "cocoapods-zource/pod/aggregation/zource_aggregrated_pod.rb"
require "cocoapods-zource/pod/config+zource.rb"

module CocoapodsZource
  class Maker
    include Pod

    attr_accessor :zource_pods
    attr_reader :configuration
    attr_reader :is_aggregation
    attr_reader :should_generate_project
    attr_reader :should_construct_project
    attr_reader :should_arm64_simulator
    attr_reader :should_make_xcframework
    attr_reader :should_make_binary

    def initialize(configuration,
                   is_aggregation,
                   should_generate_project = true,
                   should_construct_project = true,
                   should_arm64_simulator = true,
                   should_make_xcframework = true,
                   should_make_binary = true)
      @configuration = configuration
      @is_aggregation = is_aggregation
      @should_generate_project = should_generate_project
      @should_construct_project = should_construct_project
      @should_arm64_simulator = should_arm64_simulator
      @should_make_xcframework = should_make_xcframework
      @should_make_binary = should_make_binary
      Pod::Config.instance.zource_pods = Hash.new
      @pods_xcodeproj = Xcodeproj::Project.open(Pod::Config.instance.project_pods_root.join("Pods.xcodeproj"))
    end

    public

    def self.backup_project
      project_path = Pod::Config.instance.project_root
      UI.message "Backup #{project_path} => #{project_path}.backup"
      executable = "cp"
      command = Array.new
      command << "-rf"
      command << "#{project_path}"
      command << "#{project_path}.backup"
      raise_on_failure = true
      begin
        Pod::Executable.execute_command(executable, command, raise_on_failure)
      rescue Exception => e
        abort("Backup project exception:\n#{e}")
      end
    end

    def self.make_zource_directory(should_remake = false)
      if should_remake && Pod::Config.instance.zource_root.exist? && !Pod::Config.instance.zource_root.to_s.eql?("/")
        Pod::Config.instance.zource_root.rmtree
      end
      Pod::Config.instance.zource_root.mkpath if !Pod::Config.instance.zource_root.exist?
    end

    def produce
      setup_zource_pods!
      if @is_aggregation
        make_zource_aggregated_pod
      else
        make_zource_pods
      end
    end

    private

    def make_zource_aggregated_pod
      UI.section "==== make zource aggregated pod ====" do
        if !Pod::Config.instance.zource_aggregated_podspec_path.exist?
          abort("Please setup zource aggregrated pod podspec first, template: https://github.com/CocoaPods/pod-template/blob/master/NAME.podspec")
        end
        Pod::Config.instance.zource_pods.values.each {
          |zource_pod|
          zource_pod.save_binary_podspec
        }
        zource_aggregated_pod = CocoapodsZource::ZourceAggregratedPod.new
        zource_aggregated_pod.save_zource_aggregated_pod
        zource_aggregated_pod.save_binary_podspec
        if @should_construct_project
          zource_aggregated_pod.construct_project(@should_arm64_simulator)
        end
        if @should_make_xcframework
          zource_aggregated_pod.compose_xcframeworks
        end
        if @should_make_binary
          zource_aggregated_pod.compress_binary
        end
      end
    end

    def make_zource_pods
      UI.section "==== make zource pods ====" do
        Pod::Config.instance.zource_pods.values.each {
          |zource_pod|
          zource_pod.save_binary_podspec
          if zource_pod.xcodeproject_target.is_a?(Xcodeproj::Project::Object::PBXNativeTarget)
            if @should_generate_project
              zource_pod.generate_project
            end
            if @should_construct_project
              zource_pod.construct_project(@should_arm64_simulator)
            end
            if @should_make_xcframework
              zource_pod.combine_xcframework
            end
            if @should_make_binary
              zource_pod.compress_binary
            end
          end
        }
      end
    end

    def setup_zource_pods!
      UI.section "==== setup zource pods ====" do
        make_zource_pods_from_external_sources!
        make_zource_pods_from_spec_repos!
        setup_zource_pods_xcodeproject_target!
      end
      UI.message "zource pods count: #{Pod::Config.instance.zource_pods.count}".green
      save_zource_pods
    end

    def save_zource_pods
      zource_pods_json = JSON.pretty_generate(Pod::Config.instance.zource_pods)
      File.open(Pod::Config.instance.zource_pods_json_path, "w") do |f|
        f.write(zource_pods_json)
      end
    end

    def setup_zource_pods_xcodeproject_target!
      Pod::Config.instance.zource_pods.values.each {
        |zource_pod|
        @pods_xcodeproj.targets.each {
          |target|
          if target.name == zource_pod.podspec.name
            zource_pod.xcodeproject_target = target
          end
        }
      }
    end

    def make_zource_pods_from_external_sources!
      lockfile = Pod::Config.instance.lockfile  # Pod::Lockfile
      sandbox = Pod::Config.instance.sandbox # Pod::Sandbox
      external_sources_pod = lockfile.internal_data["EXTERNAL SOURCES"] || {}
      external_sources_pod.each {
        |key, value|
        # hash meta
        meta = Hash.new
        meta[:version] = lockfile.version(key).to_s
        meta[:checksum] = lockfile.checksum(key)
        meta = meta.merge(value)
        if meta.has_key?(:path)
          path = Pathname.new(meta[:path])
          if path.absolute?
            meta[:path] = path
          else
            meta[:path] = Pod::Config.instance.project_root.join(path)
          end
        end
        if meta.has_key?(:podspec)
          podspec = Pathname.new(meta[:podspec])
          if podspec.absolute?
            meta[:podspec] = podspec
          else
            meta[:podspec] = Pod::Config.instance.project_root.join(podspec)
          end
        end
        # Pod::Specification
        podspec_path = Pod::Config.instance.sandbox.specifications_root.join("#{key}.podspec.json")
        if !meta[:path].nil?
          podspec_path = meta[:path].join("#{key}.podspec")
        elsif !meta[:podspec].nil?
          podspec_path = meta[:podspec]
        end
        specification = Pod::Specification::from_file(podspec_path)
        abort("Specification not found: #{key}") if specification.nil?
        zource_pod = ZourcePod.new(specification, meta)
        Pod::Config.instance.zource_pods[key] = zource_pod
      }
    end

    def make_zource_pods_from_spec_repos!
      lockfile = Pod::Config.instance.lockfile # Pod::Lockfile
      source_manager = Pod::Config.instance.sources_manager #Pod::Source::Manager
      spec_repo_pods = lockfile.pods_by_spec_repo
      spec_repo_pods.each {
        |source, pod_names|
        pod_source = source_manager.source_with_name_or_url(source) # Pod::Source
        pod_names.each {
          |pod_name|
          # hash meta
          meta = Hash.new
          meta[:version] = lockfile.version(pod_name).to_s
          meta[:checksum] = lockfile.checksum(pod_name)
          meta[:source] = pod_source.url
          # Pod::Specification
          podspec_path = pod_source.specification_path(pod_name, meta[:version])
          specification = Pod::Specification::from_file(podspec_path)
          zource_pod = ZourcePod.new(specification, meta)
          Pod::Config.instance.zource_pods[pod_name] = zource_pod
        }
      }
    end

    # End Class
  end
end
