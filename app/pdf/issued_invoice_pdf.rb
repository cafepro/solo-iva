require "prawn"
require "prawn/table"

# PDF de factura emitida (inglés, estilo coworking / servicio).
# Ruta en app/pdf/ para cargar el constante IssuedInvoicePdf (Zeitwerk).
class IssuedInvoicePdf
  def self.render(invoice)
    raise ArgumentError, "solo facturas emitidas" unless invoice.emitida?

    pdf = Prawn::Document.new(margin: [ 40, 50, 40, 50 ])

    pdf.text "Invoice", size: 22, style: :bold
    pdf.move_down 6

    issuer_block(pdf, invoice)
    pdf.move_down 16

    pdf.text "Invoice number:  <b>#{invoice.invoice_number}</b>", inline_format: true, size: 11
    pdf.text "Date:  <b>#{invoice.invoice_date&.strftime('%d/%m/%Y')}</b>", inline_format: true, size: 11
    pdf.move_down 12

    pdf.text "CLIENT:", size: 11, style: :bold
    pdf.move_down 4
    client_block(pdf, invoice)
    pdf.move_down 16

    lines_table(pdf, invoice)
    pdf.move_down 12

    totals_block(pdf, invoice)
    pdf.move_down 16

    payment_block(pdf, invoice)

    pdf.move_down 24
    pdf.text "Generated with SoloIVA", size: 8, color: "666666"

    StringIO.new(pdf.render)
  end

  def self.issuer_block(pdf, invoice)
    pdf.text invoice.issuer_name.to_s, size: 12, style: :bold if invoice.issuer_name.present?
    pdf.text "NIF - #{invoice.issuer_nif}", size: 10 if invoice.issuer_nif.present?
    u = invoice.user
    add_lines(pdf, [
      u.billing_address_line,
      [ u.billing_postal_code, u.billing_city ].compact_blank.join(" "),
      [ u.billing_province, u.billing_country ].compact_blank.join(", ")
    ].compact_blank)
    pdf.text u.billing_phone.to_s, size: 10 if u.billing_phone.present?
    pdf.text u.billing_email.presence || u.email.to_s, size: 10
  end

  def self.client_block(pdf, invoice)
    pdf.text invoice.recipient_name.to_s, size: 11, style: :bold if invoice.recipient_name.present?
    add_lines(pdf, [
      invoice.recipient_address_line,
      [
        invoice.recipient_postal_code,
        invoice.recipient_city
      ].compact_blank.join(" "),
      [
        invoice.recipient_province,
        invoice.recipient_country
      ].compact_blank.join(", ")
    ].compact_blank)
  end

  def self.add_lines(pdf, lines)
    lines.each { |line| pdf.text line.to_s, size: 10 if line.present? }
  end

  def self.lines_table(pdf, invoice)
    rows = [ [ "Service", "price" ] ]
    invoice.invoice_lines.each do |line|
      desc = line.description.presence || "Service"
      rows << [
        period_suffix(desc, invoice),
        "#{format_money(line.base_imponible)} €"
      ]
    end

    if rows.length == 1
      pdf.text "No service lines.", size: 10
      return
    end

    pdf.table(rows, width: pdf.bounds.width, cell_style: { borders: [], padding: [ 4, 6, 4, 0 ], size: 10 }) do
      row(0).font_style = :bold
      columns(1).align = :right
    end
  end

  def self.period_suffix(description, invoice)
    return description.to_s if invoice.service_period_start.blank? || invoice.service_period_end.blank?

    "#{description}\n#{invoice.service_period_start.strftime('%d/%m/%Y')} to #{invoice.service_period_end.strftime('%d/%m/%Y')}"
  end

  def self.totals_block(pdf, invoice)
    pdf.text "Base:  <b>#{format_money(invoice.total_base)} €</b>", inline_format: true, size: 10
    rate_label = if invoice.invoice_lines.any? && invoice.invoice_lines.map { |l| l.iva_rate.to_i }.uniq.length == 1
      "#{invoice.invoice_lines.first.iva_rate.to_i}% IVA / taxes"
    else
      "IVA / taxes"
    end
    pdf.text "#{rate_label}:  <b>#{format_money(invoice.total_iva)} €</b>", inline_format: true, size: 10
    pdf.move_down 4
    pdf.text "Total to pay: <b>#{format_money(invoice.total)} €</b>", inline_format: true, size: 12
  end

  def self.payment_block(pdf, invoice)
    if invoice.payment_signed_note.present?
      pdf.text "Signed:  #{invoice.payment_signed_note}", size: 10
      pdf.move_down 4
    elsif invoice.user.payment_methods_note.present?
      pdf.text "Signed:  #{invoice.user.payment_methods_note}", size: 10
      pdf.move_down 4
    end

    u = invoice.user
    pdf.text "Telephone  #{u.billing_phone}", size: 10 if u.billing_phone.present?
    pdf.text "Paypal  #{u.paypal_email}", size: 10 if u.paypal_email.present?
    pdf.text "IBAN  #{u.iban}", size: 10 if u.iban.present?
  end

  def self.format_money(amount)
    format("%.2f", amount.to_f).tr(".", ",")
  end
end
