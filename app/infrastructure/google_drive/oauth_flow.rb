require "google/apis/drive_v3"
require "signet/oauth_2/client"

module GoogleDrive
  # Builds OAuth2 URLs and exchanges authorization codes for refresh tokens (Drive scope only).
  class OauthFlow
    SCOPE = Google::Apis::DriveV3::AUTH_DRIVE_FILE

    class << self
      def authorization_url(redirect_uri:, state:)
        client(redirect_uri).authorization_uri(
          state: state,
          access_type: "offline",
          prompt: "consent",
          include_granted_scopes: "true"
        ).to_s
      end

      def exchange_code_for_refresh_token(code:, redirect_uri:)
        c = client(redirect_uri)
        c.code = code
        c.fetch_access_token!
        c.refresh_token || raise(GoogleDrive::Error, "Google did not return a refresh token; revoke app access in Google Account and connect again with prompt=consent.")
      end

      private

      def client(redirect_uri)
        cfg = GoogleDrive::OauthCredentials.to_h
        raise GoogleDrive::Error, "Missing google_oauth credentials (client_id / client_secret)." if cfg[:client_id].blank? || cfg[:client_secret].blank?

        Signet::OAuth2::Client.new(
          client_id:             cfg[:client_id],
          client_secret:         cfg[:client_secret],
          authorization_uri:     "https://accounts.google.com/o/oauth2/auth",
          token_credential_uri:  "https://oauth2.googleapis.com/token",
          scope:                 SCOPE,
          redirect_uri:          redirect_uri
        )
      end
    end
  end
end
