require "cocoapods"
require "yaml"
require "cocoapods-zource/pod/podfile"
require "cocoapods-zource/configuration/configuration"

module CocoapodsZource
  class PodSpec
    include Pod
    include Pod::Podfile::DSL

    def self.cocoapods_repo_home_path
      File.join(Dir.home, ".cocoapods", "repos")
    end

    def self.cocoapods_repo_path
      File.join(CocoapodsZource::PodSpec.cocoapods_repo_home_path, "cocoapods")
    end

    def self.trunk_repo_path
      File.join(CocoapodsZource::PodSpec.cocoapods_repo_home_path, "trunk")
    end

    def self.pravacy_repo_path
      File.join(CocoapodsZource::PodSpec.cocoapods_repo_home_path, CocoapodsZource::Configuration.configuration.configuration.repo_privacy_name)
    end

    def self.prefix_lengths_of_repo(repo)
      file_path = File.join(repo, "CocoaPods-version.yml")
      prefix_lengths = YAML.load_file(file_path)["prefix_lengths"]
    end

    def self.cocoapods_cache_home_path
      File.join(Dir.home, "Library", "Caches", "CocoaPods", "Pods")
    end

    def self.cocoapods_cache_external_home_path
      File.join(CocoapodsZource::PodSpec.cocoapods_cache_home_path, "External")
    end

    def self.cocoapods_cache_spec_home_path
      File.join(CocoapodsZource::PodSpec.cocoapods_cache_home_path, "Specs")
    end

    def self.podspec_path_of_pod(pod_name, pod_info, repo)
      version_file = File.join(repo, "CocoaPods-version.yml")
      if File.exist?(version_file)
        md5 = Digest::MD5.hexdigest(pod_name)
        prefix_lengths = CocoapodsZource::PodSpec.prefix_lengths_of_repo(repo)
        locations = Array.new
        prefix_lengths.each_index {
          |index|
          locations << md5[index, prefix_lengths[index]]
        }
        spec_path = File.join(repo, "Specs")
        locations.each {
          |l|
          spec_path = File.join(spec_path, l)
        }
        spec_path = File.join(spec_path, pod_name, CocoapodsZource::Podfile.version_of_pod_value(pod_info))
      else
        spec_path = File.join(repo, pod_name, CocoapodsZource::Podfile.version_of_pod_value(pod_info))
      end
    end

    def self.cache_podspec_of_external_pod(pod_name, pod_info)
      podspec_path = File.join(CocoapodsZource::PodSpec.cocoapods_cache_spec_home_path, "External", pod_name)
      return nil if !File.exist?(podspec_path)
      pod_checksum = CocoapodsZource::Podfile.checksum_of_pod_value(pod_info)
      Dir::entries(podspec_path).each {
        |f|
        path = File.join(podspec_path, f)
        next if !File::ftype(path).eql?("file")
        sha1 = Digest::SHA1.hexdigest(open(path).read)
        if sha1.eql?(pod_checksum)
          return path
        end
      }
      nil
    end

    def self.cache_pod_of_external_pod(pod_name, pod_info)
      pod = Hash.new
      cache_podspec = CocoapodsZource::PodSpec.cache_podspec_of_external_pod(pod_name, pod_info)
      pod[:podspec] = cache_podspec if !cache_podspec.nil?

      pod_path = File.join(CocoapodsZource::PodSpec.cocoapods_cache_external_home_path, pod_name)
      Dir::entries(pod_path).each {
        |d|
        if !cache_podspec.nil? && cache_podspec.include?(d)
          pod[:path] = File.join(pod_path, d)
        elsif File.join(pod_path, d).include?(CocoapodsZource::Podfile.checksum_of_pod_value(pod_info)[0, 5])
          pod[:path] = File.join(pod_path, d)
        end
      }
      pod
    end
  end
end
