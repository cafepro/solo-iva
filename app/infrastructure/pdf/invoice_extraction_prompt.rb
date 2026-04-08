module Pdf
  # Shared prompt for text-based invoice extraction (Gemini, Groq, etc.).
  class InvoiceExtractionPrompt
    MAX_CHARS = 12_000

    def self.build(text)
      new(text).to_s
    end

    def initialize(text)
      @text = text.to_s
    end

    def to_s
      <<~PROMPT
        Extract all invoices found in the following Spanish invoice text and return them as JSON.
        A single PDF may contain more than one invoice (e.g. a combined water + waste bill).
        If you see different invoice numbers (Nº Factura) or different issuing companies (CIF/razón social del emisor),
        output one entry in "invoices" per invoice — never merge unrelated bills into a single object.
        Return ONLY the raw JSON object — no explanations, no markdown, no code blocks.

        Rules per invoice:
        - "invoice_number": the unique invoice identifier (e.g. "1261042548", "F-2026-001").
          Must contain at least one digit and be longer than 3 characters. Never use a date or generic word.
        - "invoice_date": invoice issue date in YYYY-MM-DD format, or null.
        - "issuer_name": legal name of the company that issued this specific invoice (the supplier/vendor),
          NOT the recipient or customer.
        - "issuer_nif": Spanish tax ID (NIF/CIF) of the issuer, or null if not present.
        - "lines": array of VAT lines for this invoice, each with:
            - "iva_rate": VAT rate as an integer (0, 4, 10 or 21)
            - "base_imponible": taxable base amount in euros as a decimal number
            - "iva_amount": VAT amount in euros as a decimal number
          Merge lines with the same VAT rate into one. Exclude lines where base_imponible is 0.

        Expected JSON format (always return an "invoices" array, even if there is only one):
        {
          "invoices": [
            {
              "invoice_number": "string or null",
              "invoice_date": "YYYY-MM-DD or null",
              "issuer_name": "string or null",
              "issuer_nif": "string or null",
              "lines": [
                { "iva_rate": 21, "base_imponible": 100.00, "iva_amount": 21.00 }
              ]
            }
          ]
        }

        Invoice text:
        #{@text.truncate(MAX_CHARS)}
      PROMPT
    end
  end
end
