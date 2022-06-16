require "cocoapods"
require "cocoapods-zource/configuration/configuration"

$ZOURCE_DEFAULT_SOURCE_PODS = [] # source as default in command environment
$ZOURCE_PRIVACY_SOURCE_PODS = [] # source as privacy
$ZOURCE_COCOAPODS_SOURCE_PODS = [] # source as cocoapods

module CocoapodsZource
  class Podfile
    include Pod
    include Pod::Podfile::DSL

    def self.load_podfile_local
      # Path for zource.podfile
      project_root = Pod::Config.instance.project_root
      path = File.join(project_root.to_s, "zource.podfile")
      unless File.exist?(path)
        path = File.join(project_root.to_s, "zource.podfile")
      end
      return if !File.exist?(path)

      # Read zource.podfile
      contents = File.open(path, "r:utf-8", &:read)

      podfile = Pod::Config.instance.podfile
      zource_podfile = Pod::Podfile.from_file(path)

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
          privacy_source = CocoapodsZource::Configuration.configuration.configuration.repo_privacy_url
          binary_source = CocoapodsZource::Configuration.configuration.configuration.repo_binary_url
          hash_sources = get_hash_value("sources") || []
          hash_sources.unshift(privacy_source)
          hash_sources.unshift(binary_source)
          set_hash_value("sources", hash_sources.uniq)

          # podfile plugins
          if zource_podfile.plugins.any?
            hash_plugins = podfile.plugins || {}
            hash_plugins = hash_plugins.merge(zource_podfile.plugins)
            set_hash_value(%w[plugins].first, hash_plugins)

            # source code white list
            # podfile.set_use_source_pods(zource_podfile.use_source_pods) if zource_podfile.use_source_pods
            # podfile.use_binaries!(zource_podfile.use_binaries?)
          end

          zource_podfile&.target_definition_list&.each do |local_target|
            next if local_target.name == "Pods"

            target_definition_list.each do |target|
              unless target.name == local_target.name #&&
                    #  (local_target.to_hash["dependencies"] && local_target.to_hash["dependencies"].any?)
                next
              end

              target.instance_exec do
                # remove then set

                local_dependencies = local_target.to_hash["dependencies"] || Array.new
                target_dependencies = target.to_hash["dependencies"]

                # remove origin target dependency
                local_dependencies.each do |local_dependency|
                  unless local_dependency.is_a?(Hash) && local_dependency.keys.first
                    next
                  end

                  target_dependencies.each do |target_dependency|
                    dp_hash_equal = target_dependency.is_a?(Hash) &&
                                    target_dependency.keys.first &&
                                    target_dependency.keys.first == local_dependency.keys.first
                    dp_str_equal = target_dependency.is_a?(String) &&
                                   target_dependency == local_dependency.keys.first
                    next unless dp_hash_equal || dp_str_equal

                    target_dependencies.delete target_dependency
                    break
                  end
                end

                final_dependencies = Array.new
                # merge in dependencies
                merged_dependencies = target_dependencies + local_dependencies
                # set source if specified by global variables
                merged_dependencies.each do |dependency|
                  key = nil
                  value = nil
                  if dependency.is_a?(String)
                    key = dependency
                  elsif dependency.is_a?(Hash)
                    key = dependency.keys.first
                    value = dependency[key]
                  end
                  next if name.nil?
                  # default, means not specify by plugin, could be :path, :git, :podspec, etc
                  if $ZOURCE_DEFAULT_SOURCE_PODS.include?(key)
                    final_dependencies << dependency
                    next
                  end

                  source_hash = Hash.new
                  if $ZOURCE_PRIVACY_SOURCE_PODS.include?(key)
                    source_hash[:source] = privacy_source
                  elsif $ZOURCE_COCOAPODS_SOURCE_PODS.include?(key)
                    source_hash[:source] = "https://github.com/CocoaPods/Specs.git"
                  else
                    source_hash[:source] = binary_source
                  end
                  final_value = Array[source_hash]
                  final_dependency = Hash[key => final_value]
                  final_dependencies << final_dependency
                end
                set_hash_value(%w[dependencies].first, final_dependencies)
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
          raise Pod::DSLError.new(message, path, e, contents)
        end
      end
    end

    def self.pod_dependencies_hash_from_podfile
      pod_dependencies = Hash.new
      target_definition_list = Pod::Config.instance.podfile.target_definition_list
      target_definition_list.each do |target|
        next if target.name == "Pods"
        dependencies = target.to_hash["dependencies"] # Pod::Config.instance.podfile.target_definition_list.last.to_hash["dependencies"]
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
