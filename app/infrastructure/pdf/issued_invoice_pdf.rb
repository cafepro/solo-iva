require "prawn"
require "prawn/table"

module Pdf
  # PDF de factura emitida (Prawn). Diseño limpio, marca SoloIVA, textos en español.
  class IssuedInvoicePdf
    MARGIN_H = 48
    MARGIN_V = 48

    NAVY     = "1D416E"
    TEAL     = "3DB2A4"
    TEXT     = "1f2937"
    MUTED    = "6b7280"
    BORDER       = "e5e7eb"
    RECIPIENT_BG = "E8F6F4"
    # Cabecera: espacio suficiente para título (emisor) a la izquierda y N.º + fecha a la derecha.
    HEADER_H = 58
    HEADER_RIGHT_COL_W = 252

    def self.render(invoice)
      raise ArgumentError, "solo facturas emitidas" unless invoice.emitida?

      Prawn::Fonts::AFM.hide_m17n_warning = true

      pdf = Prawn::Document.new(
        page_size: "A4",
        margin:    [ MARGIN_V, MARGIN_H, MARGIN_V, MARGIN_H ],
        info:      {
          Title:    "Factura #{invoice.invoice_number}",
          Creator:  "SoloIVA",
          Producer: "SoloIVA"
        }
      )

      pdf.font "Helvetica"

      draw_header(pdf, invoice)
      pdf.move_down 22

      draw_section_title(pdf, "Emisor")
      pdf.move_down 6
      draw_issuer(pdf, invoice)
      pdf.move_down 18

      draw_section_title(pdf, "Cliente")
      pdf.move_down 6
      draw_recipient(pdf, invoice)
      pdf.move_down 18

      draw_lines_table(pdf, invoice)
      pdf.move_down 14

      draw_totals(pdf, invoice)
      pdf.move_down 16

      draw_payment_and_notes(pdf, invoice)
      pdf.move_down 12

      draw_footer(pdf)

      StringIO.new(pdf.render)
    end

    def self.draw_header(pdf, invoice)
      w = pdf.bounds.width
      top = pdf.cursor
      pad_x = 14
      gap   = 12
      right_w = [ HEADER_RIGHT_COL_W, w * 0.48 ].min
      left_w  = w - pad_x - gap - right_w

      pdf.save_graphics_state
      pdf.fill_color NAVY
      pdf.fill_rectangle [ 0, top ], w, HEADER_H
      pdf.fill_color "FFFFFF"

      title = header_title(invoice)
      pdf.fill_color "FFFFFF"
      pdf.text_box title,
        at:             [ pad_x, top - 8 ],
        width:          left_w,
        height:         HEADER_H - 12,
        size:           15,
        style:          :bold,
        valign:         :center,
        overflow:       :shrink_to_fit,
        min_font_size:  9

      num = invoice.invoice_number.presence || "—"
      fecha = format_date(invoice.invoice_date)
      right_x = w - right_w - pad_x

      pdf.text_box "N.º #{escape_pdf(num)}\nFecha  #{escape_pdf(fecha)}",
        at:             [ right_x, top - 8 ],
        width:          right_w,
        height:         HEADER_H - 12,
        size:           9,
        align:          :right,
        valign:         :center,
        leading:        5,
        inline_format:  true

      pdf.restore_graphics_state
      pdf.fill_color TEXT
      pdf.move_down HEADER_H + 2
    end

    def self.header_title(invoice)
      u = invoice.user
      u.invoice_pdf_header_title.presence ||
        invoice.issuer_name.presence ||
        u.billing_display_name.presence ||
        "Factura"
    end

    def self.draw_section_title(pdf, title)
      pdf.fill_color TEAL
      pdf.text title.upcase, size: 8, style: :bold, character_spacing: 0.8
      pdf.fill_color TEXT
      pdf.move_down 4
      pdf.stroke_color BORDER
      pdf.line_width 0.5
      pdf.stroke_horizontal_line 0, pdf.bounds.width, at: pdf.cursor
      pdf.move_down 6
    end

    def self.draw_issuer(pdf, invoice)
      u = invoice.user
      pdf.text (invoice.issuer_name.presence || "—").to_s, size: 11, style: :bold
      pdf.move_down 4
      muted_line(pdf, "NIF / CIF  #{invoice.issuer_nif.presence || '—'}")
      pdf.move_down 6

      [
        u.billing_address_line,
        [ u.billing_postal_code, u.billing_city ].compact_blank.join(" "),
        [ u.billing_province, u.billing_country ].compact_blank.join(", ")
      ].compact_blank.each do |line|
        pdf.text line.to_s, size: 9, color: TEXT
        pdf.move_down 2
      end

      pdf.move_down 4
      muted_line(pdf, u.billing_phone) if u.billing_phone.present?
      muted_line(pdf, (u.billing_email.presence || u.email).to_s)
    end

    def self.draw_recipient(pdf, invoice)
      w = pdf.bounds.width
      lines = []
      lines << "<b>#{escape_pdf(invoice.recipient_name.presence || '—')}</b>"
      lines << ""
      lines << "<color rgb='#{MUTED}'>NIF / CIF  #{escape_pdf(invoice.recipient_nif.presence || '—')}</color>"
      lines << ""
      [
        invoice.recipient_address_line,
        [ invoice.recipient_postal_code, invoice.recipient_city ].compact_blank.join(", "),
        [ invoice.recipient_province, invoice.recipient_country ].compact_blank.join(", ")
      ].compact_blank.each { |t| lines << escape_pdf(t) }

      pdf.table(
        [ [ { content: lines.join("\n"), inline_format: true, padding: [ 12, 14, 12, 14 ], valign: :top } ] ],
        width: w,
        cell_style: { borders: [], background_color: RECIPIENT_BG, size: 9 }
      )
    end

    def self.draw_lines_table(pdf, invoice)
      lines = invoice.invoice_lines.to_a
      if lines.empty?
        pdf.text "No hay líneas de detalle.", size: 9, color: MUTED
        return
      end

      w = pdf.bounds.width
      w_desc = w * 0.46
      w_rate = w * 0.12
      w_base = w * 0.21
      w_iva  = w * 0.21

      header = [
        { content: "Concepto", background_color: NAVY, text_color: "FFFFFF", font_style: :bold },
        { content: "% IVA", background_color: NAVY, text_color: "FFFFFF", font_style: :bold, align: :center },
        { content: "Base imponible", background_color: NAVY, text_color: "FFFFFF", font_style: :bold, align: :right },
        { content: "Cuota IVA", background_color: NAVY, text_color: "FFFFFF", font_style: :bold, align: :right }
      ]

      data = [ header ]
      lines.each do |line|
        data << [
          concept_cell(line, invoice),
          "#{line.iva_rate.to_i} %",
          "#{format_money(line.base_imponible)} €",
          "#{format_money(line.iva_amount)} €"
        ]
      end

      pdf.table(data, column_widths: [ w_desc, w_rate, w_base, w_iva ], width: w) do
        cells.style(
          size:         9,
          padding:      [ 7, 8, 7, 8 ],
          borders:      [ :bottom ],
          border_color: BORDER,
          border_width: 0.5,
          valign:       :top
        )
        row(0).borders = [ :bottom ]
        row(0).border_width = 0
        row(0).padding = [ 9, 8, 9, 8 ]
        row(0).valign = :center
        columns(1).align = :center
        columns(2).align = :right
        columns(3).align = :right
      end
    end

    def self.concept_cell(line, invoice)
      desc = line.description.presence || "Concepto"
      if invoice.service_period_start.present? && invoice.service_period_end.present?
        d1 = format_date(invoice.service_period_start)
        d2 = format_date(invoice.service_period_end)
        {
          content:       "#{escape_pdf(desc)}\n<color rgb='#{MUTED}'>Periodo: del #{d1} al #{d2}</color>",
          inline_format: true
        }
      else
        escape_pdf(desc)
      end
    end

    def self.draw_totals(pdf, invoice)
      totals = invoice.totals
      w = pdf.bounds.width
      col_w = [ w * 0.55, w * 0.45 ]

      rows = [
        [ { content: "Base imponible", text_color: MUTED }, "#{format_money(totals.base)} €" ],
        [ { content: "IVA", text_color: MUTED },            "#{format_money(totals.iva)} €" ]
      ]

      pdf.table(rows, column_widths: col_w, width: w) do
        cells.borders = []
        cells.padding = [ 4, 0, 4, 0 ]
        columns(0).align = :right
        columns(1).align = :right
        columns(0).size = 10
        columns(1).size = 10
        columns(1).font_style = :bold
      end

      pdf.move_down 8
      pdf.stroke_color BORDER
      pdf.line_width 1
      pdf.stroke_horizontal_line w - col_w[1], w, at: pdf.cursor
      pdf.move_down 6

      pdf.text "<color rgb='#{MUTED}'>Total factura</color>    <b>#{format_money(totals.total)} €</b>",
        inline_format: true,
        size:          13,
        align:         :right
    end

    def self.draw_payment_and_notes(pdf, invoice)
      u = invoice.user

      if invoice.notes.present?
        pdf.fill_color MUTED
        pdf.text "Observaciones", size: 8, style: :bold
        pdf.fill_color TEXT
        pdf.move_down 3
        pdf.text invoice.notes.to_s, size: 9, leading: 3
        pdf.move_down 10
      end

      note = invoice.payment_signed_note.presence || u.payment_methods_note.presence
      if note.present?
        pdf.fill_color MUTED
        pdf.text "Forma de pago / condiciones", size: 8, style: :bold
        pdf.fill_color TEXT
        pdf.move_down 3
        pdf.text note.to_s, size: 9, leading: 3
        pdf.move_down 8
      end

      rows = []
      rows << [ "Teléfono", u.billing_phone ] if u.billing_phone.present?
      rows << [ "PayPal", u.paypal_email ] if u.paypal_email.present?
      rows << [ "IBAN", u.iban ] if u.iban.present?

      return if rows.empty?

      pdf.fill_color MUTED
      pdf.text "Datos de cobro", size: 8, style: :bold
      pdf.fill_color TEXT
      pdf.move_down 4

      pdf.table(rows, column_widths: [ 72, pdf.bounds.width - 72 ], width: pdf.bounds.width) do
        cells.borders = []
        cells.padding = [ 2, 0, 2, 0 ]
        cells.size = 9
        columns(0).text_color = MUTED
      end
    end

    def self.draw_footer(pdf)
      pdf.move_down 6
      pdf.fill_color MUTED
      pdf.text "Documento generado con SoloIVA · Los importes en euros",
        size: 7,
        align: :center
      pdf.fill_color TEXT
    end

    def self.muted_line(pdf, text)
      pdf.fill_color MUTED
      pdf.text text.to_s, size: 9
      pdf.fill_color TEXT
    end

    def self.format_date(date)
      return "—" if date.blank?

      "#{date.day.to_s.rjust(2, '0')}/#{date.month.to_s.rjust(2, '0')}/#{date.year}"
    end

    def self.format_money(amount)
      format("%.2f", amount.to_f).tr(".", ",")
    end

    def self.escape_pdf(text)
      text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end
