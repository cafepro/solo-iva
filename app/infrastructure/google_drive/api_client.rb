require "google/apis/drive_v3"
require "googleauth"

module GoogleDrive
  # Creates folder path: prefix segments + YYYY + MM, then uploads a file with the given MIME type.
  class ApiClient
    ROOT_PARENT = "root".freeze

    def initialize(refresh_token:)
      @refresh_token = refresh_token
      @drive         = Google::Apis::DriveV3::DriveService.new
      @drive.authorization = authorization
    end

    # @param path_prefix_segments [Array<String>] e.g. ["Facturas", "Recibidas"] before year/month
    def upload_file(io:, filename:, content_type:, path_prefix_segments:, year:, month:)
      parent_id = ROOT_PARENT
      Array(path_prefix_segments).each do |segment|
        next if segment.blank?

        parent_id = find_or_create_folder(segment.to_s, parent_id: parent_id)
      end

      year_id  = find_or_create_folder(year.to_s, parent_id: parent_id)
      month_id = find_or_create_folder(format("%02d", month.to_i), parent_id: year_id)

      metadata = Google::Apis::DriveV3::File.new(name: safe_upload_filename(filename), parents: [ month_id ])
      io.rewind if io.respond_to?(:rewind)
      @drive.create_file(
        metadata,
        upload_source: io,
        content_type:  content_type,
        fields:        "id"
      )
    end

    private

    def authorization
      cfg = GoogleDrive::OauthCredentials.to_h
      Google::Auth::UserRefreshCredentials.new(
        client_id:     cfg[:client_id],
        client_secret: cfg[:client_secret],
        scope:         Google::Apis::DriveV3::AUTH_DRIVE_FILE,
        refresh_token: @refresh_token
      )
    end

    def find_or_create_folder(name, parent_id:)
      existing = find_child_folder(name, parent_id: parent_id)
      return existing.id if existing

      metadata = Google::Apis::DriveV3::File.new(
        name:      name,
        mime_type: "application/vnd.google-apps.folder",
        parents:   [ parent_id ]
      )
      created = @drive.create_file(metadata, fields: "id")
      created.id
    end

    def find_child_folder(name, parent_id:)
      escaped = name.gsub("'", "\\'")
      q = [
        "name = '#{escaped}'",
        "'#{parent_id}' in parents",
        "mimeType = 'application/vnd.google-apps.folder'",
        "trashed = false"
      ].join(" and ")
      res = @drive.list_files(q: q, spaces: "drive", fields: "files(id, name)", page_size: 1)
      res.files&.first
    end

    def safe_upload_filename(name)
      base = File.basename(name.to_s).strip
      base = base.gsub(/[^\w.\-]+/, "_")
      base.presence || "documento"
    end
  end
end
