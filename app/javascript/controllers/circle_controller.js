import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.circle = document.querySelector('.circle');

    document.addEventListener('mousemove', (e) => {
      this.circle.style.left = `${e.clientX}px`;
      this.circle.style.top = `${e.clientY}px`;
    });
  }
}
