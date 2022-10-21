require "cocoapods"
require "xcodeproj"
require "json"

require "cocoapods-zource/pod/zource_pod.rb"
require "cocoapods-zource/pod/config+zource.rb"
require "cocoapods-zource/pod/project_constructor.rb"
require "cocoapods-zource/pod/aggregration/xcframework_aggregration_composer.rb"
require "cocoapods-zource/pod/binary_compressor.rb"
require "cocoapods-zource/pod/binary_pod_publisher.rb"

module CocoapodsZource
  class ZourceAggregratedPod < ZourcePod
    def initialize()
      super(Pod::Config.instance.zource_aggregated_podspec_path, Hash.new)
      @meta[:version] = @podspec.version
      @zource_pod_project_directory = Pod::Config.instance.project_root
    end

    public

    def binary_podspec
      if @binary_podspec.nil?
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
        @binary_podspec&.description = JSON.pretty_generate(@podspec.to_json)
        # 6. source
        source = Hash.new
        source[:http] = CocoapodsZource::Configuration.configuration.binary_download_url(@binary_podspec.name, @binary_podspec.version)
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
      end
      @binary_podspec
    end

    def compose_xcframeworks
      Pod::UI.section "==== Start composing #{@podspec.name} xcframeworks ====" do
        composer = XCFrameworkAggregrationComposer.new(self)
        composer.compose
      end
    end

    # End
  end
end
