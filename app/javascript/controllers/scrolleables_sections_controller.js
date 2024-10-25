import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scrollable-sections"
export default class extends Controller {
  static values = {
    linkSelector: String,
    scrollableSelector: String
  }

  connect() {
    // Obtener los selectores personalizados de los enlaces y de la columna scrollable
    const linkSelector = this.linkSelectorValue || '.link-scrollable';
    const scrollableSelector = this.scrollableSelectorValue || '.right-column';

    document.querySelectorAll(linkSelector).forEach(link => {
      link.addEventListener('click', function (event) {
        event.preventDefault(); // Prevenir el comportamiento predeterminado del enlace

        const targetId = this.getAttribute('href').substring(1); // Obtener el ID de la sección sin el #
        const targetElement = document.getElementById(targetId); // Encontrar el elemento objetivo en la columna scrollable
        const scrollableColumn = document.querySelector(scrollableSelector); // Columna scrollable

        if (targetElement && scrollableColumn) {
          // Obtener la posición del elemento en relación con la columna scrollable
          const targetPosition = targetElement.offsetTop;

          // Desplazar suavemente la columna scrollable hacia la posición del objetivo
          scrollableColumn.scrollTo({
            top: targetPosition - 80,
            behavior: 'smooth'
          });
        }
      });
    });
  }
}
