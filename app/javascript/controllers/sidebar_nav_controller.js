import { Controller } from "@hotwired/stimulus"

// Menú lateral en móvil: drawer + backdrop; en md+ el aside es estático.
export default class extends Controller {
  static targets = ["panel", "backdrop"]

  connect() {
    this._onKeydown = (e) => {
      if (e.key === "Escape") this.close()
    }
    this._onTurboVisit = () => {
      if (window.matchMedia("(max-width: 767px)").matches) this.close()
    }
    document.addEventListener("turbo:visit", this._onTurboVisit)
  }

  open() {
    this.panelTarget.classList.remove("-translate-x-full")
    this.backdropTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this._onKeydown)
  }

  close() {
    this.panelTarget.classList.add("-translate-x-full")
    this.backdropTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this._onKeydown)
  }

  // Cierre al navegar (Turbo) por si el enlace no recarga página entera
  disconnect() {
    document.removeEventListener("keydown", this._onKeydown)
    document.removeEventListener("turbo:visit", this._onTurboVisit)
    document.body.classList.remove("overflow-hidden")
  }
}
