import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="alert"
export default class extends Controller {
  static values = {
    dismissible: { type: Boolean, default: true },
    autoHide: { type: Boolean, default: false },
    autoHideDelay: { type: Number, default: 5000 }
  }

  connect() {
    this.setupAutoHide()
    
    // Animate in
    this.element.style.opacity = '0'
    this.element.style.transform = 'translateY(-10px)'
    
    requestAnimationFrame(() => {
      this.element.style.transition = 'opacity 0.3s ease-out, transform 0.3s ease-out'
      this.element.style.opacity = '1'
      this.element.style.transform = 'translateY(0)'
    })
  }

  disconnect() {
    this.clearAutoHideTimer()
  }

  // Dismiss the alert
  dismiss() {
    if (!this.dismissibleValue) return

    this.dispatch('dismissing', { detail: { alert: this.element } })
    
    this.element.style.transition = 'opacity 0.3s ease-out, transform 0.3s ease-out, max-height 0.3s ease-out'
    this.element.style.opacity = '0'
    this.element.style.transform = 'translateY(-10px)'
    this.element.style.maxHeight = '0'
    this.element.style.overflow = 'hidden'
    this.element.style.marginBottom = '0'
    this.element.style.paddingTop = '0'
    this.element.style.paddingBottom = '0'

    setTimeout(() => {
      this.element.remove()
      this.dispatch('dismissed', { detail: { alert: this.element } })
    }, 300)
  }

  // Setup auto-hide functionality
  setupAutoHide() {
    if (this.autoHideValue) {
      this.autoHideTimer = setTimeout(() => {
        this.dismiss()
      }, this.autoHideDelayValue)
    }
  }

  // Clear auto-hide timer
  clearAutoHideTimer() {
    if (this.autoHideTimer) {
      clearTimeout(this.autoHideTimer)
      this.autoHideTimer = null
    }
  }

  // Pause auto-hide on hover
  pauseAutoHide() {
    this.clearAutoHideTimer()
  }

  // Resume auto-hide when hover ends
  resumeAutoHide() {
    if (this.autoHideValue) {
      this.setupAutoHide()
    }
  }

  // Static methods for creating alerts programmatically
  static show(message, type = 'info', options = {}) {
    const alert = document.createElement('div')
    alert.setAttribute('data-controller', 'alert')
    alert.setAttribute('data-alert-dismissible-value', options.dismissible !== false)
    alert.setAttribute('data-alert-auto-hide-value', options.autoHide || false)
    alert.setAttribute('data-alert-auto-hide-delay-value', options.autoHideDelay || 5000)
    
    const typeClasses = {
      info: 'bg-primary-50 text-primary-700 border-primary-200',
      success: 'bg-success-50 text-success-700 border-success-200',
      warning: 'bg-warning-50 text-warning-700 border-warning-200',
      error: 'bg-danger-50 text-danger-700 border-danger-200',
      danger: 'bg-danger-50 text-danger-700 border-danger-200'
    }
    
    const iconPaths = {
      info: 'M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
      success: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z',
      warning: 'M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16c-.77.833.192 2.5 1.732 2.5z',
      error: 'M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z',
      danger: 'M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z'
    }

    alert.className = `relative rounded-lg border p-4 transition-all duration-200 mb-4 ${typeClasses[type] || typeClasses.info}`
    alert.setAttribute('role', 'alert')
    
    alert.innerHTML = `
      <div class="flex">
        <div class="flex-shrink-0 w-5 h-5">
          <svg class="w-full h-full" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${iconPaths[type] || iconPaths.info}"></path>
          </svg>
        </div>
        
        <div class="ml-3 flex-1 min-w-0">
          ${options.title ? `<h3 class="font-medium">${options.title}</h3>` : ''}
          <div class="${options.title ? 'mt-2' : ''}">
            ${message}
          </div>
        </div>
        
        ${options.dismissible !== false ? `
        <div class="ml-auto pl-3">
          <button
            type="button"
            class="p-1 rounded-md hover:bg-black/10 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-current transition-colors"
            data-action="click->alert#dismiss"
            aria-label="Dismiss alert"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>
        ` : ''}
      </div>
    `

    // Add to container or body
    const container = options.container || document.getElementById('alerts-container') || document.body
    container.appendChild(alert)

    return alert
  }

  // Helper methods for different alert types
  static info(message, options = {}) {
    return this.show(message, 'info', options)
  }

  static success(message, options = {}) {
    return this.show(message, 'success', options)
  }

  static warning(message, options = {}) {
    return this.show(message, 'warning', options)
  }

  static error(message, options = {}) {
    return this.show(message, 'error', options)
  }

  static danger(message, options = {}) {
    return this.show(message, 'danger', options)
  }
}