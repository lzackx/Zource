require "cocoapods"
require "xcodeproj"
# require "cocoapods-zource/pod/podfile"
# require "cocoapods-zource/pod/podspec"
# require "cocoapods-zource/configuration/configuration"

require "cocoapods-zource/maker/zource_pod.rb"

module CocoapodsZource
  class Maker
    include Pod

    attr_accessor :zource_pods
    attr_reader :should_generate_project
    attr_reader :should_construct_project
    attr_reader :should_combine_xcframework
    attr_reader :should_compress_binary

    def initialize(configuration,
                   should_generate_project = true,
                   should_construct_project = true,
                   should_combine_xcframework = true,
                   should_compress_binary = true)
      @configuration = configuration
      @should_generate_project = should_generate_project
      @should_construct_project = should_construct_project
      @should_combine_xcframework = should_combine_xcframework
      @should_compress_binary = should_compress_binary
      @zource_pods = Hash.new
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

    def self.make_zource_directory
      Pod::Config.instance.instance_eval do
        def zource_root
          if @zource_root.nil?
            @zource_root = Pathname.new(File.join(Pod::Config.instance.project_root, ".zource"))
          end
          @zource_root
        end

        def zource_pods_json_path
          if @zource_pods_json_path.nil?
            @zource_pods_json_path = Pathname.new(File.join(zource_root, "zource.pods.json"))
          end
          @zource_pods_json_path
        end
      end
      if Pod::Config.instance.zource_root.exist? && !Pod::Config.instance.zource_root.to_s.eql?("/")
        Pod::Config.instance.zource_root.rmtree
      end
      Pod::Config.instance.zource_root.mkpath
    end

    def setup_zource_pods!
      UI.section "==== setup zource pods ====" do
        make_zource_pods_from_external_sources!
        make_zource_pods_from_spec_repos!
        setup_zource_pods_xcodeproject_target!
      end
      UI.message "zource pods count: #{@zource_pods.count}".green
      save_zource_pods
    end

    def make_zource_pods
      UI.section "==== make zource pods ====" do
        @zource_pods.values.each {
          |zource_pod|
          zource_pod.save_binary_podspec
          if zource_pod.xcodeproject_target.class == Xcodeproj::Project::Object::PBXNativeTarget
            if @should_generate_project
              zource_pod.generate_project
            end
            if @should_construct_project
              zource_pod.construct_project
            end
            if @should_combine_xcframework
              zource_pod.combine_xcframework
            end
            if @should_compress_binary
              zource_pod.compress_binary
            end
          end
        }
      end
    end

    private

    def save_zource_pods
      zource_pods_json = JSON.pretty_generate(@zource_pods)
      File.open(Pod::Config.instance.zource_pods_json_path, "w") do |f|
        f.write(zource_pods_json)
      end
    end

    def setup_zource_pods_xcodeproject_target!
      @zource_pods.values.each {
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
        if !value[:path].nil?
          path = Pathname.new(value[:path])
          if path.absolute?
            meta[:path] = path
          else
            meta[:path] = Pod::Config.instance.project_root.join(path)
          end
        end
        if !value[:podspec].nil?
          podspec = Pathname.new(value[:podspec])
          if podspec.absolute?
            meta[:podspec] = podspec
          else
            meta[:podspec] = Pod::Config.instance.project_root.join(podspec)
          end
        end
        meta[:git] = value[:git] if !value[:git].nil?
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
        @zource_pods[key] = zource_pod
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
          meta[:source] = pod_source
          # Pod::Specification
          podspec_path = pod_source.specification_path(pod_name, meta[:version])
          specification = Pod::Specification::from_file(podspec_path)
          zource_pod = ZourcePod.new(specification, meta)
          @zource_pods[pod_name] = zource_pod
        }
      }
    end

    # End Class
  end
end
