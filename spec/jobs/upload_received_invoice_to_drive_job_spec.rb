require "rails_helper"

RSpec.describe UploadReceivedInvoiceToDriveJob, type: :job do
  let(:user) do
    create(:user,
      google_drive_refresh_token: "fake-refresh",
      google_drive_sync_enabled:  true)
  end

  let(:invoice) do
    i = create(:invoice, :recibida, user: user)
    create(:invoice_line, invoice: i)
    i.reload
  end

  it "uploads summary PDF and stores the Drive file id when there is no source upload" do
    file = instance_double(Google::Apis::DriveV3::File, id: "drive-file-1")
    client = instance_double(GoogleDrive::ApiClient, upload_file: file)
    allow(GoogleDrive::ApiClient).to receive(:new).with(refresh_token: user.google_drive_refresh_token).and_return(client)
    allow(GoogleDrive::ReceivedInvoicePdf).to receive(:render).and_return(StringIO.new("%PDF"))

    described_class.perform_now(invoice.id)

    expect(invoice.reload.google_drive_file_id).to eq("drive-file-1")
    expect(invoice.google_drive_synced_at).to be_present
    expect(client).to have_received(:upload_file).with(
      hash_including(content_type: "application/pdf")
    )
  end

  it "uploads the original file from pdf_upload when linked" do
    upload = create(:pdf_upload, user: user, filename: "proveedor.pdf")
    invoice.update!(pdf_upload: upload)

    file = instance_double(Google::Apis::DriveV3::File, id: "drive-original")
    client = instance_double(GoogleDrive::ApiClient, upload_file: file)
    allow(GoogleDrive::ApiClient).to receive(:new).and_return(client)

    described_class.perform_now(invoice.id)

    expect(GoogleDrive::ReceivedInvoicePdf).not_to receive(:render)
    expect(client).to have_received(:upload_file).with(
      hash_including(content_type: "application/pdf")
    )
    expect(invoice.reload.google_drive_file_id).to eq("drive-original")
  end

  it "prefers source_file_data on the invoice (survives PdfUpload destroy)" do
    invoice.update!(
      pdf_upload:        nil,
      source_filename:   "scan.jpg",
      source_file_data:  "%JPEG".b
    )

    file = instance_double(Google::Apis::DriveV3::File, id: "drive-from-source")
    client = instance_double(GoogleDrive::ApiClient, upload_file: file)
    allow(GoogleDrive::ApiClient).to receive(:new).and_return(client)

    described_class.perform_now(invoice.id)

    expect(client).to have_received(:upload_file).with(
      hash_including(content_type: "image/jpeg")
    )
    expect(invoice.reload.google_drive_file_id).to eq("drive-from-source")
  end

  it "no-ops when Drive is not configured" do
    user.update!(google_drive_refresh_token: nil, google_drive_sync_enabled: false)
    allow(GoogleDrive::ApiClient).to receive(:new)

    described_class.perform_now(invoice.id)

    expect(GoogleDrive::ApiClient).not_to have_received(:new)
  end
end
