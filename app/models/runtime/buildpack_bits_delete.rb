module VCAP::CloudController
  class BuildpackBitsDelete
    def self.delete_when_safe(blobstore_key, blobstore_name, config)
      return unless blobstore_key
      blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(blobstore_key, blobstore_name)
      Delayed::Job.enqueue(blobstore_delete, queue: "cc-generic", run_at: Delayed::Job.db_time_now + staging_timeout(config))
    end

    def self.staging_timeout(config)
      config[:staging] && config[:staging][:max_staging_runtime] || 120
    end
  end
end