import { Controller } from "@hotwired/stimulus"

// Copies data-clipboard-copy-text-value to the clipboard; brief "Copiado" feedback on the button.
export default class extends Controller {
  static values = {
    text: String,
    doneLabel: { type: String, default: "Copiado" }
  }

  connect() {
    this.defaultLabel = this.element.textContent.trim()
  }

  async copy(event) {
    event.preventDefault()
    const text = this.textValue
    if (!text) return

    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(text)
      } else {
        const ta = document.createElement("textarea")
        ta.value = text
        ta.setAttribute("readonly", "")
        ta.style.position = "absolute"
        ta.style.left = "-9999px"
        document.body.appendChild(ta)
        ta.select()
        document.execCommand("copy")
        document.body.removeChild(ta)
      }
      this.showDone()
    } catch {
      this.element.textContent = "Error"
      this.scheduleReset()
    }
  }

  showDone() {
    this.element.textContent = this.doneLabelValue
    this.element.classList.add("border-green-300", "bg-green-50", "text-green-800")
    this.scheduleReset()
  }

  scheduleReset() {
    clearTimeout(this.resetTimer)
    this.resetTimer = window.setTimeout(() => this.resetLabel(), 1600)
  }

  resetLabel() {
    this.element.textContent = this.defaultLabel
    this.element.classList.remove("border-green-300", "bg-green-50", "text-green-800")
  }
}
