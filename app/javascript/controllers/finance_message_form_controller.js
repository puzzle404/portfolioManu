import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "fileInput", "submitBtn", "preview"]

  submit(event) {
    const hasText = this.inputTarget.value.trim() !== ""
    const hasFiles = this.fileInputTarget.files.length > 0

    if (!hasText && !hasFiles) {
      event.preventDefault()
      return
    }

    // Clear inputs after a short delay to allow form submission
    setTimeout(() => {
      this.inputTarget.value = ""
      this.fileInputTarget.value = ""
      this.previewTarget.classList.add("d-none")
      this.previewTarget.innerHTML = ""
    }, 100)
  }

  fileSelected() {
    const files = this.fileInputTarget.files
    if (files.length > 0) {
      this.previewTarget.classList.remove("d-none")
      this.previewTarget.innerHTML = ""
      Array.from(files).forEach(file => {
        if (file.type.startsWith("image/")) {
          const img = document.createElement("img")
          img.src = URL.createObjectURL(file)
          img.className = "finance-preview-thumb"
          this.previewTarget.appendChild(img)
        }
      })
    }
  }
}
