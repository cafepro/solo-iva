import { Controller } from "@hotwired/stimulus"

// Manages the invoice form: PDF drag-and-drop upload, IVA line management.
export default class extends Controller {
  static targets = ["dropzone", "fileInput", "status", "linesContainer", "lineTemplate"]
  static values  = { uploadUrl: String, lineIndex: Number }

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
    this.dropzoneTarget.classList.add("bg-blue-100", "border-blue-500")
  }

  onDragLeave(event) {
    if (!this.dropzoneTarget.contains(event.relatedTarget)) {
      this.dropzoneTarget.classList.remove("bg-blue-100", "border-blue-500")
    }
  }

  onDrop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("bg-blue-100", "border-blue-500")
    const file = event.dataTransfer.files[0]
    if (file) this.uploadPdf(file)
  }

  openFilePicker() {
    this.fileInputTarget.click()
  }

  async uploadPdf(file) {
    this.setStatus("Procesando PDF...")

    const formData = new FormData()
    formData.append("pdf", file)
    formData.append("authenticity_token", document.querySelector('meta[name="csrf-token"]').content)

    try {
      const resp = await fetch(this.uploadUrlValue, { method: "POST", body: formData })
      const data = await resp.json()

      if (data.error) {
        this.setStatus("Error: " + data.error)
        return
      }

      this.fillForm(data)
      this.setStatus("PDF cargado correctamente. Revisa los datos antes de guardar.")
    } catch {
      this.setStatus("Error al procesar el PDF.")
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
        const rateSelect = row.querySelector("select")
        const baseInput  = row.querySelectorAll("input[type='number']")[0]
        const quotaInput = row.querySelectorAll("input[type='number']")[1]
        if (rateSelect) rateSelect.value = line.iva_rate
        if (baseInput)  baseInput.value  = line.base_imponible
        if (quotaInput) quotaInput.value = line.iva_amount
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
    const quotaInput = row.querySelectorAll("input[type='number']")[1]

    const updateQuota = () => {
      const base = parseFloat(baseInput?.value) || 0
      const rate = parseFloat(rateSelect?.value) || 0
      if (quotaInput) quotaInput.value = (base * rate / 100).toFixed(2)
    }

    rateSelect?.addEventListener("change", updateQuota)
    baseInput?.addEventListener("input", updateQuota)
  }

  // --- Helpers ---

  setStatus(text) {
    this.statusTarget.textContent = text
    this.statusTarget.classList.remove("hidden")
  }
}
