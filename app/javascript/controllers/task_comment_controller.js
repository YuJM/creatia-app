import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submitButton"]

  connect() {
    this.validateInput()
  }

  validateInput() {
    if (this.hasInputTarget && this.hasSubmitButtonTarget) {
      const hasContent = this.inputTarget.value.trim().length > 0
      this.submitButtonTarget.disabled = !hasContent
    }
  }

  handleSubmit(event) {
    event.preventDefault()
    
    if (this.inputTarget.value.trim().length === 0) {
      return
    }

    // Submit via Turbo
    const form = event.target
    form.requestSubmit()
    
    // Clear input after submission
    this.inputTarget.value = ""
    this.validateInput()
  }
}