// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "./channels"
import LocalTime from "local-time"
LocalTime.start()

// Initialize theme on page load
document.addEventListener('DOMContentLoaded', function() {
  const theme = localStorage.getItem('theme')
  const html = document.documentElement
  
  if (theme === 'dark') {
    html.classList.add('dark')
  } else if (!theme && window.matchMedia('(prefers-color-scheme: dark)').matches) {
    html.classList.add('dark')
  }
})
