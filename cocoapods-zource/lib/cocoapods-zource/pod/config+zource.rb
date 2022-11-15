require "cocoapods"
require "cocoapods-zource/pod/zource_pod.rb"

module Pod
  class Config
    public

    # Configuration

    def zource_root
      if @zource_root.nil?
        @zource_root = Pod::Config.instance.project_root.join(".zource")
      end
      @zource_root
    end

    def zource_podfile_path
      if @zource_podfile_path.nil?
        @zource_podfile_path = Pod::Config.instance.project_root.join("zource.podfile")
      end
      @zource_podfile_path
    end

    def zource_configuration_path
      if @zource_configuration_path.nil?
        @zource_configuration_path = Pod::Config.instance.project_root.join("zource.yaml")
      end
      @zource_configuration_path
    end

    # Zource Pods
    attr_accessor :zource_pods

    def zource_pods
      if @zource_pods.nil?
        @zource_pods = Hash.new
        zource_pods_hash = JSON.parse(zource_pods_json_path.read, { symbolize_names: true })
        zource_pods_hash.each {
          |zource_pod_name, zource_pod_hash|
          zp = CocoapodsZource::ZourcePod.from_hash(zource_pod_hash)
          @zource_pods[zource_pod_name] = zp
        }
      end
      @zource_pods
    end

    def zource_pods_json_path
      if @zource_pods_json_path.nil?
        @zource_pods_json_path = zource_root.join("zource.pods.json")
      end
      @zource_pods_json_path
    end

    # Zource Aggregation Pod
    def zource_aggregated_podspec_path
      if @zource_aggregated_podspec_path.nil?
        @zource_aggregated_podspec_path = Pod::Config.instance.project_root.join("zource.aggregated.pod.podspec")
      end
      @zource_aggregated_podspec_path
    end

    def zource_aggregated_pod_json_path
      if @zource_aggregated_pod_json_path.nil?
        @zource_aggregated_pod_json_path = zource_root.join("zource.aggregated.pod.json")
      end
      @zource_aggregated_pod_json_path
    end

    # End Class
  end
end
