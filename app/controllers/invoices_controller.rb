class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[show edit update destroy confirm]

  SORTABLE_COLUMNS = %w[invoice_number invoice_date invoice_type].freeze

  def review
    @pending = current_user.invoices.pending_review.includes(:invoice_lines).order(:created_at)
    @uploads = current_user.pdf_uploads.where(status: %w[pending processing]).order(:created_at)
  end

  def upload_pdfs
    uploads = Array(params[:pdfs]).map do |file|
      CreatePdfUpload.new(user: current_user, file: file).call
    end
    render json: {
      uploads: uploads.map do |u|
        {
          id:       u.id,
          filename: u.filename,
          status:   u.status,
          html:     render_to_string(
            partial: "invoices/pdf_upload_row",
            locals:  { upload: u },
            layout:  false,
            formats: [ :html ]
          )
        }
      end
    }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def confirm
    ConfirmInvoice.new(invoice: @invoice).call
    pending_count = current_user.invoices.pending_review.count

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("pending_invoice_#{@invoice.id}"),
          turbo_stream.replace("pending_badge", partial: "layouts/pending_badge", locals: { count: pending_count })
        ]
      end
      format.html { redirect_to review_invoices_path }
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

  def new
    @invoice = current_user.invoices.build(invoice_type: params[:invoice_type].presence)
    @invoice.invoice_lines.build
  end

  def edit
    @invoice.invoice_lines.build if @invoice.invoice_lines.empty?
  end

  def create
    result = CreateInvoice.new(user: current_user, params: invoice_params).call
    @invoice = result[:invoice]

    if result[:ok]
      redirect_to invoices_path, notice: "Factura guardada correctamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    result = UpdateInvoice.new(invoice: @invoice, params: invoice_params).call
    @invoice = result[:invoice]

    if result[:ok]
      redirect_to invoices_path, notice: "Factura actualizada correctamente."
    else
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

    result = BulkCreateInvoices.new(user: current_user, invoices_params: invoices_params).call

    render json: {
      saved:   result.saved.map { |i| { id: i.id, invoice_number: i.invoice_number } },
      skipped: result.skipped.map { |i| { invoice_number: i.invoice_number, errors: i.errors.full_messages } }
    }
  end

  def upload_pdf
    unless params[:pdf].present?
      return render json: { error: "No se ha subido ningún PDF" }, status: :bad_request
    end

    results = ParsePdfInvoice.new(params[:pdf].tempfile).call

    invoices = results.map do |result|
      data = result.to_h
      if result.invoice_number.present?
        data[:duplicate] = current_user.invoices.for_accounting.exists?(invoice_number: result.invoice_number)
      end
      data
    end

    payload = { invoices: invoices }
    if invoices.empty?
      payload[:extraction_note] =
        "No se extrajo ninguna factura. Suele deberse a límites de cuota de las APIs de IA (error 429), " \
        "a un PDF escaneado sin texto seleccionable o a un formato que aún no reconocemos. " \
        "Prueba más tarde o comprueba las claves en credentials (Gemini / Groq)."
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
      invoice_lines_attributes: %i[id iva_rate base_imponible _destroy]
    )
  end
end
