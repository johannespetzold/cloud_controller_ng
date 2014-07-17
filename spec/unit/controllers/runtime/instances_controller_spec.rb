require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::InstancesController do
    describe "GET /v2/apps/:id/instances" do
      before :each do
        @app = AppFactory.make(:package_hash => "abc", :package_state => "STAGED")
        @user =  make_user_for_space(@app.space)
        @developer = make_developer_for_space(@app.space)
      end

      context "as a developer" do
        let(:user) { @developer }
        let(:instances_reporter) { double(:instances_reporter) }

        before do
          allow(CloudController::DependencyLocator.instance).to receive(:instances_reporter).and_return(instances_reporter)
        end

        it "returns 400 when there is an error finding the instances" do
          @app.state = "STOPPED"
          @app.save

          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))

          expect(last_response.status).to eq(400)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response["code"]).to eq(220001)
          expect(parsed_response["description"]).to eq("Instances error: Request failed for app: #{@app.name} as the app is in stopped state.")
        end

        it "returns '170001 StagingError' when the app is failed to stage" do
          @app.package_state = "FAILED"
          @app.save

          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))

          expect(last_response.status).to eq(400)
          expect(MultiJson.load(last_response.body)["code"]).to eq(170001)
        end

        it "returns '170002 NotStaged' when the app is pending to be staged" do
          @app.package_state = "PENDING"
          @app.save

          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))

          expect(last_response.status).to eq(400)
          expect(MultiJson.load(last_response.body)["code"]).to eq(170002)
        end

        it "returns '170003 NoAppDetectedError' when the app was not detected by a buildpack" do
          @app.mark_as_failed_to_stage("NoAppDetectedError")
          @app.save

          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))

          expect(last_response.status).to eq(400)
          expect(MultiJson.load(last_response.body)["code"]).to eq(170003)
        end

        it "returns '170004 BuildpackCompileFailed' when the app fails due in the buildpack compile phase" do
          @app.mark_as_failed_to_stage("BuildpackCompileFailed")
          @app.save

          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))

          expect(last_response.status).to eq(400)
          expect(MultiJson.load(last_response.body)["code"]).to eq(170004)
        end

        it "returns '170005 BuildpackReleaseFailed' when the app fails due in the buildpack compile phase" do
          @app.mark_as_failed_to_stage("BuildpackReleaseFailed")
          @app.save

          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))

          expect(last_response.status).to eq(400)
          expect(MultiJson.load(last_response.body)["code"]).to eq(170005)
        end

        it "returns the instances" do
          @app.state = "STARTED"
          @app.instances = 1
          @app.save

          @app.refresh

          instances = {
            0 => {
              :state => "FLAPPING",
              :since => 1,
            },
          }

          expected = {
            "0" => {
              "state" => "FLAPPING",
              "since" => 1,
            },
          }

          allow(instances_reporter).to receive(:all_instances_for_app).and_return(instances)

          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))

          expect(last_response.status).to eq(200)
          expect(MultiJson.load(last_response.body)).to eq(expected)
          expect(instances_reporter).to have_received(:all_instances_for_app).with(
              satisfy {|requested_app| requested_app.guid == @app.guid})
        end
      end

      context "as a non-developer" do
        let(:user) { @user }
        it "returns 403" do
          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))
          expect(last_response.status).to eq(403)
        end
      end
    end
  end
end
