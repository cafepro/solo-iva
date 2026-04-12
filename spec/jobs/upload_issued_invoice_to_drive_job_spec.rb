require "rails_helper"

RSpec.describe UploadIssuedInvoiceToDriveJob, type: :job do
  let(:user) do
    create(:user,
      google_drive_refresh_token: "fake-refresh",
      google_drive_sync_enabled:  true)
  end

  let(:invoice) do
    i = create(:invoice, user: user, invoice_type: :emitida, invoice_number: "F2026001")
    create(:invoice_line, invoice: i, iva_rate: 21, base_imponible: 100.0)
    i.reload
  end

  it "uploads the issued invoice PDF and stores the Drive file id" do
    file = instance_double(Google::Apis::DriveV3::File, id: "drive-emit-1")
    client = instance_double(GoogleDrive::ApiClient, upload_file: file)
    allow(GoogleDrive::ApiClient).to receive(:new).with(refresh_token: user.google_drive_refresh_token).and_return(client)
    allow(Pdf::IssuedInvoicePdf).to receive(:render).and_return(StringIO.new("%PDF"))

    described_class.perform_now(invoice.id)

    expect(invoice.reload.google_drive_file_id).to eq("drive-emit-1")
    expect(invoice.google_drive_synced_at).to be_present
    expect(client).to have_received(:upload_file).with(
      hash_including(
        content_type:         "application/pdf",
        path_prefix_segments: [ "Facturas", "Emitidas" ]
      )
    )
  end

  it "no-ops when Drive is not configured" do
    user.update!(google_drive_refresh_token: nil, google_drive_sync_enabled: false)
    allow(GoogleDrive::ApiClient).to receive(:new)

    described_class.perform_now(invoice.id)

    expect(GoogleDrive::ApiClient).not_to have_received(:new)
  end

  it "no-ops for recibida invoices" do
    rec = create(:invoice, :recibida, user: user)
    create(:invoice_line, invoice: rec)
    allow(GoogleDrive::ApiClient).to receive(:new)

    described_class.perform_now(rec.reload.id)

    expect(GoogleDrive::ApiClient).not_to have_received(:new)
  end
end
