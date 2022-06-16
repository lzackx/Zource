require "cocoapods"
require "xcodeproj"
require 'find'
require "cocoapods-zource/pod/podfile"
require "cocoapods-zource/pod/podspec"
require "cocoapods-zource/configuration/configuration"
require "cocoapods-zource/maker/xcode_project"

module CocoapodsZource
  class Maker
    include Pod
    include Pod::Podfile::DSL

    def initialize(configuration)
      @configuration = configuration
      @pods = Hash.new
      @project_path = Pod::Config.instance.project_root
      @pods_path = Pod::Config.instance.project_pods_root
      @iphoneos_frameworks_path = File.join(@project_path, "build", "#{@configuration}-iphoneos")
      @iphonesimulator_frameworks_path = File.join(@project_path, "build", "#{@configuration}-iphonesimulator")
      @cocoapods_cache_home_path = CocoapodsZource::PodSpec.cocoapods_cache_home_path
      @zource_path = File.join(@pods_path, "zource")
    end

    def backup_project
      UI.message "Backup #{@project_path} => #{@project_path}.backup"
      command = "cp -rf #{@project_path} #{@project_path}.backup"
      done = system command
      abort("Backup #{@project_path} failed") if !done
    end

    def build_frameworks
      UI.message "Start building frameworks for each architecture...".blue

      pod_project_buildsettings = CocoapodsZource::XcodeProject.new
      pod_project_buildsettings.set_xcode_project

      if File::exist?(@zource_path) && !@zource_path.eql?("/")
        UI.message "Removing #{@zource_path}".yellow
        system "rm -rf #{@zource_path}"
      end
      Dir::mkdir(@zource_path)

      xcodebuild_iphoneos_frameworks
      xcodebuild_iphonesimulator_frameworks
    end

    def create_xcframeworks
      # 1. get pods
      @pods = CocoapodsZource::Podfile.pod_from_podfile_lock
      UI.message "Pods count: #{@pods.count}".green
      # 2. filter empty framework, which is already a library
      @target_pods = filter_target_pods
      UI.message "target_pods: #{@target_pods.count}".blue

      # 3. create xcframework
      @target_pods.each {
        |key, value|
        xcodebuild_create_xcframework(key, value)
        @target_pods[key][:zource] = File.join(@zource_path, key)
      }
    end

    def make_podspecs
      insert_pod_info
      add_podspecs_to_xcframework
    end

    def zip_pods
      @target_pods.each {
        |key, value|
        zource_path = CocoapodsZource::Podfile.zource_of_pod_value(value)
        Dir::chdir(zource_path)
        done = system "zip -r #{key}.zip ./*"
        Dir::chdir(@project_path)
        abort("zip failed: #{key}.zip") if !done
      }
      UI.info "zip target pods done"
    end

    private

    def xcodebuild_iphoneos_frameworks
      UI.message "xcodebuild iphoneos frameworks"
      Dir::chdir(@pods_path)
      done = system "xcodebuild -project Pods.xcodeproj -alltargets -parallelizeTargets -sdk iphoneos -configuration #{@configuration} BUILD_LIBRARY_FOR_DISTRIBUTION=YES MACH_O_TYPE=staticlib CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES=YES"
      abort("xcodebuild iphoneos frameworks failed") if !done
      Dir::chdir(@project_path)
    end

    def xcodebuild_iphonesimulator_frameworks
      UI.message "xcodebuild iphonesimulator frameworks"
      Dir::chdir(@pods_path)
      done = system "xcodebuild -project Pods.xcodeproj -alltargets -parallelizeTargets -sdk iphonesimulator -configuration #{@configuration} BUILD_LIBRARY_FOR_DISTRIBUTION=YES MACH_O_TYPE=staticlib CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES=YES"
      abort("xcodebuild iphonesimulator frameworks failed") if !done
      Dir::chdir(@project_path)
    end

    def xcodebuild_create_xcframework(key, value)
      UI.message "create xcframework for:\n #{key}".cyan
      xcframework_name = File.basename(iphoneos_framework_for_pod_value(value), ".framework")
      output_path = File.join(@zource_path, key, "#{xcframework_name}.xcframework")
      command = "xcodebuild -create-xcframework -output #{output_path} "
      if !iphoneos_framework_for_pod_value(value).nil?
        command = command + " -framework #{iphoneos_framework_for_pod_value(value)} "
      end
      if !iphonesimulator_framework_for_pod_value(value).nil?
        command = command + " -framework #{iphonesimulator_framework_for_pod_value(value)} "
      end
      done = system "#{command}"
      abort("create xcframework failed:\nkey: #{key}\nvalue: #{value}") if !done
    end

    def filter_target_pods
      # 1. filter pod 
      target_pods = @pods.reject {
        |key, value|
        pod_path = File.join(@iphoneos_frameworks_path, key)
        should_reject = true
        # 1.1 whose has not framework in build directory
        if !File.exist?(pod_path)
          should_reject = true
        else
          Dir.entries(pod_path).each {
            |f|
            if File.extname(f).eql?(".framework")
              should_reject = false
              break
            end
          }
        end
        # 1.2 whose is Swift framework (because .swiftinterface bug from Swift compiler)
        Find.find(pod_path) do |path|
          if File::directory?(path)
            if File.basename(path).start_with?('.')
              Find.prune       # Don't look any further into this directory.
            else
              next
            end
          else
            file_name = File.basename(path)
            if File.extname(file_name).eql?(".swiftinterface")
              should_reject = true
              break
            end
          end
        end
        should_reject
      }
      # 2. add framework path info to Hash
      target_pods.each {
        |key, value|
        pod_iphoneos_path = File.join(@iphoneos_frameworks_path, key)
        Dir.entries(pod_iphoneos_path).each {
          |f|
          if File.extname(f).eql?(".framework")
            value[:iphoneos_framework] = File.join(pod_iphoneos_path, f)
            break
          end
        }

        pod_iphonesimulator_path = File.join(@iphonesimulator_frameworks_path, key)
        Dir.entries(pod_iphonesimulator_path).each {
          |f|
          if File.extname(f).eql?(".framework")
            value[:iphonesimulator_framework] = File.join(pod_iphonesimulator_path, f)
            break
          end
        }
      }
    end

    def iphoneos_framework_for_pod_value(pod_value)
      pod_value[:iphoneos_framework]
    end

    def iphonesimulator_framework_for_pod_value(pod_value)
      pod_value[:iphonesimulator_framework]
    end

    def insert_pod_info
      @target_pods.each {
        |key, value|
        spec = nil
        if !CocoapodsZource::Podfile.path_of_pod_value(value).nil?
          # 1 :path exisits
          podspec_path = CocoapodsZource::Podfile.path_of_pod_value(value)
          podspec_file = File.join(podspec_path, "#{key}.podspec")
          if !File.exist?(podspec_file)
            podspec_file = File.join(podspec_path, "#{key}.podspec.json")
          end
          @target_pods[key][:podspec] = podspec_file
          # convert related path to absolute path
          @target_pods[key][:path] = File.join(@project_path, podspec_path)
        elsif !CocoapodsZource::Podfile.source_of_pod_value(value).nil?
          # 2 :source exisits => Release
          podspec_path = CocoapodsZource::PodSpec.podspec_path_of_pod(key, value, CocoapodsZource::PodSpec.cocoapods_repo_path)
          if !File.exist?(podspec_path)
            podspec_path = CocoapodsZource::PodSpec.podspec_path_of_pod(key, value, CocoapodsZource::PodSpec.trunk_repo_path)
          end
          if !File.exist?(podspec_path)
            podspec_path = CocoapodsZource::PodSpec.podspec_path_of_pod(key, value, CocoapodsZource::PodSpec.pravacy_repo_path)
          end
          if podspec_path.nil? || !File.exist?(podspec_path)
            abort("Lookup Podspec failed: #{key}")
          end
          podspec_file = File.join(podspec_path, "#{key}.podspec")
          if !File.exist?(podspec_file)
            podspec_file = File.join(podspec_path, "#{key}.podspec.json")
          end
          @target_pods[key][:podspec] = podspec_file

          @target_pods[key][:path] = File.join(@pods_path, key)
        else
          # 3 :podspec exisits => "External"
          # 4 :git exisits => "External"
          pod = CocoapodsZource::PodSpec.cache_pod_of_external_pod(key, value)
          # /Users/xxx/Library/Caches/CocoaPods/Pods/External/boost/909665deed38b6f25051fac8c534aa3c-a7c83
          @target_pods[key] = value.merge(pod)
        end
        abort("Lookup podspec failed: #{key}") if CocoapodsZource::Podfile.podspec_of_pod_value(@target_pods[key]).nil?
        abort("Lookup path failed: #{key}") if CocoapodsZource::Podfile.path_of_pod_value(@target_pods[key]).nil?
      }
    end

    def add_podspecs_to_xcframework
      @target_pods.each {
        |key, value|
        podspec_path = CocoapodsZource::Podfile.podspec_of_pod_value(value)
        abort("no podspec value of #{key} pod") if podspec_path.nil?
        spec = Pod::Specification.from_file(podspec_path)
        if spec.nil?
          abort("spec new error for: #{key}")
        end
        # modify spec attributes to specify xcframework
        # 1. clear code related attributes
        spec&.source_files = []
        spec&.exclude_files = []
        spec&.public_header_files = []
        spec&.project_header_files = []
        spec&.private_header_files = []
        spec&.subspecs = []
        spec&.module_map = false
        spec&.prepare_command = nil
        spec&.header_mappings_dir = nil
        spec&.preserve_paths = nil
        spec&.default_subspecs = nil
        # 1.1 clear code related attributes on iOS platform
        spec.ios&.source_files = []
        spec.ios&.exclude_files = []
        spec.ios&.public_header_files = []
        spec.ios&.project_header_files = []
        spec.ios&.private_header_files = []
        spec.ios&.module_map = false
        spec.ios&.header_mappings_dir = nil
        spec.ios&.preserve_paths = nil
        # 1.2 clear all related attributes on other platform
        # spec.osx = nil
        # spec.tvos = nil
        # spec.watchos = nil

        # 2. description
        description = Hash.new
        description[:version] = CocoapodsZource::Podfile.version_of_pod_value(value)
        description[:checksum] = CocoapodsZource::Podfile.checksum_of_pod_value(value) if !CocoapodsZource::Podfile.checksum_of_pod_value(value).nil?
        description[:subspec] = CocoapodsZource::Podfile.subspec_of_pod_value(value) if !CocoapodsZource::Podfile.subspec_of_pod_value(value).nil?
        spec&.description = JSON.pretty_generate(description)
        # 3. source
        source = Hash.new
        source[:http] = CocoapodsZource::Configuration.configuration.binary_download_url(key, description[:version])
        spec&.source = source
        # 4. static_framework
        spec&.static_framework = true
        # 5. vendored_frameworks
        xcframework_name = File.basename(iphoneos_framework_for_pod_value(value), ".framework")
        spec&.vendored_frameworks = "#{xcframework_name}.xcframework"
        # 6. resource / resources / resource_bundles
        copy_resource_for_spec(spec)
        # 7. Fix Swift compiler bug about .swiftinterface file,
        # https://github.com/apple/swift/issues/43510, https://github.com/apple/swift/issues/56573
        # module_name = "Zource#{key}"
        # if !spec.to_hash["module_name"].nil?
        #   module_name = "Zource#{spec.to_hash["module_name"]}"
        # end
        # spec&.module_name = module_name
        # fix_swiftinterface(spec, key, value)

        # write spec json to file
        write_podspec_file_for_spec(spec)
      }
      # write target pods json to file
      write_target_pods_file
    end

    # def fix_swiftinterface(spec, key, value)
    #   zource_pod_path = CocoapodsZource::Podfile.zource_of_pod_value(value)
    #   xcframework_path = File.join(zource_pod_path, "#{key}.xcframework")
    #   Dir::chdir(zource_pod_path)
    #   # system "find . -name '*.swiftinterface' -exec sed -i -e 's/#{module_name}\.//g' {} \\;"
    #   system "find . -name '*.swiftinterface' -exec sed -i -e 's/Zource//g' {} \\;"
    #   Dir::chdir(@project_path)
    # end

    def copy_resource_for_spec(spec)
      if spec.to_hash.key?("resource")
        resource_path = spec.to_hash["resource"]
        copy_resource(resource_path)
      end
      if spec.to_hash.key?("resources")
        resources = spec.to_hash["resources"]
        if resources.is_a?(String)
          resource_path = resources
          copy_resource(spec, resource_path)
        elsif resources.is_a?(Array)
          resources.each {
            |resource|
            resource_path = resource
            copy_resource(spec, resource_path)
          }
        end
      end
      if spec.to_hash.key?("resource_bundles")
        resource_bundles = spec.to_hash["resource_bundles"]
        resource_bundles.each {
          |key, value|
          if value.is_a?(String)
            resource_path = value
            copy_resource(spec, resource_path)
          elsif value.is_a?(Array)
            zource_resources = Array.new
            value.each {
              |v|
              resource_path = v
              copy_resource(spec, resource_path)
            }
          end
        }
      end
    end

    def copy_resource(spec, resource_path)
      zource_pod_home = File.join(@zource_path, spec.name)

      abort("no path: #{@target_pods[spec.name]}") if CocoapodsZource::Podfile.path_of_pod_value(@target_pods[spec.name]).nil?
      pod_path = CocoapodsZource::Podfile.path_of_pod_value(@target_pods[spec.name])
      resource_absolute_path = File.join(pod_path, resource_path)
      if Dir::glob(resource_absolute_path).empty?
        abort("not exists: #{resource_absolute_path}")
      end

      Dir::glob(resource_absolute_path).each {
        |f|
        next if File.basename(f).eql?("*") || File.basename(f).eql?("**")
        f_related_path = f[pod_path.length...f.length]
        zource_resource_path = File.join(zource_pod_home, f_related_path)
        if !File.exist?(zource_resource_path)
          FileUtils.mkdir_p(zource_resource_path)
        end
        FileUtils.cp_r(f, File.dirname(zource_resource_path), verbose: true)
        UI.message "#{f} => cp => #{zource_resource_path}"
      }
    end

    def write_podspec_file_for_spec(spec)
      podspec_json = JSON.pretty_generate(spec)
      podspec_json_path = File.join(@zource_path, spec.name, "#{spec.name}.podspec.json")
      File.open(podspec_json_path, "w") do |f|
        f.write(podspec_json)
      end
    end

    def write_target_pods_file
      target_pods_json = JSON.pretty_generate(@target_pods)
      target_pods_json_path = File.join(@pods_path, "zource.make.pods.json")
      File.open(target_pods_json_path, "w") do |f|
        f.write(target_pods_json)
      end
      UI.info "target pods: #{target_pods_json_path}".cyan
    end

    # End Class
  end
end
