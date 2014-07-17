module VCAP::CloudController
  class AppSummariesController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    get "#{path_guid}/summary", :summary
    def summary(guid)
      app = find_guid_and_validate_access(:read, guid)

      app_info = {
        guid: app.guid,
        name: app.name,
        routes: app.routes.map(&:as_summary_json),
        running_instances: instances_reporter.number_of_starting_and_running_instances_for_app(app),
        services: app.service_bindings.map { |service_binding| service_binding.service_instance.as_summary_json },
        available_domains:
          (app.space.organization.private_domains + SharedDomain.all).map(&:as_summary_json)
      }.merge(app.to_hash)

      MultiJson.dump(app_info)
    end

    protected

    attr_reader :instances_reporter

    def inject_dependencies(dependencies)
      super
      @instances_reporter = dependencies[:instances_reporter]
    end
  end
end
