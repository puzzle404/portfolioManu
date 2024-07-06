import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    $('input').on('change', function () {
      $('body').toggleClass('blue');
    });
  }
}
