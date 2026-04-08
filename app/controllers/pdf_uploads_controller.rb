class PdfUploadsController < ApplicationController
  def destroy
    upload = current_user.pdf_uploads.find(params[:id])

    unless upload.pending? || upload.processing?
      respond_to do |format|
        format.turbo_stream { head :unprocessable_content }
        format.html { redirect_to review_invoices_path, alert: "Esta subida ya no se puede cancelar." }
      end
      return
    end

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
