import { Controller } from "@hotwired/stimulus"

// Check icon (brand teal); inline color so Tailwind CDN does not need to scan this file.
const DONE_SVG =
  '<svg class="w-3.5 h-3.5 pointer-events-none" style="color:#2f9d90" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" aria-hidden="true"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" /></svg>'

// Copies data-clipboard-copy-text-value to the clipboard; brief visual feedback on the button.
export default class extends Controller {
  static values = {
    text: String
  }

  connect() {
    this.defaultHTML = this.element.innerHTML
    this.defaultClassName = this.element.className
    this.defaultTitle = this.element.getAttribute("title") || ""
    this.defaultAriaLabel = this.element.getAttribute("aria-label") || ""
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
      this.element.innerHTML = this.defaultHTML
      this.element.className = this.defaultClassName
      this.element.setAttribute("title", "No se pudo copiar")
      this.element.setAttribute("aria-label", "No se pudo copiar")
      clearTimeout(this.resetTimer)
      this.resetTimer = window.setTimeout(() => {
        this.element.setAttribute("title", this.defaultTitle)
        this.element.setAttribute("aria-label", this.defaultAriaLabel)
      }, 2000)
    }
  }

  showDone() {
    this.element.innerHTML = DONE_SVG
    this.element.className =
      "inline-flex items-center justify-center shrink-0 rounded-md border border-brand-teal bg-brand-teal-muted p-1 transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-teal focus-visible:ring-offset-1"
    this.scheduleReset()
  }

  scheduleReset() {
    clearTimeout(this.resetTimer)
    this.resetTimer = window.setTimeout(() => this.resetLabel(), 1600)
  }

  resetLabel() {
    this.element.innerHTML = this.defaultHTML
    this.element.className = this.defaultClassName
  }
}
