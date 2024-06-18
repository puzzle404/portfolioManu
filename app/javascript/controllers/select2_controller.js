import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    var settings = {
      plugins: {
        remove_button: {
          title: 'Remove this item',
        }
      }
    };
    new TomSelect('#tom-select-it', settings);
  }
}
