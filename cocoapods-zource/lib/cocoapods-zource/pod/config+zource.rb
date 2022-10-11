require "cocoapods"

module Pod
  class Config
    public

    attr_accessor :zource_pods

    def zource_pods
      if @zource_pods.nil?
        @zource_pods = Hash.new
        zource_pods_hash = JSON.parse(zource_pods_json_path.read, { symbolize_names: true })
        zource_pods_hash.each {
          |zource_pod_name, zource_pod_hash|
          zp = ZourcePod.from_hash(zource_pod_hash)
          @zource_pods[zource_pod_name] = zp
        }
      end
      @zource_pods
    end

    def zource_root
      if @zource_root.nil?
        @zource_root = Pod::Config.instance.project_root.join(".zource")
      end
      @zource_root
    end

    def zource_pods_json_path
      if @zource_pods_json_path.nil?
        @zource_pods_json_path = zource_root.join("zource.pods.json")
      end
      @zource_pods_json_path
    end

    # End Class
  end
end
