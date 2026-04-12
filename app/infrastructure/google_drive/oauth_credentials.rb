module GoogleDrive
  module OauthCredentials
    class << self
      def to_h
        creds = Rails.application.credentials.fetch(:google_oauth)
        {
          client_id:     creds[:client_id].to_s.presence,
          client_secret: creds[:client_secret].to_s.presence
        }
      rescue NoMethodError, KeyError
        {
          client_id:     ENV.fetch("GOOGLE_OAUTH_CLIENT_ID", nil),
          client_secret: ENV.fetch("GOOGLE_OAUTH_CLIENT_SECRET", nil)
        }
      end
    end
  end
end
