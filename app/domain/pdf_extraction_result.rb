# Value object returned by any PDF extractor.
# Provides a consistent structure regardless of extraction strategy used.
class PdfExtractionResult
  attr_reader :invoice_number, :invoice_date, :issuer_name, :issuer_nif, :lines

  def initialize(invoice_number:, invoice_date:, issuer_name:, issuer_nif:, lines:)
    @invoice_number = invoice_number
    @invoice_date   = invoice_date
    @issuer_name    = issuer_name
    @issuer_nif     = issuer_nif
    @lines          = lines || []
  end

  def empty?
    @lines.empty? &&
      @invoice_number.nil? &&
      @invoice_date.nil? &&
      @issuer_name.nil? &&
      @issuer_nif.nil?
  end

  def to_h
    {
      invoice_number: @invoice_number,
      invoice_date:   @invoice_date,
      issuer_name:    @issuer_name,
      issuer_nif:     @issuer_nif,
      lines:          @lines
    }
  end
end
