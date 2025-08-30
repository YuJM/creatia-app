import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.clickOutsideHandler = this.clickOutside.bind(this)
    this.keyHandler = this.handleKeydown.bind(this)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    this.element.setAttribute("aria-expanded", "true")
    
    // Add event listeners
    document.addEventListener("click", this.clickOutsideHandler)
    document.addEventListener("keydown", this.keyHandler)
    
    // Focus first menu item
    const firstMenuItem = this.menuTarget.querySelector('a, button')
    if (firstMenuItem) {
      firstMenuItem.focus()
    }
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.element.setAttribute("aria-expanded", "false")
    
    // Remove event listeners
    document.removeEventListener("click", this.clickOutsideHandler)
    document.removeEventListener("keydown", this.keyHandler)
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
      return
    }
    
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      this.navigateMenu(event.key === "ArrowDown")
    }
  }

  navigateMenu(down = true) {
    const menuItems = Array.from(this.menuTarget.querySelectorAll('a, button'))
    const currentIndex = menuItems.indexOf(document.activeElement)
    
    let nextIndex
    if (down) {
      nextIndex = currentIndex < menuItems.length - 1 ? currentIndex + 1 : 0
    } else {
      nextIndex = currentIndex > 0 ? currentIndex - 1 : menuItems.length - 1
    }
    
    menuItems[nextIndex].focus()
  }

  isOpen() {
    return !this.menuTarget.classList.contains("hidden")
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutsideHandler)
    document.removeEventListener("keydown", this.keyHandler)
  }
}