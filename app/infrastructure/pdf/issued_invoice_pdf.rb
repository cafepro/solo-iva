require "prawn"
require "prawn/table"

module Pdf
  # PDF de factura emitida — estilo plantilla tipo F2026013 / F2026020 (banda naranja, Service/price).
  class IssuedInvoicePdf
    MARGIN_H = 48
    MARGIN_V = 44
    ACCENT_ORANGE = "F79646"
    TEXT_MUTED = "555555"
    RULE_COLOR = "DDDDDD"
    BANNER_HEIGHT = 44
    SECTION_BAR_H = 22
    # Cabecera tabla: ~68% / ~32% como en el PDF de referencia
    SERVICE_COL_FRAC = 0.681
    PRICE_COL_FRAC = 0.319

    def self.render(invoice)
      raise ArgumentError, "solo facturas emitidas" unless invoice.emitida?

      Prawn::Fonts::AFM.hide_m17n_warning = true

      pdf = Prawn::Document.new(
        page_size: "A4",
        margin:    [ MARGIN_V, MARGIN_H, MARGIN_V, MARGIN_H ],
        info:      { Title: "Invoice #{invoice.invoice_number}" }
      )

      top_banner(pdf, invoice)
      pdf.move_down 12

      issuer_and_meta_row(pdf, invoice)
      pdf.move_down 16

      orange_section_bar(pdf, "CLIENT:")
      # Separar claramente el bloque cliente de la barra naranja (evita solapamiento visual)
      pdf.move_down 12
      client_block(pdf, invoice)
      pdf.move_down 14

      lines_table(pdf, invoice)
      pdf.move_down 10

      discount_placeholder_row(pdf, invoice)
      totals_block(pdf, invoice)
      pdf.move_down 14

      payment_block(pdf, invoice)
      pdf.move_down 16

      legal_footer(pdf)

      StringIO.new(pdf.render)
    end

    def self.top_banner(pdf, invoice)
      w = pdf.bounds.width
      top = pdf.cursor
      y0 = top - BANNER_HEIGHT

      pdf.save_graphics_state
      pdf.fill_color ACCENT_ORANGE
      pdf.fill_rectangle [ 0, y0 ], w, BANNER_HEIGHT

      logo_r = 15
      cx = 18 + logo_r
      cy = y0 + BANNER_HEIGHT / 2.0
      draw_initials_badge(pdf, invoice, cx, cy, logo_r)

      pdf.fill_color "FFFFFF"
      pdf.text_box "Invoice",
        at:       [ 52, y0 + BANNER_HEIGHT - 32 ],
        width:    w - 60,
        height:   34,
        size:     20,
        style:    :bold,
        valign:   :center
      pdf.restore_graphics_state

      pdf.fill_color "000000"
      pdf.move_down BANNER_HEIGHT
    end

    def self.draw_initials_badge(pdf, invoice, cx, cy, radius)
      initials = initials_for(invoice)
      pdf.fill_color "FFFFFF"
      pdf.fill do
        pdf.circle [ cx, cy ], radius
      end
      pdf.fill_color ACCENT_ORANGE
      pdf.text_box initials.upcase,
        at:     [ cx - radius - 1, cy - 6 ],
        width:  radius * 2 + 2,
        height: 16,
        align:  :center,
        valign: :center,
        size:   11,
        style:  :bold
      pdf.fill_color "000000"
    end

    def self.initials_for(invoice)
      name = invoice.issuer_name.presence || invoice.user.billing_display_name.presence || invoice.user.email.to_s
      parts = name.to_s.split(/\s+/).reject(&:blank?).first(2)
      return "IV" if parts.empty?

      parts.map { |p| p[0] }.join
    end

    def self.issuer_and_meta_row(pdf, invoice)
      u = invoice.user
      w = pdf.bounds.width
      left_w = w * 0.52
      right_w = w - left_w
      num = invoice.invoice_number.presence || "—"
      dt  = format_invoice_date(invoice.invoice_date)

      left_lines = []
      left_lines << "<b>#{pdf_escape(invoice.issuer_name.presence || '—')}</b>"
      left_lines << ""
      left_lines << "<color rgb='#{TEXT_MUTED}'>NIF - #{pdf_escape(invoice.issuer_nif.presence || '—')}</color>"
      left_lines << ""
      left_lines.concat(
        [
          u.billing_address_line,
          [ u.billing_postal_code, u.billing_city ].compact_blank.join(" "),
          [ u.billing_province, u.billing_country ].compact_blank.join(", ")
        ].compact_blank.map { |t| pdf_escape(t) }
      )
      left_lines << ""
      left_lines << "<color rgb='#{TEXT_MUTED}'>#{pdf_escape(u.billing_phone)}</color>" if u.billing_phone.present?
      left_lines << "<color rgb='#{TEXT_MUTED}'>#{pdf_escape(u.billing_email.presence || u.email.to_s)}</color>"

      right_lines = []
      right_lines << "<color rgb='#{TEXT_MUTED}'>Invoice number:</color>  <b>#{pdf_escape(num)}</b>"
      right_lines << ""
      right_lines << "<color rgb='#{TEXT_MUTED}'>Date:</color>  <b>#{pdf_escape(dt)}</b>"

      pdf.table(
        [
          [
            { content: left_lines.join("\n"), inline_format: true, valign: :top, padding: [ 2, 4, 6, 0 ] },
            { content: right_lines.join("\n"), inline_format: true, valign: :top, align: :right, padding: [ 2, 0, 6, 12 ] }
          ]
        ],
        column_widths: [ left_w, right_w ],
        width:         w
      ) do
        cells.borders = []
        columns(0).size = 9
        columns(1).size = 10
      end
    end

    def self.format_invoice_date(date)
      return "—" if date.blank?

      "#{date.day}/#{date.month}/#{date.year}"
    end

    def self.orange_section_bar(pdf, label)
      w = pdf.bounds.width
      top = pdf.cursor
      y0 = top - SECTION_BAR_H

      pdf.fill_color ACCENT_ORANGE
      pdf.fill_rectangle [ 0, y0 ], w, SECTION_BAR_H
      pdf.fill_color "FFFFFF"
      pdf.text_box label,
        at:     [ 10, y0 + SECTION_BAR_H - 20 ],
        width:  w - 20,
        height: SECTION_BAR_H,
        size:   10,
        style:  :bold,
        valign: :center
      pdf.fill_color "000000"
      pdf.move_down SECTION_BAR_H
    end

    def self.client_block(pdf, invoice)
      pdf.text (invoice.recipient_name.presence || "—").to_s, size: 11, style: :bold
      pdf.move_down 3
      pdf.fill_color TEXT_MUTED
      pdf.text (invoice.recipient_nif.presence || "—").to_s, size: 9
      pdf.fill_color "000000"
      pdf.move_down 5
      add_lines(pdf, [
        invoice.recipient_address_line,
        [
          invoice.recipient_postal_code,
          invoice.recipient_city
        ].compact_blank.join(", "),
        [
          invoice.recipient_province,
          invoice.recipient_country
        ].compact_blank.join(", ")
      ].compact_blank, size: 9)
    end

    def self.add_lines(pdf, lines, size: 10)
      lines.each { |line| pdf.text line.to_s, size: size if line.present? }
    end

    def self.lines_table(pdf, invoice)
      lines = invoice.invoice_lines.to_a

      if lines.empty?
        pdf.text "No service lines.", size: 9, color: TEXT_MUTED
        return
      end

      w = pdf.bounds.width
      w_svc = w * SERVICE_COL_FRAC
      w_price = w * PRICE_COL_FRAC

      data = [
        [
          { content: "Service", background_color: ACCENT_ORANGE, text_color: "FFFFFF", font_style: :bold,
            align: :left },
          { content: "price", background_color: ACCENT_ORANGE, text_color: "FFFFFF", font_style: :bold,
            align: :right }
        ]
      ]
      lines.each do |line|
        desc = line.description.presence || "Service"
        desc = period_suffix(desc, invoice)
        data << [ desc, "#{format_money(line.base_imponible)} €" ]
      end

      pdf.table(data, column_widths: [ w_svc, w_price ], width: w) do
        cells.style(
          size:          9,
          padding:       [ 6, 10, 6, 10 ],
          borders:       [ :bottom ],
          border_color:  RULE_COLOR,
          border_width:  0.5,
          valign:        :top
        )
        row(0).borders = [ :bottom ]
        row(0).border_width = 0
        row(0).padding = [ 8, 10, 8, 10 ]
        row(0).valign = :center
        columns(1).align = :right
      end
    end

    def self.period_suffix(description, invoice)
      return description.to_s if invoice.service_period_start.blank? || invoice.service_period_end.blank?

      d1 = format_invoice_date(invoice.service_period_start)
      d2 = format_invoice_date(invoice.service_period_end)
      "#{description}\n#{d1} to #{d2}"
    end

    def self.discount_placeholder_row(pdf, invoice)
      return if invoice.invoice_lines.empty?

      pdf.fill_color TEXT_MUTED
      pdf.text "DTO.-", size: 9
      pdf.fill_color "000000"
      pdf.move_down 8
    end

    def self.totals_block(pdf, invoice)
      totals = invoice.totals
      base = totals.base
      iva_total = totals.iva
      grand = totals.total

      rate_label = if invoice.invoice_lines.any? && invoice.invoice_lines.map { |l| l.iva_rate.to_i }.uniq.length == 1
        "#{invoice.invoice_lines.first.iva_rate.to_i}% IVA / taxes:"
      else
        "IVA / taxes:"
      end

      w = pdf.bounds.width
      col_w = w * 0.48
      x0 = w - col_w

      pdf.bounding_box([ x0, pdf.cursor ], width: col_w) do
        pdf.text "<color rgb='#{TEXT_MUTED}'>Base:</color>    <b>#{format_money(base)} €</b>",
          inline_format: true, size: 10, align: :right, leading: 2
        pdf.move_down 6
        pdf.text "<color rgb='#{TEXT_MUTED}'>#{pdf_escape(rate_label)}</color>    <b>#{format_money(iva_total)} €</b>",
          inline_format: true, size: 10, align: :right, leading: 2
        pdf.move_down 10
        pdf.text "Total to pay:    <b>#{format_money(grand)} €</b>",
          inline_format: true, size: 12, style: :bold, align: :right
      end
    end

    def self.payment_block(pdf, invoice)
      u = invoice.user
      note = invoice.payment_signed_note.presence || u.payment_methods_note.presence
      if note.present?
        pdf.text "<color rgb='#{TEXT_MUTED}'>Signed:</color>  #{pdf_escape(note)}",
          inline_format: true, size: 9
        pdf.move_down 5
      end

      pdf.fill_color TEXT_MUTED
      pdf.text "Telephone  #{pdf_escape(u.billing_phone)}", size: 9 if u.billing_phone.present?
      pdf.text "Paypal  #{pdf_escape(u.paypal_email)}", size: 9 if u.paypal_email.present?
      pdf.text "IBAN  #{pdf_escape(u.iban)}", size: 9 if u.iban.present?
      pdf.fill_color "000000"
    end

    def self.legal_footer(pdf)
      pdf.move_down 8
      pdf.fill_color TEXT_MUTED
      pdf.text "Generated with SoloIVA", size: 7, align: :center
      pdf.fill_color "000000"
    end

    def self.pdf_escape(text)
      text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end

    def self.format_money(amount)
      format("%.2f", amount.to_f).tr(".", ",")
    end
  end
end
