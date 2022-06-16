require "cocoapods"
require "xcodeproj"
require "cocoapods-zource/configuration/configuration"

module CocoapodsZource
  class XcodeProject
    def initialize()
      super
      @project_path = Pod::Config.instance.project_root
      @pods_path = Pod::Config.instance.project_pods_root
      @pod_project_path = File.join(@pods_path, "Pods.xcodeproj")
      @pod_project = Xcodeproj::Project.open(@pod_project_path)
      @configuration = CocoapodsZource::Configuration.configuration
    end

    def set_xcode_project
      @pod_project.targets.each {
        |target|
        next if defined?(target.source_build_phase).nil?
        macho_type = "staticlib"
        # target.source_build_phase.files.each {
        #   |f|
        #   path = f.file_ref.real_path.basename.to_path.to_s
        #   extension = File.extname(path)

        #   if extension.eql?(".swift")
        #     macho_type = "mh_dylib"
        #     break
        #   end
        # }

        target.build_configurations.each {
          |build_configuration|
          # environment
          next if build_configuration.name != @configuration.configuration.environment
          # MACH_O_TYPE
          target_macho_type = build_configuration.build_settings["MACH_O_TYPE"]
          next if target_macho_type.nil?
          # PRODUCT_NAME
          product_name = build_configuration.build_settings["PRODUCT_NAME"]
          next if product_name.nil?
          # set MACH_O_TYPE
          build_configuration.build_settings["MACH_O_TYPE"] = macho_type

        }
        print "#{target.name}: [MACH_O_TYPE => #{macho_type}]\n"
      }
      @pod_project.save
    end
  end
end
