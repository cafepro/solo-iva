import { Controller } from "@hotwired/stimulus"

// Muestra u oculta campos propios de facturas emitidas y rellena periodos de servicio.
export default class extends Controller {
  static targets = ["emitidaSection", "emitidaUpload"]

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

  setPeriodPreset(event) {
    const preset = event.target.value
    const dateEl = document.getElementById("invoice_invoice_date")
    const startEl = document.getElementById("invoice_service_period_start")
    const endEl = document.getElementById("invoice_service_period_end")
    if (!preset || !dateEl?.value || !startEl || !endEl) return

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
    event.target.selectedIndex = 0
  }
}
