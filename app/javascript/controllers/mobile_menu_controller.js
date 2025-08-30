import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="mobile-menu"
export default class extends Controller {
  static targets = ["overlay"]

  toggle() {
    const overlay = this.overlayTarget
    if (overlay.classList.contains("hidden")) {
      this.show()
    } else {
      this.close()
    }
  }

  show() {
    const overlay = this.overlayTarget
    overlay.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    
    // Add focus trap
    this.trapFocus()
    
    // Add ESC key listener
    document.addEventListener("keydown", this.handleKeydown)
  }

  close() {
    const overlay = this.overlayTarget
    overlay.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    
    // Remove ESC key listener
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown = (event) => {
    if (event.key === "Escape") {
      this.close()
    }
  }

  trapFocus() {
    const overlay = this.overlayTarget
    const focusableElements = overlay.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    )
    
    if (focusableElements.length === 0) return
    
    const firstElement = focusableElements[0]
    const lastElement = focusableElements[focusableElements.length - 1]
    
    firstElement.focus()
    
    overlay.addEventListener("keydown", (event) => {
      if (event.key === "Tab") {
        if (event.shiftKey) {
          if (document.activeElement === firstElement) {
            event.preventDefault()
            lastElement.focus()
          }
        } else {
          if (document.activeElement === lastElement) {
            event.preventDefault()
            firstElement.focus()
          }
        }
      }
    })
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
    document.body.classList.remove("overflow-hidden")
  }
}