import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="theme"
export default class extends Controller {
  static targets = ["toggle", "icon", "text"]

  connect() {
    this.updateIcon()
    this.updateText()
  }

  toggle() {
    const html = document.documentElement
    const currentTheme = this.getCurrentTheme()
    
    let newTheme
    switch (currentTheme) {
      case 'light':
        newTheme = 'dark'
        break
      case 'dark':
        newTheme = 'system'
        break
      default:
        newTheme = 'light'
    }
    
    this.setTheme(newTheme)
  }

  setTheme(theme) {
    const html = document.documentElement
    
    // Remove existing theme classes
    html.classList.remove('light', 'dark')
    
    if (theme === 'system') {
      localStorage.removeItem('theme')
      // Apply system preference
      if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
        html.classList.add('dark')
      }
    } else {
      localStorage.setItem('theme', theme)
      if (theme === 'dark') {
        html.classList.add('dark')
      }
    }
    
    this.updateIcon()
    this.updateText()
  }

  getCurrentTheme() {
    const stored = localStorage.getItem('theme')
    if (stored) return stored
    return 'system'
  }

  updateIcon() {
    if (!this.hasIconTarget) return
    
    const theme = this.getCurrentTheme()
    const iconTarget = this.iconTarget
    
    let iconHTML
    switch (theme) {
      case 'light':
        iconHTML = `
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z">
            </path>
          </svg>`
        break
      case 'dark':
        iconHTML = `
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z">
            </path>
          </svg>`
        break
      default:
        iconHTML = `
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z">
            </path>
          </svg>`
    }
    
    iconTarget.innerHTML = iconHTML
  }

  updateText() {
    if (!this.hasTextTarget) return
    
    const theme = this.getCurrentTheme()
    const textTarget = this.textTarget
    
    switch (theme) {
      case 'light':
        textTarget.textContent = 'Light'
        break
      case 'dark':
        textTarget.textContent = 'Dark'
        break
      default:
        textTarget.textContent = 'System'
    }
  }
}