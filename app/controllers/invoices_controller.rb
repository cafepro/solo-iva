class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[show edit update destroy]

  SORTABLE_COLUMNS = %w[invoice_number invoice_date invoice_type].freeze

  def index
    @invoices = current_user.invoices.includes(:invoice_lines)
    @invoices = @invoices.where(invoice_type: params[:invoice_type]) if params[:invoice_type].present?

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
    redirect_to invoices_path, notice: "Factura eliminada."
  end

  def upload_pdf
    unless params[:pdf].present?
      return render json: { error: "No se ha subido ningún PDF" }, status: :bad_request
    end

    results = ParsePdfInvoice.new(params[:pdf].tempfile).call

    invoices = results.map do |result|
      data = result.to_h
      data[:duplicate] = current_user.invoices.exists?(invoice_number: result.invoice_number) if result.invoice_number.present?
      data
    end

    render json: { invoices: invoices }
  rescue ParsePdfInvoice::ParseError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

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
