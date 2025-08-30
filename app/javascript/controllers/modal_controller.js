import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
export default class extends Controller {
  static values = { 
    closable: { type: Boolean, default: true },
    backdropClose: { type: Boolean, default: true }
  }

  connect() {
    this.boundHandleEscape = this.handleEscape.bind(this)
    this.boundHandleBackdropClick = this.handleBackdropClick.bind(this)
  }

  disconnect() {
    this.close()
  }

  // Action methods
  open() {
    this.element.classList.remove('hidden')
    document.body.style.overflow = 'hidden'
    
    // Add event listeners
    document.addEventListener('keydown', this.boundHandleEscape)
    this.element.addEventListener('click', this.boundHandleBackdropClick)
    
    // Focus management
    this.trapFocus()
    
    // Dispatch custom event
    this.dispatch('opened', { detail: { modal: this.element } })
  }

  close() {
    if (!this.closableValue) return
    
    this.element.classList.add('hidden')
    document.body.style.overflow = ''
    
    // Remove event listeners
    document.removeEventListener('keydown', this.boundHandleEscape)
    this.element.removeEventListener('click', this.boundHandleBackdropClick)
    
    // Restore focus
    this.restoreFocus()
    
    // Dispatch custom event
    this.dispatch('closed', { detail: { modal: this.element } })
  }

  toggle() {
    if (this.element.classList.contains('hidden')) {
      this.open()
    } else {
      this.close()
    }
  }

  // Event handlers
  handleEscape(event) {
    if (event.key === 'Escape' && this.closableValue) {
      event.preventDefault()
      this.close()
    }
  }

  handleBackdropClick(event) {
    if (event.target === this.element && this.backdropCloseValue && this.closableValue) {
      this.close()
    }
  }

  // Focus management
  trapFocus() {
    this.previousActiveElement = document.activeElement
    
    const focusableElements = this.element.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    )
    
    if (focusableElements.length > 0) {
      focusableElements[0].focus()
    }

    this.element.addEventListener('keydown', (event) => {
      if (event.key === 'Tab') {
        this.handleTabKey(event, focusableElements)
      }
    })
  }

  handleTabKey(event, focusableElements) {
    const firstElement = focusableElements[0]
    const lastElement = focusableElements[focusableElements.length - 1]

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

  restoreFocus() {
    if (this.previousActiveElement && typeof this.previousActiveElement.focus === 'function') {
      this.previousActiveElement.focus()
    }
  }

  // Helper methods for external use
  isOpen() {
    return !this.element.classList.contains('hidden')
  }

  // Static methods for programmatic control
  static open(modalId) {
    const modal = document.getElementById(modalId)
    if (modal) {
      const controller = this.application.getControllerForElementAndIdentifier(modal, 'modal')
      if (controller) controller.open()
    }
  }

  static close(modalId) {
    const modal = document.getElementById(modalId)
    if (modal) {
      const controller = this.application.getControllerForElementAndIdentifier(modal, 'modal')
      if (controller) controller.close()
    }
  }
}