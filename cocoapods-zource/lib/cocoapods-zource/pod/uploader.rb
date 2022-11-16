require "cocoapods"

require "cocoapods-zource/pod/zource_pod.rb"
require "cocoapods-zource/pod/config+zource.rb"

module CocoapodsZource
  class Uploader
    include Pod

    def initialize
    end

    public

    def upload
      UI.section "==== start uploading ====" do
        Pod::Config.instance.zource_pods.each {
          |zource_pod_name, zource_pod|
          zource_pod.publish_binary
        }
      end
      UI.message "==== uploaded ====".green
    end

    def upload_aggregation
      UI.section "==== start uploading ====" do
        Pod::Config.instance.zource_aggregated_pod.publish_binary
      end
      UI.message "==== uploaded ====".green
    end

    # End Class
  end
end
