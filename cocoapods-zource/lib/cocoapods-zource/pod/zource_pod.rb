require "cocoapods"
require "xcodeproj"
require "json"

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
    attr_reader :generated_project_path
    attr_reader :archived_path
    attr_reader :zource_pod_binary_path
    attr_reader :zource_pod_product_path
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
      @zource_pod_path = Pod::Config.instance.zource_root.join(@podspec.name)
      @generated_project_path = @zource_pod_path.join("project")
      @archived_path = @zource_pod_path.join("archived")
      @zource_pod_binary_path = @zource_pod_path.join("binary")
      @zource_pod_product_path = @zource_pod_path.join("product")
      # File path
      @zip_path = @zource_pod_product_path.join("#{@podspec.name}.zip")
      @binary_podspec_path = @zource_pod_product_path.join("#{@podspec.name}.podspec.json")
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
        xcodeproject_target: "#{@xcodeproject_target.name}(#{@xcodeproject_target.class})",
        zource_pod_path: @zource_pod_path,
        generated_project_path: @generated_project_path,
        archived_path: @archived_path,
        zource_pod_binary_path: @zource_pod_binary_path,
        zource_pod_product_path: @zource_pod_product_path,
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

    def construct_project
      Pod::UI.section "==== Start constructing #{@podspec.name} project ====" do
        constructor = ProjectConstructor.new(self)
        constructor.construct
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
        if @xcodeproject_target.class == Xcodeproj::Project::Object::PBXNativeTarget
          podspec_hash = @podspec.to_hash
          clear_podspec_attributes(podspec_hash)
          @binary_podspec = Pod::Specification.from_hash(podspec_hash)
          # 1 add Zource subspec
          zource_subspec_name = "Zource"
          zource_subspec = @binary_podspec&.subspec(zource_subspec_name)
          xcframework_name = "#{@binary_podspec.name}.xcframework"
          zource_subspec&.vendored_frameworks = xcframework_name
          # 2 set default subspec to Zource subspec
          @binary_podspec&.default_subspecs = zource_subspec_name
          # 3 depend Zource subspec if there is any other subspec
          @binary_podspec&.subspecs.each {
            |ss|
            next if ss.name == zource_subspec.name
            ss.dependency(zource_subspec.name)
          }
          # 4 order subspecs
          @binary_podspec&.subspecs.reverse!
          # 5. description
          description = Hash.new
          description[:version] = @meta[:version]
          description[:checksum] = @meta[:checksum]
          description[:git] = @meta[:git] if !@meta[:git].nil?
          description[:source] = @meta[:source] if !@meta[:source].nil?
          @binary_podspec&.description = JSON.pretty_generate(description)
          # 6. source
          source = Hash.new
          source[:http] = CocoapodsZource::Configuration.configuration.binary_download_url(@binary_podspec.name, @meta[:version])
          @binary_podspec&.source = source
          # 7. static_framework
          @binary_podspec&.static_framework = true
          # 8. static_framework
          @binary_podspec&.module_name = @binary_podspec.name if @binary_podspec&.module_name.nil?
          # 9. license
          @binary_podspec&.license = "MIT"
          # 10. resource / resources / resource_bundles
          copy_resource_if_needed
          # Fix Swift compiler bug about .swiftinterface file,
          # https://github.com/apple/swift/issues/43510, https://github.com/apple/swift/issues/56573
          # module_name = "Zource#{key}"
          # if !spec.to_hash["module_name"].nil?
          #   module_name = "Zource#{spec.to_hash["module_name"]}"
          # end
          # spec&.module_name = module_name
          # fix_swiftinterface(spec, key, value)
        else
          @binary_podspec = @podspec
        end
      end
      @binary_podspec
    end

    private

    def setup_path
      @zource_pod_path.mkdir if !@zource_pod_path.exist?
      @generated_project_path.mkdir if !@generated_project_path.exist?
      @archived_path.mkdir if !@archived_path.exist?
      @zource_pod_binary_path.mkdir if !@zource_pod_binary_path.exist?
      @zource_pod_product_path.mkdir if !@zource_pod_product_path.exist?
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
      # spec_hash.delete("ios")
      # spec_hash.delete("osx")
      # spec_hash.delete("tvos")
      # spec_hash.delete("watchos")
      spec_hash["subspecs"].each {
        |ss|
        clear_podspec_attributes(ss)
      } unless spec_hash["subspecs"].nil?
    end

    def copy_resource_if_needed
      # resource
      if @binary_podspec.to_hash.key?("resource")
        resource_path = @binary_podspec.to_hash["resource"]
        copy_resource(resource_path)
      end
      # resources
      if @binary_podspec.to_hash.key?("resources")
        resources = @binary_podspec.to_hash["resources"]
        if resources.is_a?(String)
          resource_path = resources
          copy_resource(resource_path)
        elsif resources.is_a?(Array)
          resources.each {
            |resource|
            resource_path = resource
            copy_resource(resource_path)
          }
        end
      end
      # resource_bundles
      if @binary_podspec.to_hash.key?("resource_bundles")
        resource_bundles = @binary_podspec.to_hash["resource_bundles"]
        resource_bundles.each {
          |key, value|
          if value.is_a?(String)
            resource_path = value
            copy_resource(resource_path)
          elsif value.is_a?(Array)
            zource_resources = Array.new
            value.each {
              |v|
              resource_path = v
              copy_resource(resource_path)
            }
          end
        }
      end
    end

    def copy_resource(resource_path)
      # Path
      resource_path = File.join(".", resource_path)
      resource_path_prefix = Pod::Config.instance.sandbox_root.join(@podspec.name)
      if !@meta[:path].nil?
        resource_path_prefix = @podspec.defined_in_file.dirname
      end
      resource_absolute_path = resource_path_prefix.join(resource_path)
      zource_pod_binary_resource_path = @zource_pod_binary_path.join(resource_path)
      FileUtils.mkdir_p(zource_pod_binary_resource_path.to_s) if !zource_pod_binary_resource_path.exist?
      # Copy
      Dir::glob(resource_absolute_path).each {
        |f|
        next if File.basename(f).eql?("*") || File.basename(f).eql?("**")
        f_relative_path = File.join(".", f[resource_path_prefix.to_s.length...f.length])
        zource_pod_resource_path = @zource_pod_binary_path.join(f_relative_path)
        if !zource_pod_resource_path.exist?
          FileUtils.mkdir_p(zource_pod_resource_path)
        end
        FileUtils.cp_r(f, zource_pod_resource_path.dirname, verbose: true)
      }
    end

    # End
  end
end
