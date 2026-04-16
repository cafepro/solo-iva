import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { checkUrl: String, provider: String }
  static targets = ["token", "message"]

  async verify(event) {
    event.preventDefault()
    if (!this.hasMessageTarget) return

    this.messageTarget.textContent = "Comprobando…"
    this.messageTarget.className = "text-xs text-gray-500"

    const token = this.hasTokenTarget ? this.tokenTarget.value.trim() : ""
    const csrf = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")

    try {
      const response = await fetch(this.checkUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": csrf || ""
        },
        body: JSON.stringify({ provider: this.providerValue, api_key: token })
      })

      const data = await response.json().catch(() => ({}))
      const msg = data.message || "No se pudo interpretar la respuesta."
      this.messageTarget.textContent = msg

      if (data.ok) {
        this.messageTarget.className = "text-xs text-green-700 font-medium"
      } else {
        this.messageTarget.className = "text-xs text-red-700"
      }
    } catch (e) {
      this.messageTarget.textContent = "Error de red al comprobar. Inténtalo de nuevo."
      this.messageTarget.className = "text-xs text-red-700"
    }
  }
}
