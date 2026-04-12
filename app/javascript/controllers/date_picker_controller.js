import { Controller } from "@hotwired/stimulus"

// Abre el selector de fecha nativo del navegador (calendario) desde un botón adjunto.
export default class extends Controller {
  static targets = ["field"]

  open(event) {
    event.preventDefault()
    const el = this.fieldTarget
    if (typeof el.showPicker === "function") {
      el.showPicker()
    } else {
      el.focus()
    }
  }
}
