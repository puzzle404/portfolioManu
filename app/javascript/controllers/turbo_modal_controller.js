import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal"];

  connect() {
    // Escuchar clics en el documento
    document.querySelector('.modal-backdrop').classList.remove('d-none')
  }

  disconnect() {
    // Eliminar el listener cuando el controlador se desconecta
  }

  hideModal() {
    this.element.parentElement.removeAttribute("src"); // Eliminar la referencia al modal
    document.querySelector('.modal-backdrop').classList.add('d-none')

    this.element.remove();
  }

  closeWithKeyboard(e) {
    if (e.code == "Escape") {
      this.hideModal();
    }
  }

  closeBackground(e) {
    // Detectar el verdadero contenido del modal, no el div envolvente
    const modalContent = document.querySelector('.modal-content');

    // Si el clic fue fuera del verdadero contenido del modal, cerramos el modal
    const clickedOutside = !modalContent.contains(e.target);
    console.log('Clic fuera del modal:', clickedOutside);

    if (clickedOutside) {
      this.hideModal();
    }
  }
}
