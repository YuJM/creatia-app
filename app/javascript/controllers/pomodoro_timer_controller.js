// Pomodoro Timer Controller
// Stimulus controller for pomodoro timer countdown display
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { seconds: Number }
  
  connect() {
    this.startTimer()
  }
  
  disconnect() {
    this.stopTimer()
  }
  
  startTimer() {
    if (this.secondsValue <= 0) return
    
    this.timer = setInterval(() => {
      this.secondsValue--
      this.updateDisplay()
      
      if (this.secondsValue <= 0) {
        this.timerComplete()
      }
    }, 1000)
  }
  
  stopTimer() {
    if (this.timer) {
      clearInterval(this.timer)
    }
  }
  
  updateDisplay() {
    const minutes = Math.floor(this.secondsValue / 60)
    const seconds = this.secondsValue % 60
    
    this.element.textContent = `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
    
    // Update styling based on remaining time
    if (this.secondsValue <= 60) {
      this.element.classList.add("text-red-600", "animate-pulse")
      this.element.classList.remove("text-orange-600", "text-gray-700")
    } else if (this.secondsValue <= 300) {
      this.element.classList.add("text-orange-600")
      this.element.classList.remove("text-red-600", "animate-pulse", "text-gray-700")
    }
  }
  
  timerComplete() {
    this.stopTimer()
    this.element.textContent = "00:00"
    this.element.classList.add("text-red-600", "animate-pulse")
    
    // Dispatch custom event for timer completion
    const event = new CustomEvent("pomodoro:complete", {
      detail: { element: this.element },
      bubbles: true
    })
    this.element.dispatchEvent(event)
    
    // Play sound if available
    this.playCompletionSound()
  }
  
  playCompletionSound() {
    const audio = new Audio('/sounds/pomodoro_complete.mp3')
    audio.play().catch(e => console.log('Could not play sound:', e))
  }
  
  // Public methods for external control
  pause() {
    this.stopTimer()
  }
  
  resume() {
    this.startTimer()
  }
  
  reset(seconds = 1500) { // Default 25 minutes
    this.stopTimer()
    this.secondsValue = seconds
    this.updateDisplay()
    this.startTimer()
  }
}