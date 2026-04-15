import { Controller } from "@hotwired/stimulus"

// Handles multi-file PDF / image upload on the review page.
// Sends each file to the server, which enqueues a background job.
// Live status updates arrive via Turbo Streams — no polling needed.
export default class extends Controller {
  static targets = ["dropzone", "fileInput"]
  static values  = { url: String }

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
    this.uploadFiles(event.dataTransfer.files)
  }

  openFilePicker() {
    this.fileInputTarget.click()
  }

  onFileChange(event) {
    this.uploadFiles(event.target.files)
    event.target.value = ""
  }

  async uploadFiles(files) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content

    for (const file of files) {
      this.addOptimisticRow(file.name)

      const formData = new FormData()
      formData.append("pdfs[]", file)
      formData.append("authenticity_token", csrfToken)

      const queue = document.getElementById("upload_queue")

      try {
        const response = await fetch(this.urlValue, {
          method: "POST",
          body: formData,
          headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" }
        })

        const optimistic = document.getElementById(`optimistic_${CSS.escape(file.name)}`)
        optimistic?.remove()

        if (!response.ok) {
          const data = await response.json().catch(() => ({}))
          this.showUploadError(queue, file.name, data.error || "No se pudo subir el archivo")
          continue
        }

        const data = await response.json()
        const row = data.uploads?.[0]
        if (row?.error) {
          this.showUploadError(queue, row.filename || file.name, row.error)
          continue
        }
        if (row?.html && queue) {
          queue.insertAdjacentHTML("beforeend", row.html)
        }
      } catch {
        document.getElementById(`optimistic_${CSS.escape(file.name)}`)?.remove()
        this.showUploadError(queue, file.name, "Error de red")
      }
    }
  }

  // Show an immediate spinner row while the server processes the upload
  addOptimisticRow(filename) {
    const queue = document.getElementById("upload_queue")
    if (!queue) return

    const row = document.createElement("div")
    row.id = `optimistic_${CSS.escape(filename)}`
    row.className = "flex items-center gap-3 px-4 py-2 text-sm bg-white rounded-lg border"
    row.innerHTML = `
      <svg class="w-4 h-4 text-brand-teal animate-spin" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
      </svg>
      <span class="flex-1 text-gray-700 truncate">${filename}</span>
      <span class="text-xs text-gray-400">Subiendo…</span>
    `
    queue.appendChild(row)
  }

  markRowFailed(filename) {
    const row = document.getElementById(`optimistic_${CSS.escape(filename)}`)
    if (row) row.querySelector("span:last-child").textContent = "Error al subir"
  }

  showUploadError(queue, filename, message) {
    if (!queue) return
    const row = document.createElement("div")
    row.className = "flex items-center gap-3 px-4 py-2 text-sm bg-white rounded-lg border border-red-200"
    row.innerHTML = `
      <span class="flex-1 text-gray-700 truncate">${filename}</span>
      <span class="text-xs text-red-600">${message}</span>
    `
    queue.appendChild(row)
  }
}
