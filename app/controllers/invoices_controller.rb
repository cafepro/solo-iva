class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[show edit update destroy confirm pdf]

  SORTABLE_COLUMNS = %w[invoice_number invoice_date invoice_type].freeze

  def review
    @pending = current_user.invoices.pending_review.includes(:invoice_lines).order(:created_at)
    @uploads = current_user.pdf_uploads.where(status: %w[pending processing]).order(:created_at)
  end

  def upload_pdfs
    uploads = Array(params[:pdfs]).map { |file| build_pdf_upload_payload(file) }
    render json: { uploads: uploads }
  end

  def confirm
    result    = ConfirmInvoice.new(invoice: @invoice).call
    pending_count = current_user.invoices.pending_review.count

    respond_to do |format|
      format.turbo_stream do
        if result[:ok]
          render turbo_stream: [
            turbo_stream.remove("pending_invoice_#{@invoice.id}"),
            turbo_stream.replace("pending_badge", partial: "layouts/pending_badge", locals: { count: pending_count })
          ]
        else
          render turbo_stream: [
            turbo_stream.replace(
              "pending_invoice_#{@invoice.id}",
              partial: "invoices/pending_invoice_card",
              locals:  {
                invoice:       result[:invoice],
                confirm_error: result[:invoice].errors.full_messages.to_sentence
              }
            ),
            turbo_stream.replace("pending_badge", partial: "layouts/pending_badge", locals: { count: pending_count })
          ], status: :unprocessable_entity
        end
      end
      format.html do
        if result[:ok]
          redirect_to review_invoices_path, notice: "Factura confirmada."
        else
          redirect_to review_invoices_path, alert: result[:invoice].errors.full_messages.to_sentence
        end
      end
    end
  end

  def index
    @invoices = current_user.invoices.for_accounting.includes(:invoice_lines)
    @invoices = @invoices.where(invoice_type: params[:invoice_type]) if params[:invoice_type].present?

    @period_year, @period_quarter = parse_period_params
    @invoices = @invoices.in_calendar_quarter(@period_year, @period_quarter) if @period_year

    @sort    = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : "invoice_number"
    @dir     = params[:dir] == "desc" ? "desc" : "asc"
    @invoices = @invoices.order(@sort => @dir)
  end

  def show
  end

  def pdf
    unless @invoice.emitida?
      redirect_to invoice_path(@invoice), alert: "El PDF de factura solo aplica a emitidas."
      return
    end

    pdf_io = IssuedInvoicePdf.render(@invoice)
    send_data pdf_io.read,
              filename:     "#{@invoice.invoice_number.presence || 'factura'}.pdf",
              type:         "application/pdf",
              disposition:  "attachment"
  end

  def new
    @invoice = current_user.invoices.build(invoice_type: params[:invoice_type].presence)
    @suggested_invoice_number = AssignNextInvoiceNumber.new(current_user).preview
    if @invoice.emitida?
      @invoice.assign_attributes(current_user.default_issuer_attributes_for_invoice)
      @invoice.invoice_number = @suggested_invoice_number
    end
    @invoice.invoice_lines.build
    @clients = current_user.clients.order(:name)
  end

  def edit
    @invoice.invoice_lines.build if @invoice.invoice_lines.empty?
    @clients = current_user.clients.order(:name)
    @suggested_invoice_number = AssignNextInvoiceNumber.new(current_user).preview
  end

  def create
    permitted = invoice_params
    stash     = permitted[:source_stash_token]
    permitted = permitted.except(:source_stash_token)
    auto_num  = params[:use_auto_invoice_number] == "1"
    result = CreateInvoice.new(
      user: current_user, params: permitted, source_stash_token: stash,
      auto_invoice_number: auto_num
    ).call
    @invoice = result[:invoice]

    if result[:ok]
      redirect_to invoices_path, notice: "Factura guardada correctamente."
    else
      @clients = current_user.clients.order(:name)
      @suggested_invoice_number = AssignNextInvoiceNumber.new(current_user).preview
      render :new, status: :unprocessable_entity
    end
  end

  def update
    permitted = invoice_params
    stash     = permitted[:source_stash_token]
    permitted = permitted.except(:source_stash_token)
    result = UpdateInvoice.new(invoice: @invoice, params: permitted, source_stash_token: stash).call
    @invoice = result[:invoice]

    if result[:ok]
      notice = if @invoice.reload.pending?
        "Factura guardada. Sigue en «Revisión» hasta que la confirmes."
      else
        "Factura actualizada correctamente."
      end
      path = @invoice.pending? ? review_invoices_path : invoices_path
      redirect_to path, notice: notice
    else
      @clients = current_user.clients.order(:name)
      @suggested_invoice_number = AssignNextInvoiceNumber.new(current_user).preview if @invoice.emitida?
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    DestroyInvoice.new(invoice: @invoice).call

    case params[:return_to]
    when "review"
      redirect_to review_invoices_path, notice: "Factura eliminada."
    else
      path = invoices_path(
        { invoice_type: params[:invoice_type], year: params[:year], quarter: params[:quarter],
          sort: params[:sort], dir: params[:dir] }.compact_blank
      )
      redirect_to path, notice: "Factura eliminada."
    end
  end

  def bulk_create
    invoices_params = params.require(:invoices).map do |inv|
      inv.permit(
        :invoice_type, :invoice_number, :invoice_date,
        :issuer_name, :issuer_nif, :recipient_name, :recipient_nif, :notes,
        invoice_lines_attributes: %i[iva_rate base_imponible]
      )
    end

    stash = params[:source_stash_token].presence
    result = BulkCreateInvoices.new(
      user:                current_user,
      invoices_params:     invoices_params,
      source_stash_token:  stash
    ).call

    render json: {
      saved:   result.saved.map { |i| { id: i.id, invoice_number: i.invoice_number } },
      skipped: result.skipped.map { |i| { invoice_number: i.invoice_number, errors: i.errors.full_messages } }
    }
  end

  def upload_pdf
    unless params[:pdf].present?
      return render json: { error: "No se ha subido ningún archivo" }, status: :bad_request
    end

    uploaded = params[:pdf]
    raw      = uploaded.read.to_s.b

    results = ParseInvoiceDocument.new(
      StringIO.new(raw),
      filename: uploaded.original_filename
    ).call

    stash_token = InvoiceUploadStash.store!(
      user:      current_user,
      file_data: raw,
      filename:  uploaded.original_filename
    )

    invoices = results.map do |result|
      data = result.to_h
      if result.invoice_number.present?
        data[:duplicate] = current_user.invoices.for_accounting.exists?(invoice_number: result.invoice_number)
      end
      data
    end

    payload = { invoices: invoices, source_stash_token: stash_token }
    if invoices.empty?
      payload[:extraction_note] =
        "No se extrajo ninguna factura. Suele deberse a límites de cuota de las APIs (429), " \
        "a un PDF sin texto seleccionable, a una foto borrosa o con poca luz, o a un formato no soportado. " \
        "Prueba más tarde o revisa las claves en credentials (Gemini / Groq)."
    end

    render json: payload
  rescue ParsePdfInvoice::ParseError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def parse_period_params
    y = params[:year].presence&.to_i
    q = params[:quarter].presence&.to_i
    return [ nil, nil ] if y.blank? || q.blank?
    return [ nil, nil ] if y < 2000 || y > 2100
    return [ nil, nil ] if q < 1 || q > 4

    [ y, q ]
  end

  def set_invoice
    @invoice = current_user.invoices.find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(
      :invoice_type, :invoice_number, :invoice_date,
      :issuer_name, :issuer_nif, :recipient_name, :recipient_nif, :notes,
      :client_id, :recipient_address_line, :recipient_postal_code, :recipient_city,
      :recipient_province, :recipient_country, :service_period_start, :service_period_end,
      :payment_signed_note, :source_stash_token,
      invoice_lines_attributes: %i[id description iva_rate base_imponible _destroy]
    )
  end

  def build_pdf_upload_payload(file)
    upload = CreatePdfUpload.new(user: current_user, file: file).call
    {
      id:       upload.id,
      filename: upload.filename,
      status:   upload.status,
      html:     render_to_string(
        partial: "invoices/pdf_upload_row",
        locals:  { upload: upload },
        layout:  false,
        formats: [ :html ]
      )
    }
  rescue ArgumentError => e
    {
      filename: file.original_filename,
      error:    e.message
    }
  end
end
