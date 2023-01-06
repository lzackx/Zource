require "cocoapods"

require "cocoapods-zource/pod/zource_pod.rb"
require "cocoapods-zource/pod/config+zource.rb"

module CocoapodsZource
  class Uploader
    include Pod

    def initialize
      @pods_xcodeproj = Xcodeproj::Project.open(Pod::Config.instance.project_pods_root.join("Pods.xcodeproj"))
    end

    public

    def upload
      UI.section "==== start uploading ====" do
        setup_zource_pods_xcodeproject_target!
        Pod::Config.instance.zource_pods.each {
          |zource_pod_name, zource_pod|
          # Not compose zource_pod if it is not a Xcodeproj::Project::Object::PBXNativeTarget
          if zource_pod.xcodeproject_target.class != Xcodeproj::Project::Object::PBXNativeTarget
            next
          end
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

    def setup_zource_pods_xcodeproject_target!
      Pod::Config.instance.zource_pods.values.each {
        |zource_pod|
        @pods_xcodeproj.targets.each {
          |target|
          if target.name == zource_pod.podspec.name
            zource_pod.xcodeproject_target = target
          end
        }
      }
    end

    # End Class
  end
end
