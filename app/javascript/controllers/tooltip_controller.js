import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tooltip"
export default class extends Controller {
  static targets = ["content"]
  static values = {
    text: String,
    placement: { type: String, default: "top" }, // top, bottom, left, right
    offset: { type: Number, default: 8 },
    delay: { type: Number, default: 200 },
    hideDelay: { type: Number, default: 100 },
    arrow: { type: Boolean, default: true },
    trigger: { type: String, default: "hover focus" } // hover, focus, click, manual
  }

  connect() {
    this.createTooltip()
    this.setupTriggers()
  }

  disconnect() {
    this.hideTooltip()
    this.removeTooltip()
    this.cleanupTriggers()
  }

  // Create tooltip element
  createTooltip() {
    if (this.tooltip) return

    this.tooltip = document.createElement('div')
    this.tooltip.className = this.tooltipClasses
    this.tooltip.setAttribute('role', 'tooltip')
    this.tooltip.style.position = 'fixed'
    this.tooltip.style.zIndex = '9999'
    this.tooltip.style.pointerEvents = 'none'
    this.tooltip.style.opacity = '0'
    this.tooltip.style.transform = 'scale(0.8)'
    this.tooltip.style.transition = 'opacity 0.15s ease-out, transform 0.15s ease-out'

    // Add content
    const contentDiv = document.createElement('div')
    contentDiv.className = 'px-3 py-2 text-sm'
    contentDiv.textContent = this.textValue || this.element.getAttribute('title') || ''
    
    this.tooltip.appendChild(contentDiv)

    // Add arrow if enabled
    if (this.arrowValue) {
      this.arrow = document.createElement('div')
      this.arrow.className = this.arrowClasses
      this.tooltip.appendChild(this.arrow)
    }

    document.body.appendChild(this.tooltip)

    // Remove title attribute to prevent native tooltip
    if (this.element.hasAttribute('title')) {
      this.originalTitle = this.element.getAttribute('title')
      this.element.removeAttribute('title')
    }
  }

  // Remove tooltip element
  removeTooltip() {
    if (this.tooltip) {
      this.tooltip.remove()
      this.tooltip = null
    }
    
    // Restore original title
    if (this.originalTitle) {
      this.element.setAttribute('title', this.originalTitle)
    }
  }

  // Setup event listeners based on trigger type
  setupTriggers() {
    const triggers = this.triggerValue.split(' ')
    
    triggers.forEach(trigger => {
      switch (trigger) {
        case 'hover':
          this.element.addEventListener('mouseenter', this.handleMouseEnter.bind(this))
          this.element.addEventListener('mouseleave', this.handleMouseLeave.bind(this))
          break
        case 'focus':
          this.element.addEventListener('focusin', this.handleFocusIn.bind(this))
          this.element.addEventListener('focusout', this.handleFocusOut.bind(this))
          break
        case 'click':
          this.element.addEventListener('click', this.handleClick.bind(this))
          break
      }
    })
  }

  // Cleanup event listeners
  cleanupTriggers() {
    this.element.removeEventListener('mouseenter', this.handleMouseEnter.bind(this))
    this.element.removeEventListener('mouseleave', this.handleMouseLeave.bind(this))
    this.element.removeEventListener('focusin', this.handleFocusIn.bind(this))
    this.element.removeEventListener('focusout', this.handleFocusOut.bind(this))
    this.element.removeEventListener('click', this.handleClick.bind(this))
  }

  // Event handlers
  handleMouseEnter() {
    this.cancelHide()
    this.showDelayed()
  }

  handleMouseLeave() {
    this.cancelShow()
    this.hideDelayed()
  }

  handleFocusIn() {
    this.cancelHide()
    this.showDelayed()
  }

  handleFocusOut() {
    this.cancelShow()
    this.hideDelayed()
  }

  handleClick() {
    if (this.isVisible()) {
      this.hideTooltip()
    } else {
      this.showTooltip()
    }
  }

  // Show/Hide with delays
  showDelayed() {
    this.cancelShow()
    this.showTimeout = setTimeout(() => {
      this.showTooltip()
    }, this.delayValue)
  }

  hideDelayed() {
    this.cancelHide()
    this.hideTimeout = setTimeout(() => {
      this.hideTooltip()
    }, this.hideDelayValue)
  }

  cancelShow() {
    if (this.showTimeout) {
      clearTimeout(this.showTimeout)
      this.showTimeout = null
    }
  }

  cancelHide() {
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout)
      this.hideTimeout = null
    }
  }

  // Show/Hide tooltip
  showTooltip() {
    if (!this.tooltip || this.isVisible()) return

    this.updatePosition()
    this.tooltip.style.opacity = '1'
    this.tooltip.style.transform = 'scale(1)'
    
    this.dispatch('shown', { detail: { tooltip: this.tooltip } })
  }

  hideTooltip() {
    if (!this.tooltip || !this.isVisible()) return

    this.tooltip.style.opacity = '0'
    this.tooltip.style.transform = 'scale(0.8)'
    
    this.dispatch('hidden', { detail: { tooltip: this.tooltip } })
  }

  // Position tooltip
  updatePosition() {
    if (!this.tooltip) return

    const elementRect = this.element.getBoundingClientRect()
    const tooltipRect = this.tooltip.getBoundingClientRect()
    const viewportWidth = window.innerWidth
    const viewportHeight = window.innerHeight

    let top, left

    // Calculate base position
    switch (this.placementValue) {
      case 'top':
        top = elementRect.top - tooltipRect.height - this.offsetValue
        left = elementRect.left + (elementRect.width / 2) - (tooltipRect.width / 2)
        break
      case 'bottom':
        top = elementRect.bottom + this.offsetValue
        left = elementRect.left + (elementRect.width / 2) - (tooltipRect.width / 2)
        break
      case 'left':
        top = elementRect.top + (elementRect.height / 2) - (tooltipRect.height / 2)
        left = elementRect.left - tooltipRect.width - this.offsetValue
        break
      case 'right':
        top = elementRect.top + (elementRect.height / 2) - (tooltipRect.height / 2)
        left = elementRect.right + this.offsetValue
        break
    }

    // Adjust for viewport boundaries
    if (left < 8) left = 8
    if (left + tooltipRect.width > viewportWidth - 8) {
      left = viewportWidth - tooltipRect.width - 8
    }
    if (top < 8) top = 8
    if (top + tooltipRect.height > viewportHeight - 8) {
      top = viewportHeight - tooltipRect.height - 8
    }

    this.tooltip.style.top = `${top}px`
    this.tooltip.style.left = `${left}px`

    // Position arrow
    if (this.arrow) {
      this.positionArrow(elementRect, { top, left })
    }
  }

  // Position arrow relative to element
  positionArrow(elementRect, tooltipPos) {
    if (!this.arrow) return

    const arrowSize = 6
    
    switch (this.placementValue) {
      case 'top':
        this.arrow.style.top = '100%'
        this.arrow.style.left = `${elementRect.left + (elementRect.width / 2) - tooltipPos.left - arrowSize}px`
        break
      case 'bottom':
        this.arrow.style.bottom = '100%'
        this.arrow.style.left = `${elementRect.left + (elementRect.width / 2) - tooltipPos.left - arrowSize}px`
        break
      case 'left':
        this.arrow.style.left = '100%'
        this.arrow.style.top = `${elementRect.top + (elementRect.height / 2) - tooltipPos.top - arrowSize}px`
        break
      case 'right':
        this.arrow.style.right = '100%'
        this.arrow.style.top = `${elementRect.top + (elementRect.height / 2) - tooltipPos.top - arrowSize}px`
        break
    }
  }

  // Helper methods
  isVisible() {
    return this.tooltip && this.tooltip.style.opacity === '1'
  }

  // CSS classes
  get tooltipClasses() {
    return [
      'bg-neutral-900 text-neutral-50 rounded-md shadow-lg',
      'dark:bg-neutral-100 dark:text-neutral-900',
      'max-w-xs break-words'
    ].join(' ')
  }

  get arrowClasses() {
    const base = 'absolute w-0 h-0 border-solid'
    
    switch (this.placementValue) {
      case 'top':
        return `${base} border-t-neutral-900 dark:border-t-neutral-100 border-l-transparent border-r-transparent border-b-0 border-t-8 border-l-6 border-r-6`
      case 'bottom':
        return `${base} border-b-neutral-900 dark:border-b-neutral-100 border-l-transparent border-r-transparent border-t-0 border-b-8 border-l-6 border-r-6`
      case 'left':
        return `${base} border-l-neutral-900 dark:border-l-neutral-100 border-t-transparent border-b-transparent border-r-0 border-l-8 border-t-6 border-b-6`
      case 'right':
        return `${base} border-r-neutral-900 dark:border-r-neutral-100 border-t-transparent border-b-transparent border-l-0 border-r-8 border-t-6 border-b-6`
      default:
        return base
    }
  }

  // API methods
  show() {
    this.showTooltip()
  }

  hide() {
    this.hideTooltip()
  }

  updateText(text) {
    this.textValue = text
    if (this.tooltip) {
      const contentDiv = this.tooltip.querySelector('div')
      if (contentDiv) contentDiv.textContent = text
    }
  }
}