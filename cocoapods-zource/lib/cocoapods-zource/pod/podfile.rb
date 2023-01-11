require "cocoapods"
require "cocoapods-zource/pod/config+zource.rb"
require "cocoapods-zource/configuration/configuration"

$ZOURCE_ORIGINAL_SOURCE_PODS = [] # source as default in command environment
$ZOURCE_PRIVACY_SOURCE_PODS = [] # source as privacy
$ZOURCE_BINARY_SOURCE_PODS = [] # source as binary
$ZOURCE_COCOAPODS_SOURCE_PODS = [] # source as cocoapods

module CocoapodsZource
  class Podfile
    include Pod
    include Pod::Podfile::DSL

    def self.load_podfile_local
      # Path for zource.podfile
      return if !Pod::Config.instance.zource_podfile_path.exist?

      # Read zource.podfile
      podfile = Pod::Config.instance.podfile
      zource_podfile = Pod::Podfile.from_file(Pod::Config.instance.zource_podfile_path.to_path)

      if zource_podfile
        local_pre_install_callback = nil
        local_post_install_callback = nil
        zource_podfile.instance_eval do
          local_pre_install_callback = @pre_install_callback
          local_post_install_callback = @post_install_callback
        end
      end

      podfile.instance_eval do
        begin

          # add sources
          privacy_sources = CocoapodsZource::Configuration.configuration.repo_privacy_urls_array
          binary_source = CocoapodsZource::Configuration.configuration.configuration.repo_binary_url
          hash_sources = get_hash_value("sources") || []
          privacy_sources.each {
            |source|
            hash_sources.unshift(source)
          }
          hash_sources.unshift(binary_source)
          set_hash_value("sources", hash_sources.uniq)

          zource_podfile&.target_definition_list&.each do |zource_podfile_target| #Pod::Podfile::TargetDefinition
            next if zource_podfile_target.abstract?
            zource_target_dependencies = zource_podfile_target.dependencies # Array<Pod::Dependency>

            # compare target definition between zource and origin
            target_definition_list.each do |original_podfile_target|
              next unless original_podfile_target.name == zource_podfile_target.name
              original_target_dependencies = original_podfile_target.dependencies  # Array<Pod::Dependency>

              original_podfile_target.instance_exec do
                # remove then set
                zource_target_dependencies_names = zource_target_dependencies.map { |ztd| ztd.name }
                original_target_dependencies = original_target_dependencies.delete_if {
                  |dependency|
                  should_delete = false
                  if zource_target_dependencies_names.include?(dependency.name)
                    should_delete = true
                  end
                  should_delete
                }

                final_dependencies = Array.new
                # merge in dependencies
                merged_dependencies = original_target_dependencies | zource_target_dependencies
                # set source if specified by global variables
                merged_dependencies.each {
                  |dependency|
                  # Default to binary source since ordered sources added before
                  # setup source if there are dependencies name included by the specified variables in zource.podfile
                  if $ZOURCE_ORIGINAL_SOURCE_PODS.include?(dependency.root_name)
                    # ZOURCE_ORIGINAL_SOURCE_PODS
                    # do nothing
                  elsif $ZOURCE_PRIVACY_SOURCE_PODS.include?(dependency.root_name)
                    # ZOURCE_PRIVACY_SOURCE_PODS
                    dependency.podspec_repo = privacy_sources.first
                    dependency.external_source = nil
                  elsif $ZOURCE_COCOAPODS_SOURCE_PODS.include?(dependency.root_name)
                    # ZOURCE_COCOAPODS_SOURCE_PODS
                    dependency.podspec_repo = "https://github.com/CocoaPods/Specs.git"
                    dependency.external_source = nil
                  elsif $ZOURCE_BINARY_SOURCE_PODS.include?(dependency.root_name)
                    # ZOURCE_BINARY_SOURCE_PODS
                    dependency.podspec_repo = binary_source
                    dependency.external_source = nil
                  else
                    # Do nothing
                  end
                  # finally, add to final_dependencies
                  final_dependencies << dependency
                }
                # handle external dependency
                final_dependencies.each {
                  |dependency|
                  if dependency.external?
                    # not use local dependency 
                    if dependency.external_source.key?(:path) || dependency.external_source.key?(:podspec)
                      # use source as specified
                      dependency.podspec_repo = nil
                      dependency.external_source = nil
                    else
                      # use source list if dependency's static xcframework exists
                      current_uploaded_static_frameworks = CocoapodsZource::Configuration.configuration.current_uploaded_static_frameworks
                      if current_uploaded_static_frameworks.keys.include?(dependency.root_name)
                        dependency.podspec_repo = nil
                        dependency.external_source = nil
                      end
                    end
                  end
                }
                # convert Pod::Dependency to pod description (name or { name => requirements })
                final_dependencies_hash_array = final_dependencies.map {
                  |fd|
                  requirements = Array.new
                  if !fd.podspec_repo.nil?
                    requirements << fd.podspec_repo
                  elsif fd.external?
                    requirements << fd.external_source
                  elsif fd.requirement != Pod::Requirement.default
                    requirements << fd.requirement.to_s
                  end
                  mfd = fd.name
                  if !requirements.empty?
                    mfd = { fd.name => requirements }
                  end
                  mfd
                }
                set_hash_value("dependencies", final_dependencies_hash_array)
              end
            end
          end

          if local_pre_install_callback
            @pre_install_callback = local_pre_install_callback
          end
          if local_post_install_callback
            @post_install_callback = local_post_install_callback
          end
        rescue Exception => e
          message = "Invalid `#{path}` file: #{e.message}"
          raise Pod::DSLError.new(message, path, e)
        end
      end
    end

    def self.pod_dependencies_hash_from_podfile
      pod_dependencies = Hash.new
      target_definition_list = Pod::Config.instance.podfile.target_definition_list
      target_definition_list.each do |original_podfile_target|
        next if original_podfile_target.name == "Pods"
        dependencies = original_podfile_target.to_hash["dependencies"] # Pod::Config.instance.podfile.target_definition_list.last.to_hash["dependencies"]
        dependencies.each do |dependency|
          if dependency.is_a?(String)
            pod_dependencies[dependency] = Array.new
          elsif dependency.is_a?(Hash)
            pod_dependencies = pod_dependencies.merge(dependency)
          end
        end
      end
      pod_dependencies
    end

    def self.pod_dependencies
      pod_dependencies = Hash.new
      CocoapodsZource::Podfile.pod_dependencies_hash_from_podfile.each {
        |k, v|
        key = k
        value = Hash.new
        # convert Array v to Hash value
        if !v.empty?
          v.each {
            |a|
            value = value.merge(a)
          }
        end
        # if there is "/" subspec, convert it to :subspec Array and get the correct key
        if key.include?("/")
          subspec = key[key.index("/") + 1...key.length]
          key = key[0, key.index("/")]
          if pod_dependencies[key].nil?
            value[:subspec] = Array[subspec]
          elsif pod_dependencies[key][:subspec].nil?
            value[:subspec] = Array[subspec]
          elsif pod_dependencies[key][:subspec].is_a?(Array)
            value = pod_dependencies[key].merge(value)
            value[:subspec] << subspec
          end
        end
        pod_dependencies[key] = value
      }
      pod_dependencies
    end

    def self.pod_from_podfile_lock
      project_path = Pod::Config.instance.project_root
      podfile_lock_path = File.join(project_path, "Podfile.lock")
      podfile_lock_hash = YAML.load_file(podfile_lock_path).to_hash
      pod = Hash.new
      # Read "PODS"
      podfile_lock_hash["PODS"].each do |item|
        p = item
        if p.is_a?(Hash)
          p = item.keys.first
        end
        name = p[0, p.index(" ")]
        version = p[p.index("(") + 1...p.index(")")]
        p_info = Hash.new
        p_info[:version] = version
        # if there is "/" subspec, convert it to :subspec Array and get the correct key
        if name.include?("/")
          subspec = name[name.index("/") + 1...name.length]
          name = name[0, name.index("/")]
          if pod[name].nil?
            p_info[:subspec] = Array[subspec]
          elsif pod[name][:subspec].nil?
            p_info[:subspec] = Array[subspec]
          elsif pod[name][:subspec].is_a?(Array)
            p_info = pod[name].merge(p_info)
            p_info[:subspec] << subspec
          end
        end
        pod[name] = p_info
      end
      # Read "SPEC REPOS"
      podfile_lock_hash["SPEC REPOS"].each do |repo, pod_names|
        pod_names.each do |pn|
          if pod.keys.include?(pn)
            pod[pn][:source] = repo
          end
        end
      end

      # Read "EXTERNAL SOURCES"
      podfile_lock_hash["EXTERNAL SOURCES"].each do |pod_name, info|
        if pod.keys.include?(pod_name)
          pod[pod_name] = pod[pod_name].merge(info)
        end
      end

      # Read "CHECKOUT OPTIONS"
      podfile_lock_hash["CHECKOUT OPTIONS"].each do |pod_name, info|
        if pod.keys.include?(pod_name)
          pod[pod_name] = pod[pod_name].merge(info)
        end
      end

      # Read "CSPEC CHECKSUMS"
      podfile_lock_hash["SPEC CHECKSUMS"].each do |pod_name, info|
        if pod.keys.include?(pod_name)
          pod[pod_name][:checksum] = info
        end
      end
      pod
    end

    def self.version_of_pod_value(pod_value)
      pod_value[:version]
    end

    def self.source_of_pod_value(pod_value)
      pod_value[:source]
    end

    def self.podspec_of_pod_value(pod_value)
      pod_value[:podspec]
    end

    def self.subspec_of_pod_value(pod_value)
      pod_value[:subspec]
    end

    def self.product_path_of_pod_value(pod_value)
      pod_value[:product]
    end

    def self.path_of_pod_value(pod_value)
      pod_value[:path]
    end

    def self.git_of_pod_value(pod_value)
      pod_value[:git]
    end

    def self.tag_of_pod_value(pod_value)
      pod_value[:tag]
    end

    def self.branch_of_pod_value(pod_value)
      pod_value[:branch]
    end

    def self.commit_of_pod_value(pod_value)
      pod_value[:commit]
    end

    def self.checksum_of_pod_value(pod_value)
      pod_value[:checksum]
    end

    def self.zource_of_pod_value(pod_value)
      pod_value[:zource]
    end
  end
end
