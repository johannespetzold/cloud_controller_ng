require "cloud_controller/dea/backend"
require "cloud_controller/diego/backend"
require "cloud_controller/diego/traditional/protocol"
require "cloud_controller/diego/docker/protocol"

module VCAP::CloudController
  class Backends
    def initialize(config, message_bus, dea_pool, stager_pool)
      @config = config
      @message_bus = message_bus
      @dea_pool = dea_pool
      @stager_pool = stager_pool
    end

    def validate_app_for_staging(app)
      if app.docker_image.present? && !@config[:diego_docker]
        raise Errors::ApiError.new_from_details("DockerDisabled")
      end

      if app.package_hash.blank?
        raise Errors::ApiError.new_from_details("AppPackageInvalid", "The app package hash is empty")
      end

      if app.buildpack.custom? && !app.custom_buildpacks_enabled?
        raise Errors::ApiError.new_from_details("CustomBuildpacksDisabled")
      end

      if Buildpack.count == 0 && app.buildpack.custom? == false
        raise Errors::ApiError.new_from_details("NoBuildpacksFound")
      end
    end

    def find_one_to_stage(app)
      case @config[:diego][:staging]
      when 'disabled'
        app.stage_with_diego? ?
          raise_diego_disabled :
          dea_backend(app)
      when 'optional'
        app.stage_with_diego? ?
          diego_backend(app) :
          dea_backend(app)
      end
    end

    def find_one_to_run(app)
      case @config[:diego][:running]
      when 'disabled'
        app.run_with_diego? ?
          raise_diego_disabled :
          dea_backend(app)
      when 'optional'
        app.run_with_diego? ?
          diego_backend(app) :
          dea_backend(app)
      end
    end

    def diego_backend(app)
      app.docker_image.present? ?
        diego_docker_backend(app) :
        diego_traditional_backend(app)
    end

    private

    def diego_docker_backend(app)
      protocol = Diego::Docker::Protocol.new
      messenger = Diego::Messenger.new(@message_bus, protocol)
      completion_handler = Diego::Docker::StagingCompletionHandler.new(self)
      Diego::Backend.new(app, messenger, protocol, completion_handler)
    end

    def diego_traditional_backend(app)
      dependency_locator = CloudController::DependencyLocator.instance
      protocol = Diego::Traditional::Protocol.new(dependency_locator.blobstore_url_generator)
      messenger = Diego::Messenger.new(@message_bus, protocol)
      completion_handler = Diego::Traditional::StagingCompletionHandler.new(self)
      Diego::Backend.new(app, messenger, protocol, completion_handler)
    end

    def dea_backend(app)
      Dea::Backend.new(app, @config, @message_bus, @dea_pool, @stager_pool)
    end

    def raise_diego_disabled
      raise VCAP::Errors::ApiError.new_from_details("DiegoDisabled")
    end
  end
end
