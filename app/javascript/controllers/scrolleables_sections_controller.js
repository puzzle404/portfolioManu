import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scrolleables-sections"
export default class extends Controller {
  static values = {
    linkSelector: String
  }

  connect() {
    const linkSelector = this.linkSelectorValue || '.link-scrollable';
    this.links = document.querySelectorAll(linkSelector);

    // Handle click events
    this.links.forEach(link => {
      link.addEventListener('click', (event) => {
        event.preventDefault();

        // Update active state
        this.setActiveLink(link);

        const targetId = link.getAttribute('href').substring(1);
        const targetElement = document.getElementById(targetId);

        if (targetElement) {
          const targetPosition = targetElement.getBoundingClientRect().top + window.pageYOffset;
          window.scrollTo({
            top: targetPosition - 80,
            behavior: 'smooth'
          });
        }
      });
    });

    // Handle scroll to update active link based on section in view
    window.addEventListener('scroll', () => this.updateActiveOnScroll());

    // Initial check
    this.updateActiveOnScroll();
  }

  setActiveLink(activeLink) {
    this.links.forEach(link => link.classList.remove('active'));
    activeLink.classList.add('active');
  }

  updateActiveOnScroll() {
    const scrollPosition = window.scrollY + 150;

    let currentSection = null;

    this.links.forEach(link => {
      const targetId = link.getAttribute('href').substring(1);
      const section = document.getElementById(targetId);

      if (section) {
        const sectionTop = section.offsetTop;
        const sectionHeight = section.offsetHeight;

        if (scrollPosition >= sectionTop && scrollPosition < sectionTop + sectionHeight) {
          currentSection = link;
        }
      }
    });

    if (currentSection) {
      this.setActiveLink(currentSection);
    }
  }
}
