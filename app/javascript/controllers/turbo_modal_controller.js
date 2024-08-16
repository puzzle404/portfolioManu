import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal"];

  connect() {
    // console.log("probando turbo-modal controller");
  }

  hideModal() {
    this.element.parentElement.removeAttribute("src"); // it might be nice to also remove the modal SRC
    this.element.remove();
  }

  submitEnd(e) {
    if (e.detail.success) {
      const notClose = document.querySelector(".notClose");
      if (notClose) {
        e.preventDefault();
      } else {
        this.hideModal();
      }
    }
  }
  closeWithKeyboard(e) {
    if (e.code == "Escape") {
      this.hideModal();
    }
  }

  closeBackground(e) {
    // Verificar si el clic se originó fuera del sidebar
    if (e.target.classList.contains("modal-backdrop")) {
      this.hideModal();
    } else {
    }
  }
}
