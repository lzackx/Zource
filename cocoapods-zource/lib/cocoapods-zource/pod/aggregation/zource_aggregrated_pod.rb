require "cocoapods"
require "xcodeproj"
require "json"

require "cocoapods-zource/pod/zource_pod.rb"
require "cocoapods-zource/pod/config+zource.rb"
require "cocoapods-zource/pod/project_constructor.rb"
require "cocoapods-zource/pod/aggregation/xcframework_aggregration_composer.rb"
require "cocoapods-zource/pod/binary_compressor.rb"
require "cocoapods-zource/pod/binary_pod_publisher.rb"

module CocoapodsZource
  class ZourceAggregratedPod < ZourcePod
    attr_reader :zource_productive_pods

    def initialize()
      super(Pod::Specification::from_file(Pod::Config.instance.zource_aggregated_podspec_path), Hash.new)
      @meta[:version] = @podspec.version
      @zource_pod_project_directory = Pod::Config.instance.project_root
      @zource_productive_pods = Hash.new
    end

    public

    def save_zource_aggregated_pod
      json = JSON.pretty_generate(self)
      File.open(Pod::Config.instance.zource_aggregated_pod_json_path, "w") do |f|
        f.write(json)
      end
    end

    def binary_podspec
      if @binary_podspec.nil?
        podspec_hash = @podspec.to_hash
        clear_podspec_attributes(podspec_hash)
        @binary_podspec = Pod::Specification.from_hash(podspec_hash)
        # 1 add Zource subspec
        zource_subspec_name = "Zource"
        zource_subspec = @binary_podspec&.subspec(zource_subspec_name)
        zource_subspec&.vendored_frameworks = aggregated_vendored_frameworks
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
        @binary_podspec&.description = JSON.pretty_generate(@podspec.to_json)
        # 6. source
        source = Hash.new
        source[:http] = CocoapodsZource::Configuration.configuration.binary_download_url(@binary_podspec.name, @binary_podspec.version)
        @binary_podspec&.source = source
        # 7. static_framework
        @binary_podspec&.static_framework = true
        # 8. module_name
        # @binary_podspec&.module_name = @binary_podspec.name if @binary_podspec&.module_name.nil?
        # 9. license
        @binary_podspec&.license = "MIT"
        # 10. resource / resources / resource_bundles
        copy_resources_for_zource_aggregrated_pod
      end
      @binary_podspec
    end

    def compose_xcframeworks
      Pod::UI.section "==== Start composing #{@podspec.name} xcframeworks ====" do
        composer = XCFrameworkAggregrationComposer.new(self)
        composer.compose
      end
    end

    private

    def aggregated_vendored_frameworks
      verdored_frameworks = Array.new
      Pod::Config.instance.zource_pods.each {
        |zource_pod_name, zource_pod|
        next if zource_pod.xcodeproject_target&.class != Xcodeproj::Project::Object::PBXNativeTarget
        module_name = zource_pod_name
        if !zource_pod.podspec&.module_name.nil?
          module_name = zource_pod.podspec.module_name
        end
        next if JSON.parse(@binary_podspec.dependencies.to_json).include?(module_name)
        vf = "#{module_name}.xcframework"
        verdored_frameworks << vf
      }
      verdored_frameworks
    end

    def copy_resources_for_zource_aggregrated_pod
      Pod::UI.section("==== Start copying resources ====") do
        Pod::Config.instance.zource_pods.each {
          |zource_pod_name, zource_pod|
          copy_resources_from(zource_pod)
        }
      end
    end

    def copy_resources_from(source_zource_pod)
      super(source_zource_pod)
      copy_resources_meta_from(source_zource_pod)
      copy_resource_bundles_meta_from(source_zource_pod)
    end

    def copy_resource_bundles_meta_from(source_zource_pod)
      Pod::UI.section "==== copy #{source_zource_pod.podspec.name} resource bundles to #{@binary_podspec.name} ====" do
        # self resource_bundle & resource_bundles
        binary_resource_bundles = Hash.new
        if @binary_podspec.to_hash.key?("resource_bundle")
          resource_bundle = @binary_podspec.to_hash["resource_bundle"]
          resource_bundle.each {
            |key, value|
            values = Array.new
            if binary_resource_bundles.key?(key)
              values = binary_resource_bundles[key]
            end
            values << value
            binary_resource_bundles[key] = values
          }
          @binary_podspec&.resource_bundle = nil
        end
        if @binary_podspec.to_hash.key?("resource_bundles")
          resource_bundles = @binary_podspec.to_hash["resource_bundles"]
          resource_bundles.each {
            |key, value|
            values = Array.new
            if binary_resource_bundles.key?(key)
              values = binary_resource_bundles[key]
            end
            values = values + value
            binary_resource_bundles[key] = values
          }
        end

        # source resource_bundle & resource_bundles
        if source_zource_pod.podspec.to_hash.key?("resource_bundle")
          resource_bundle = source_zource_pod.podspec.to_hash["resource_bundle"]
          resource_bundle.each {
            |key, value|
            values = Array.new
            if binary_resource_bundles.key?(key)
              values = binary_resource_bundles[key]
            end
            values << value
            binary_resource_bundles[key] = values
          }
        end
        if source_zource_pod.podspec.to_hash.key?("resource_bundles")
          resource_bundles = source_zource_pod.podspec.to_hash["resource_bundles"]
          resource_bundles.each {
            |key, value|
            values = Array.new
            if binary_resource_bundles.key?(key)
              values = binary_resource_bundles[key]
            end
            values = values + value
            binary_resource_bundles[key] = values
          }
        end
        @binary_podspec&.resource_bundles = binary_resource_bundles
      end
    end

    def copy_resources_meta_from(source_zource_pod)
      Pod::UI.section "==== copy #{source_zource_pod.podspec.name} resources to #{@binary_podspec.name} ====" do
        # self resource & resources
        binary_resources = Array.new
        if @binary_podspec.to_hash.key?("resource")
          resource = @binary_podspec.to_hash["resource"]
          binary_resources << resource
          @binary_podspec&.resource = nil
        end
        if @binary_podspec.to_hash.key?("resources")
          resources = @binary_podspec.to_hash["resources"]
          binary_resources = binary_resources + resources
        end

        # source resource & resources
        source_zource_pod_podspec_resources = Array.new
        # resource
        if source_zource_pod.podspec.to_hash.key?("resource")
          resource = source_zource_pod.podspec.to_hash["resource"]
          source_zource_pod_podspec_resources << resource
        end
        # resources
        if source_zource_pod.podspec.to_hash.key?("resources")
          resources = source_zource_pod.podspec.to_hash["resources"]
          source_zource_pod_podspec_resources = source_zource_pod_podspec_resources + resources
        end
        # compose resources
        if source_zource_pod_podspec_resources.length > 0
          binary_resources = binary_resources + source_zource_pod_podspec_resources
        end
        @binary_podspec&.resources = binary_resources
      end
    end

    # End
  end
end
