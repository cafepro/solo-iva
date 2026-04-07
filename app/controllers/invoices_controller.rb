class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[show edit update destroy]

  def index
    @invoices = current_user.invoices.includes(:invoice_lines).order(invoice_date: :desc)
    @invoices = @invoices.where(invoice_type: params[:invoice_type]) if params[:invoice_type].present?
  end

  def show
  end

  def new
    @invoice = current_user.invoices.build
    @invoice.invoice_lines.build
  end

  def edit
    @invoice.invoice_lines.build if @invoice.invoice_lines.empty?
  end

  def create
    @invoice = current_user.invoices.build(invoice_params)
    if @invoice.save
      redirect_to invoices_path, notice: "Factura guardada correctamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @invoice.update(invoice_params)
      redirect_to invoices_path, notice: "Factura actualizada correctamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @invoice.destroy
    redirect_to invoices_path, notice: "Factura eliminada."
  end

  def upload_pdf
    unless params[:pdf].present?
      return render json: { error: "No se ha subido ningún PDF" }, status: :bad_request
    end

    parsed = PdfInvoiceParser.new(params[:pdf].tempfile).parse
    render json: parsed
  rescue PdfInvoiceParser::ParseError => e
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
