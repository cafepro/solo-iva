import { Controller } from "@hotwired/stimulus"

// Manages the invoice form: PDF or photo upload, IVA line management.
export default class extends Controller {
  static targets = ["dropzone", "fileInput", "status", "linesContainer", "lineTemplate", "picker"]
  static values  = { uploadUrl: String, bulkCreateUrl: String, lineIndex: Number }

  connect() {
    this.element.querySelectorAll(".line-row").forEach(row => this.attachLineEvents(row))
  }

  // --- PDF upload ---

  onFileChange(event) {
    const file = event.target.files[0]
    if (file) this.uploadPdf(file)
  }

  onDragOver(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("bg-brand-teal-soft", "border-brand-teal")
  }

  onDragLeave(event) {
    if (!this.dropzoneTarget.contains(event.relatedTarget)) {
      this.dropzoneTarget.classList.remove("bg-brand-teal-soft", "border-brand-teal")
    }
  }

  onDrop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("bg-brand-teal-soft", "border-brand-teal")
    const file = event.dataTransfer.files[0]
    if (file) this.uploadPdf(file)
  }

  openFilePicker() {
    this.fileInputTarget.click()
  }

  async uploadPdf(file) {
    this.setStatus("Procesando archivo…")
    this.removePicker()

    const formData = new FormData()
    formData.append("pdf", file)
    formData.append("authenticity_token", document.querySelector('meta[name="csrf-token"]').content)

    try {
      const resp = await fetch(this.uploadUrlValue, { method: "POST", body: formData })
      const data = await resp.json()

      if (data.error) { this.setStatus("Error: " + data.error); return }

      this.setSourceStashToken(data.source_stash_token)

      const invoices = data.invoices || []
      if (invoices.length === 0) {
        this.setStatus(data.extraction_note || "No se encontraron facturas en el archivo.")
        return
      }

      if (invoices.length === 1) {
        this.loadInvoice(invoices[0])
      } else {
        this.setStatus(`Se encontraron ${invoices.length} facturas. Selecciona cuál importar:`)
        this.showPicker(invoices)
      }
    } catch {
      this.setStatus("Error al procesar el archivo.")
    }
  }

  // --- Multi-invoice picker ---

  showPicker(invoices) {
    this.removePicker()

    const container = document.createElement("div")
    container.setAttribute("data-invoice-form-target", "picker")
    container.className = "mt-3 flex flex-col gap-2"

    invoices.forEach((inv, i) => {
      const label = [inv.issuer_name, inv.invoice_number, inv.invoice_date].filter(Boolean).join(" · ")
      const badge = inv.duplicate
        ? `<span class="ml-2 text-xs text-amber-600 font-medium">⚠️ posible duplicado</span>`
        : ""

      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "text-left px-3 py-2 rounded border border-gray-200 bg-white hover:bg-brand-teal-muted hover:border-brand-teal/40 text-sm transition-colors"
      btn.innerHTML = `<span class="font-medium">${label}</span>${badge}`
      btn.addEventListener("click", () => { this.loadInvoice(invoices[i]); this.removePicker() })
      container.appendChild(btn)
    })

    // "Save all" button — only shown when none are duplicates
    const nonDuplicates = invoices.filter(inv => !inv.duplicate)
    if (nonDuplicates.length > 1) {
      const saveAll = document.createElement("button")
      saveAll.type = "button"
      saveAll.className = "mt-1 px-3 py-2 rounded bg-brand-teal text-white text-sm font-medium hover:bg-brand-teal-dark transition-colors"
      saveAll.textContent = `Guardar las ${nonDuplicates.length} facturas`
      saveAll.addEventListener("click", () => this.saveAll(nonDuplicates))
      container.appendChild(saveAll)
    }

    this.dropzoneTarget.after(container)
  }

  async saveAll(invoices) {
    this.setStatus("Guardando facturas...")

    const invoicesData = invoices.map(inv => ({
      invoice_type:   inv.invoice_type || "recibida",
      invoice_number: inv.invoice_number,
      invoice_date:   inv.invoice_date,
      issuer_name:    inv.issuer_name,
      issuer_nif:     inv.issuer_nif,
      invoice_lines_attributes: (inv.lines || []).map(l => ({
        iva_rate:       l.iva_rate,
        base_imponible: l.base_imponible
      }))
    }))

    try {
      const resp = await fetch(this.bulkCreateUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          invoices: invoicesData,
          source_stash_token: this.sourceStashTokenValue()
        })
      })
      const data = await resp.json()

      const savedCount   = data.saved?.length   || 0
      const skippedCount = data.skipped?.length || 0

      if (savedCount > 0) {
        this.setSourceStashToken("")
      }

      if (skippedCount > 0) {
        this.setStatus(`${savedCount} factura(s) guardadas. ${skippedCount} no pudieron guardarse (revisa duplicados).`, "warning")
      } else {
        this.setStatus(`${savedCount} factura(s) guardadas correctamente.`, "ok")
      }

      this.removePicker()
    } catch {
      this.setStatus("Error al guardar las facturas.", "warning")
    }
  }

  removePicker() {
    if (this.hasPickerTarget) this.pickerTarget.remove()
  }

  // --- Form fill ---

  loadInvoice(inv) {
    this.fillForm(inv)

    if (inv.duplicate) {
      this.setStatus("⚠️ Ya existe una factura con el número " + inv.invoice_number + ". Revisa que no sea un duplicado.", "warning")
    } else {
      this.setStatus("Datos cargados. Revisa antes de guardar.", "ok")
    }
  }

  fillForm(data) {
    const set = (id, value) => { if (value) { const el = document.getElementById(id); if (el) el.value = value } }

    set("invoice_invoice_number", data.invoice_number)
    set("invoice_invoice_date",   data.invoice_date)
    set("invoice_issuer_name",    data.issuer_name)
    set("invoice_issuer_nif",     data.issuer_nif)

    if (data.lines && data.lines.length > 0) {
      this.linesContainerTarget.innerHTML = ""
      data.lines.forEach(line => {
        const row = this.buildLineRow()
        const rateSelect = row.querySelector("select[name*='iva_rate']")
        const baseInput  = row.querySelector("input[name*='base_imponible']")
        const quotaInput = row.querySelector("input[type='number'][readonly]")
        if (rateSelect) rateSelect.value = line.iva_rate
        if (baseInput)  baseInput.value  = parseFloat(line.base_imponible).toFixed(2)
        if (quotaInput) quotaInput.value = parseFloat(line.iva_amount).toFixed(2)
        this.linesContainerTarget.appendChild(row)
        this.attachLineEvents(row)
      })
    }
  }

  // --- Line management ---

  addLine() {
    const row = this.buildLineRow()
    this.linesContainerTarget.appendChild(row)
    this.attachLineEvents(row)
  }

  buildLineRow() {
    const html = this.lineTemplateTarget.innerHTML.replace(/NEW_RECORD/g, this.lineIndexValue)
    this.lineIndexValue++
    const div = document.createElement("div")
    div.innerHTML = html
    return div.firstElementChild
  }

  attachLineEvents(row) {
    row.querySelector(".remove-line")?.addEventListener("click", () => {
      const destroyInput = row.querySelector("input[name*='_destroy']")
      if (destroyInput) { destroyInput.value = "1"; row.style.display = "none" }
      else row.remove()
    })

    const rateSelect = row.querySelector("select[name*='iva_rate']")
    const baseInput  = row.querySelector("input[name*='base_imponible']")
    const quotaInput = row.querySelector("input[type='number'][readonly]")

    const updateQuota = () => {
      const base = parseFloat(baseInput?.value) || 0
      const rate = parseFloat(rateSelect?.value) || 0
      if (quotaInput) quotaInput.value = (base * rate / 100).toFixed(2)
    }

    rateSelect?.addEventListener("change", updateQuota)
    baseInput?.addEventListener("input", updateQuota)
  }

  // --- Helpers ---

  setSourceStashToken(token) {
    const el = document.getElementById("invoice_source_stash_token")
    if (el) el.value = token || ""
  }

  sourceStashTokenValue() {
    const el = document.getElementById("invoice_source_stash_token")
    return el?.value || null
  }

  setStatus(text, type = "ok") {
    const el = this.statusTarget
    el.textContent = text
    el.classList.remove("hidden", "text-brand-navy", "text-amber-700")
    el.classList.add(type === "warning" ? "text-amber-700" : "text-brand-navy")
  }
}
