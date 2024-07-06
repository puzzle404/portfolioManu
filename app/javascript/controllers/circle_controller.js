import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
      anchor.addEventListener('click', function (e) {
        e.preventDefault();

        document.querySelector(this.getAttribute('href')).scrollIntoView({
          behavior: 'smooth'
        });
      });
    });

    const circle = document.querySelector('.circle');

    document.addEventListener('mousemove', (e) => {
      circle.style.left = `${e.clientX}px`;
      circle.style.top = `${e.clientY}px`;
    });
  }
}
