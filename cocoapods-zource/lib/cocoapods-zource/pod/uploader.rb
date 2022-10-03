require "cocoapods"

require "cocoapods-zource/pod/zource_pod.rb"

module CocoapodsZource
  class Uploader
    include Pod

    attr_accessor :zource_pods

    def initialize
      @zource_pods = Hash.new
    end

    public

    def upload
      setup_zource_pods!
      UI.section "==== start uploading ====" do
        @zource_pods.each {
          |zource_pod_name, zource_pod|
          zource_pod.publish_binary
        }
      end
      UI.message "==== uploaded ====".green
    end

    private

    def setup_zource_pods!
      UI.section "==== setup zource pods ====" do
        # Setup Pod::Config.instance environment variables
        Pod::Config.instance.instance_eval do
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
        end
        # Setup @zource_pods
        zource_pods_hash = JSON.parse(Pod::Config.instance.zource_pods_json_path.read,
                                      { symbolize_names: true })
        zource_pods_hash.each {
          |zource_pod_name, zource_pod_hash|
          zp = ZourcePod.from_hash(zource_pod_hash)
          @zource_pods[zource_pod_name] = zp
        }
      end
      UI.message "zource pods count: #{@zource_pods.count}".green
    end

    # End Class
  end
end
