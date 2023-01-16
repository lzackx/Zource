require "cocoapods"
require "xcodeproj"
require "json"

require "cocoapods-zource/pod/config+zource.rb"
require "cocoapods-zource/pod/project_generator.rb"
require "cocoapods-zource/pod/project_constructor.rb"
require "cocoapods-zource/pod/xcframework_combinator.rb"
require "cocoapods-zource/pod/binary_compressor.rb"
require "cocoapods-zource/pod/binary_pod_publisher.rb"

module CocoapodsZource
  class ZourcePod

    # Original
    # Pod::Specification
    attr_accessor :podspec
    # Hash
    attr_accessor :meta
    # xcodeproj, Xcodeproj::Project::Object::PBXAggregateTarget
    attr_accessor :xcodeproject_target

    # Calculated
    attr_reader :zource_path
    attr_reader :zource_pod_project_directory
    attr_reader :zource_pod_archived_directory
    attr_reader :zource_pod_binary_directory
    attr_reader :zource_pod_product_directory
    attr_reader :zip_path
    attr_reader :binary_podspec_path
    attr_reader :binary_podspec
    attr_reader :project_deployment_target

    def initialize(podspec, meta)
      if podspec.is_a?(Pod::Specification)
        @podspec = podspec
      elsif podspec.is_a?(String)
        @podspec = Pod::Specification.from_file(podspec)
      else
      end
      @meta = meta
      # Directory Path
      @zource_pod_directory = Pod::Config.instance.zource_root.join(@podspec.name)
      @zource_pod_project_directory = @zource_pod_directory.join("project")
      @zource_pod_archived_directory = @zource_pod_directory.join("archived")
      @zource_pod_binary_directory = @zource_pod_directory.join("binary")
      @zource_pod_product_directory = @zource_pod_directory.join("product")
      # File path
      @zip_path = @zource_pod_product_directory.join("#{@podspec.name}.zip")
      @binary_podspec_path = @zource_pod_product_directory.join("#{@podspec.name}.podspec.json")
      setup_path
    end

    def self.from_hash(zource_pod_hash)
      abort("ZourcePod from_hash error: #{zource_pod_hash}") if zource_pod_hash[:podspec].nil?
      zource_pod = ZourcePod.new(zource_pod_hash[:podspec], zource_pod_hash[:meta])
    end

    public

    # JSON
    def as_json(options = {})
      {
        podspec: @podspec.defined_in_file,
        meta: @meta,
        xcodeproject_target: "#{@xcodeproject_target&.name}(#{@xcodeproject_target&.class})",
        zource_pod_directory: @zource_pod_directory,
        zource_pod_project_directory: @zource_pod_project_directory,
        zource_pod_archived_directory: @zource_pod_archived_directory,
        zource_pod_binary_directory: @zource_pod_binary_directory,
        zource_pod_product_directory: @zource_pod_product_directory,
        zip_path: @zip_path,
        binary_podspec_path: @binary_podspec_path,
      }
    end

    def to_json(*options)
      as_json(*options).to_json(*options)
    end

    # Handlers
    def save_binary_podspec
      podspec_json = JSON.pretty_generate(binary_podspec)
      File.open(@binary_podspec_path, "w") do |f|
        f.write(podspec_json)
      end
    end

    def generate_project
      Pod::UI.section "==== Start generating #{@podspec.name} project ====" do
        generator = ProjectGenerator.new(self)
        generator.generate
      end
    end

    def construct_project(should_arm64_simulator)
      Pod::UI.section "==== Start constructing #{@podspec.name} project ====" do
        constructor = ProjectConstructor.new(self)
        constructor.construct(should_arm64_simulator)
      end
    end

    def combine_xcframework
      Pod::UI.section "==== Start combining #{@podspec.name} xcframework ====" do
        combinator = XCFrameworkCombinator.new(self)
        combinator.combine
      end
    end

    def compress_binary
      Pod::UI.section "==== Start compressing #{@podspec.name} binary ====" do
        compressor = BinaryCompressor.new(self)
        compressor.compress
      end
    end

    def publish_binary
      Pod::UI.section "==== Start publish #{@podspec.name} binary ====" do
        publisher = BinaryPodPublisher.new(self)
        publisher.publish
      end
    end

    # Getter
    def project_deployment_target
      if @project_deployment_target.nil?
        xcodeproj = nil
        Pod::Config.instance.project_root.entries.each {
          |entry|
          if File.extname(entry) == ".xcodeproj"
            xcodeproject_path = Pod::Config.instance.project_root.join(entry)
            xcodeproj = Xcodeproj::Project.open(xcodeproject_path)
            break
          end
        }
        abort("xcodeproj file not found") if xcodeproj.nil?
        @project_deployment_target = xcodeproj.targets.first.build_configurations.last.build_settings["IPHONEOS_DEPLOYMENT_TARGET"]
      end
      @project_deployment_target
    end

    def binary_podspec
      if @binary_podspec.nil?
        podspec_hash = @podspec.to_hash
        # Have to clear or the aggregated target (etc RN) will integrate redundant codes to project
        clear_podspec_attributes(podspec_hash)
        @binary_podspec = Pod::Specification.from_hash(podspec_hash)
        if @xcodeproject_target.class == Xcodeproj::Project::Object::PBXNativeTarget
          # 1. resource / resources / resource_bundles
          copy_resources_from(self, @podspec)
          # 2. vendored_frameworks and vendored_libraries
          copy_vendored_from(self, @podspec)
          # 3. prefix_header_file
          copy_prefix_header_file_from(self, @podspec)
          # 4. add Zource subspec
          zource_subspec_name = "Zource"
          zource_subspec = @binary_podspec&.subspec(zource_subspec_name)
          xcframework_name = "#{@binary_podspec.module_name}.xcframework"
          zource_subspec&.vendored_frameworks = xcframework_name
          # Subspecs
          if @binary_podspec&.default_subspecs == :none
            # 5.1 set default subspec to Zource subspec
            @binary_podspec&.default_subspecs = zource_subspec_name
            # 5.2 depend Zource subspec if there is any other subspec
            @binary_podspec&.subspecs.each {
              |ss|
              next if ss.name == zource_subspec.name
              ss.dependency(zource_subspec.name)
            }
          else
            # 5.3 Let default subspecs depend on zource subspec
            @binary_podspec&.subspecs.each {
              |ss|
              subspec_name = ss.name[@binary_podspec.name.length + 1, ss.name.length]
              if @binary_podspec&.default_subspecs.include?(subspec_name)
                next if ss == zource_subspec.name
                ss.dependency(zource_subspec.name)
              end
            }
          end

          # 6 order subspecs
          @binary_podspec&.subspecs.reverse!
          # 7. description
          @binary_podspec&.description = JSON.pretty_generate(@podspec.to_json)
          # 8. source
          source = Hash.new
          source[:http] = CocoapodsZource::Configuration.configuration.binary_download_url(@binary_podspec.name, @binary_podspec.version)
          @binary_podspec&.source = source
          # 9. static_framework
          @binary_podspec&.static_framework = true
          # 10. license
          @binary_podspec&.license = "MIT"
          # # 11. static_framework
          # @binary_podspec&.module_name = @binary_podspec.name if @binary_podspec&.module_name.nil?
          # Fix Swift compiler bug about .swiftinterface file,
          # https://github.com/apple/swift/issues/43510, https://github.com/apple/swift/issues/56573
          # module_name = "Zource#{key}"
          # if !spec.to_hash["module_name"].nil?
          #   module_name = "Zource#{spec.to_hash["module_name"]}"
          # end
          # spec&.module_name = module_name
          # fix_swiftinterface(spec, key, value)
        end
      end
      @binary_podspec
    end

    protected

    def setup_path
      @zource_pod_directory.mkdir if !@zource_pod_directory.exist?
      @zource_pod_project_directory.mkdir if !@zource_pod_project_directory.exist?
      @zource_pod_archived_directory.mkdir if !@zource_pod_archived_directory.exist?
      @zource_pod_binary_directory.mkdir if !@zource_pod_binary_directory.exist?
      @zource_pod_product_directory.mkdir if !@zource_pod_product_directory.exist?
    end

    def clear_podspec_attributes(spec_hash)
      spec_hash.delete("source_files")
      spec_hash.delete("script_phases")
      spec_hash.delete("compiler_flags")
      spec_hash.delete("exclude_files")
      spec_hash.delete("public_header_files")
      spec_hash.delete("project_header_files")
      spec_hash.delete("private_header_files")
      spec_hash.delete("module_map")
      spec_hash.delete("header_mappings_dir")
      spec_hash.delete("preserve_paths")
      spec_hash.delete("pod_target_xcconfig")
      spec_hash.delete("prepare_command")
      spec_hash.delete("license")
      # spec_hash.delete("ios")
      # spec_hash.delete("osx")
      # spec_hash.delete("tvos")
      # spec_hash.delete("watchos")
      spec_hash["subspecs"].each {
        |ss|
        clear_podspec_attributes(ss)
      } unless spec_hash["subspecs"].nil?
    end

    def copy_resource(podspec, resource_path)
      # Path
      resource_path = File.join(".", resource_path)
      resource_path_prefix = Pod::Config.instance.sandbox_root.join(podspec.name)
      if !@meta[:path].nil?
        resource_path_prefix = podspec.defined_in_file.dirname
      end
      resource_absolute_path = resource_path_prefix.join(resource_path)
      zource_pod_binary_resource_path = @zource_pod_binary_directory.join(resource_path)
      FileUtils.mkdir_p(zource_pod_binary_resource_path.dirname) if !zource_pod_binary_resource_path.dirname.exist?
      # Copy
      Dir::glob(resource_absolute_path).each {
        |f|
        next if File.basename(f).eql?("*") || File.basename(f).eql?("**")
        f_relative_path = File.join(".", f[resource_path_prefix.to_s.length...f.length])
        zource_pod_resource_path = @zource_pod_binary_directory.join(f_relative_path)
        if !zource_pod_resource_path.dirname.exist?
          FileUtils.mkdir_p(zource_pod_resource_path.dirname)
        end
        FileUtils.cp_r(f, zource_pod_resource_path.dirname, verbose: true)
      }
    end

    def copy_resources_from(source_zource_pod, specification)
      # resource
      if specification.to_hash.key?("resource")
        resource_path = specification.to_hash["resource"]
        copy_resource(source_zource_pod.podspec, resource_path)
      end
      # resources
      if specification.to_hash.key?("resources")
        resources = specification.to_hash["resources"]
        if resources.is_a?(String)
          resource_path = resources
          copy_resource(source_zource_pod.podspec, resource_path)
        elsif resources.is_a?(Array)
          resources.each {
            |resource|
            resource_path = resource
            copy_resource(source_zource_pod.podspec, resource_path)
          }
        end
      end
      # resource_bundle
      if specification.to_hash.key?("resource_bundle")
        resource_bundle = specification.to_hash["resource_bundle"]
        resource_bundle.each {
          |key, value|
          resource_path = value
          copy_resource(source_zource_pod.podspec, resource_path)
        }
      end
      # resource_bundles
      if specification.to_hash.key?("resource_bundles")
        resource_bundles = specification.to_hash["resource_bundles"]
        resource_bundles.each {
          |key, value|
          if value.is_a?(String)
            resource_path = value
            copy_resource(source_zource_pod.podspec, resource_path)
          elsif value.is_a?(Array)
            zource_resources = Array.new
            value.each {
              |v|
              resource_path = v
              copy_resource(source_zource_pod.podspec, resource_path)
            }
          end
        }
      end
      # Recursively
      specification.subspecs.each {
        |ss|
        copy_resources_from(source_zource_pod, ss)
      } unless specification.subspecs.empty?
    end

    def copy_vendored_from(source_zource_pod, specification)
      # vendored_frameworks
      if specification.to_hash.key?("vendored_frameworks")
        resources = specification.to_hash["vendored_frameworks"]
        if resources.is_a?(String)
          resource_path = resources
          copy_resource(source_zource_pod.podspec, resource_path)
        elsif resources.is_a?(Array)
          resources.each {
            |resource|
            resource_path = resource
            copy_resource(source_zource_pod.podspec, resource_path)
          }
        end
      end
      # vendored_libraries
      if specification.to_hash.key?("vendored_libraries")
        resources = specification.to_hash["vendored_libraries"]
        if resources.is_a?(String)
          resource_path = resources
          copy_resource(source_zource_pod.podspec, resource_path)
        elsif resources.is_a?(Array)
          resources.each {
            |resource|
            resource_path = resource
            copy_resource(source_zource_pod.podspec, resource_path)
          }
        end
      end
      # Recursively
      specification.subspecs.each {
        |ss|
        copy_vendored_from(source_zource_pod, ss)
      } unless specification.subspecs.empty?
    end

    def copy_prefix_header_file_from(source_zource_pod, specification)
      # vendored_frameworks
      if specification.to_hash.key?("prefix_header_file")
        resources = specification.to_hash["prefix_header_file"]
        if resources.is_a?(String)
          resource_path = resources
          copy_resource(source_zource_pod.podspec, resource_path)
        elsif resources.is_a?(Array)
          resources.each {
            |resource|
            resource_path = resource
            copy_resource(source_zource_pod.podspec, resource_path)
          }
        end
      end
      # Recursively
      specification.subspecs.each {
        |ss|
        copy_prefix_header_file_from(source_zource_pod, ss)
      } unless specification.subspecs.empty?
    end

    # End
  end
end
