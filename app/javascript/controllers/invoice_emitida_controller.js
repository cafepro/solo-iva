import { Controller } from "@hotwired/stimulus"

const RECIPIENT_FIELD_KEYS = [
  "recipient_name",
  "recipient_nif",
  "recipient_address_line",
  "recipient_postal_code",
  "recipient_city",
  "recipient_province",
  "recipient_country"
]

// Muestra u oculta campos propios de facturas emitidas y rellena periodos de servicio.
export default class extends Controller {
  static targets = ["emitidaSection", "emitidaUpload"]
  static values = {
    serviceTemplatesBase: String,
    clientsSnapshot: { type: Object, default: {} }
  }

  connect() {
    this.boundToggle = this.toggle.bind(this)
    this.typeSelect = this.element.querySelector("#invoice_invoice_type")
    this.typeSelect?.addEventListener("change", this.boundToggle)
    this.toggle()
  }

  disconnect() {
    this.typeSelect?.removeEventListener("change", this.boundToggle)
  }

  toggle() {
    const isEmitida = this.typeSelect?.value === "emitida"
    this.emitidaSectionTargets.forEach((el) => el.classList.toggle("hidden", !isEmitida))
    this.emitidaUploadTargets.forEach((el) => el.classList.toggle("hidden", isEmitida))
  }

  clientChanged(event) {
    const id = event.target.value
    if (!id) {
      this.clearRecipientFields()
      return
    }
    const snapshot = this.clientsSnapshotValue[id]
    if (!snapshot) return

    for (const key of RECIPIENT_FIELD_KEYS) {
      const el = document.getElementById(`invoice_${key}`)
      if (el) el.value = snapshot[key] ?? ""
    }
  }

  clearRecipientFields() {
    for (const key of RECIPIENT_FIELD_KEYS) {
      const el = document.getElementById(`invoice_${key}`)
      if (el) el.value = ""
    }
  }

  setPeriodPreset(event) {
    const preset = event.target.value
    if (!preset) return
    this.applyPeriodFromPreset(preset)
    event.target.selectedIndex = 0
  }

  applyPeriodFromPreset(preset) {
    if (!preset || preset === "custom") return

    const dateEl = document.getElementById("invoice_invoice_date")
    const startEl = document.getElementById("invoice_service_period_start")
    const endEl = document.getElementById("invoice_service_period_end")
    if (!dateEl?.value || !startEl || !endEl) return

    const base = new Date(`${dateEl.value}T12:00:00`)
    let start
    let end

    if (preset === "day") {
      start = end = base
    } else if (preset === "week") {
      const day = base.getDay()
      const mondayOffset = day === 0 ? -6 : 1 - day
      start = new Date(base)
      start.setDate(base.getDate() + mondayOffset)
      end = new Date(start)
      end.setDate(start.getDate() + 6)
    } else if (preset === "month") {
      start = new Date(base.getFullYear(), base.getMonth(), 1)
      end = new Date(base.getFullYear(), base.getMonth() + 1, 0)
    } else {
      return
    }

    startEl.valueAsDate = start
    endEl.valueAsDate = end
  }

  async applyServiceTemplate(event) {
    const id = event.target.value
    if (!id) return

    const basePath = this.hasServiceTemplatesBaseValue ? this.serviceTemplatesBaseValue : ""
    if (!basePath) return

    try {
      const resp = await fetch(`${basePath}/${id}.json`, {
        headers: { Accept: "application/json" }
      })
      if (!resp.ok) throw new Error("fetch failed")
      const data = await resp.json()

      if (data.billing_period && data.billing_period !== "custom") {
        this.applyPeriodFromPreset(data.billing_period)
      }
      this.fillFirstInvoiceLine(data)
      event.target.selectedIndex = 0
    } catch {
      // ignorar errores de red o 404
    }
  }

  fillFirstInvoiceLine(data) {
    const formCtrl = this.application.getControllerForElementAndIdentifier(this.element, "invoice-form")
    if (!formCtrl || !formCtrl.hasLinesContainerTarget) return

    const container = formCtrl.linesContainerTarget
    let row = this.firstEditableLine(container)
    if (!row) {
      formCtrl.addLine()
      row = this.firstEditableLine(container)
    }
    if (!row) return

    const desc = row.querySelector("input[name*='description']")
    if (desc && data.default_description != null && data.default_description !== "") {
      desc.value = data.default_description
    }

    const rateSelect = row.querySelector("select[name*='iva_rate']")
    if (rateSelect && data.default_iva_rate != null && data.default_iva_rate !== "") {
      rateSelect.value = String(parseFloat(data.default_iva_rate, 10))
    }

    const baseInput = row.querySelector("input[name*='base_imponible']")
    if (baseInput && data.default_base_imponible != null && data.default_base_imponible !== "") {
      baseInput.value = parseFloat(data.default_base_imponible, 10).toFixed(2)
    }

    rateSelect?.dispatchEvent(new Event("change", { bubbles: true }))
    baseInput?.dispatchEvent(new Event("input", { bubbles: true }))
  }

  firstEditableLine(container) {
    for (const row of container.querySelectorAll(".line-row")) {
      if (row.style.display === "none") continue
      const dest = row.querySelector("input[name*='_destroy']")
      if (dest && dest.value === "1") continue
      return row
    }
    return null
  }
}
