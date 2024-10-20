import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Hello World!")
  }

  invalidInputQuestionModal(e) {
    const invalidMessage = document.querySelector('.invalid-feedback')
    console.log('invalidMessage', invalidMessage)
    console.log('thi elemento', this.element)
    if (invalidMessage) {
      invalidMessage.classList.add('invalid-feedback-question')
    }
  }
}
