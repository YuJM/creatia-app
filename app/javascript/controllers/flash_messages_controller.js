import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flash-messages"
export default class extends Controller {
  static targets = ["message"]

  connect() {
    // Auto-dismiss messages after 5 seconds
    this.messageTargets.forEach(message => {
      const autoDismiss = message.dataset.autoDismiss === "true"
      if (autoDismiss) {
        setTimeout(() => {
          this.dismissMessage(message)
        }, 5000)
      }
    })
  }

  dismiss(event) {
    const message = event.target.closest('[data-flash-messages-target="message"]')
    this.dismissMessage(message)
  }

  dismissMessage(message) {
    if (!message) return
    
    // Add fade out animation
    message.style.transition = "all 0.3s ease-in-out"
    message.style.opacity = "0"
    message.style.transform = "translateX(100%)"
    
    // Remove from DOM after animation
    setTimeout(() => {
      if (message.parentNode) {
        message.parentNode.removeChild(message)
      }
      
      // If no messages left, hide container
      if (this.messageTargets.length === 0) {
        this.element.style.display = "none"
      }
    }, 300)
  }

  // Called when a message target is added (useful for Turbo streams)
  messageTargetConnected(target) {
    const autoDismiss = target.dataset.autoDismiss === "true"
    if (autoDismiss) {
      setTimeout(() => {
        this.dismissMessage(target)
      }, 5000)
    }
  }
}