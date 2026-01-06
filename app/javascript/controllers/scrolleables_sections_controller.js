import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scrolleables-sections"
// Ahora usa scroll del documento en lugar de scroll interno
export default class extends Controller {
  static values = {
    linkSelector: String
  }

  connect() {
    const linkSelector = this.linkSelectorValue || '.link-scrollable';

    document.querySelectorAll(linkSelector).forEach(link => {
      link.addEventListener('click', function (event) {
        event.preventDefault();

        const targetId = this.getAttribute('href').substring(1);
        const targetElement = document.getElementById(targetId);

        if (targetElement) {
          // Scroll suave del documento completo
          const targetPosition = targetElement.getBoundingClientRect().top + window.pageYOffset;

          window.scrollTo({
            top: targetPosition - 80,
            behavior: 'smooth'
          });
        }
      });
    });
  }
}
