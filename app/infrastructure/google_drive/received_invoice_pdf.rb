require "prawn"
require "prawn/table"

module GoogleDrive
  # User-facing PDF summary of a received invoice (Spanish copy inside the document).
  class ReceivedInvoicePdf
    def self.render(invoice)
      raise ArgumentError, "expected received invoice" unless invoice.recibida?

      pdf = Prawn::Document.new
      pdf.text "Factura recibida — resumen", size: 18, style: :bold
      pdf.move_down 12
      pdf.text "Número: #{invoice.invoice_number}", size: 11
      pdf.text "Fecha: #{invoice.invoice_date&.strftime('%d/%m/%Y')}", size: 11
      pdf.text "Emisor: #{invoice.issuer_name.presence || '—'}", size: 11
      pdf.text "NIF emisor: #{invoice.issuer_nif.presence || '—'}", size: 11
      pdf.move_down 16
      pdf.text "Líneas de IVA", size: 12, style: :bold
      pdf.move_down 6

      if invoice.invoice_lines.any?
        rows = [ %w[Base IVA % Cuota IVA] ]
        invoice.invoice_lines.each do |line|
          rows << [
            format("%.2f", line.base_imponible.to_f),
            "#{line.iva_rate.to_i}%",
            format("%.2f", line.iva_amount.to_f)
          ]
        end
        rows << [ "", "Total (IVA incl.)", format("%.2f", invoice.total) ]

        pdf.table(rows, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
          columns(0..2).align = :right
          row(rows.length - 1).font_style = :bold
        end
      else
        pdf.text "Sin líneas de IVA registradas.", size: 10
      end

      pdf.move_down 20
      pdf.text "Generado por SoloIVA — documento de respaldo, no sustituye la factura original.", size: 8, color: "666666"

      StringIO.new(pdf.render)
    end
  end
end
