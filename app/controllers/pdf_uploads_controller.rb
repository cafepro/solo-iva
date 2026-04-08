class PdfUploadsController < ApplicationController
  def destroy
    upload = current_user.pdf_uploads.find(params[:id])

    # Always allow removing the row. Pending/processing: cancels an in-flight upload (the job
    # exits early if the record disappears). Done/failed: clears the item from the queue
    # (invoices already created are unchanged). This avoids 422 when the UI is stale behind
    # Turbo Streams / Action Cable.
    id = upload.id
    upload.destroy!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("pdf_upload_#{id}")
      end
      format.html { redirect_to review_invoices_path, notice: "Subida descartada." }
    end
  end
end
