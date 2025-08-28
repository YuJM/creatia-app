// Local Time Controller
// Stimulus controller for displaying times in user's local timezone
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    type: String,
    format: String,
    updateInterval: { type: Number, default: 60000 } // Update every minute
  }
  
  connect() {
    this.updateTime()
    
    if (this.typeValue === "relative") {
      // Set up periodic updates for relative times
      this.startUpdating()
    }
  }
  
  disconnect() {
    this.stopUpdating()
  }
  
  updateTime() {
    const datetime = this.element.getAttribute('datetime')
    if (!datetime) return
    
    const date = new Date(datetime)
    
    switch(this.typeValue) {
      case 'relative':
        this.element.textContent = this.relativeTime(date)
        break
      case 'local':
        this.element.textContent = this.localTime(date)
        break
      default:
        this.element.textContent = this.formatTime(date)
    }
  }
  
  relativeTime(date) {
    const now = new Date()
    const diffInSeconds = Math.floor((now - date) / 1000)
    const absSeconds = Math.abs(diffInSeconds)
    
    let timeString
    
    if (absSeconds < 60) {
      timeString = "방금"
    } else if (absSeconds < 3600) {
      const minutes = Math.floor(absSeconds / 60)
      timeString = `${minutes}분`
    } else if (absSeconds < 86400) {
      const hours = Math.floor(absSeconds / 3600)
      timeString = `${hours}시간`
    } else if (absSeconds < 2592000) {
      const days = Math.floor(absSeconds / 86400)
      timeString = `${days}일`
    } else if (absSeconds < 31536000) {
      const months = Math.floor(absSeconds / 2592000)
      timeString = `${months}개월`
    } else {
      const years = Math.floor(absSeconds / 31536000)
      timeString = `${years}년`
    }
    
    if (diffInSeconds > 0) {
      return `${timeString} 전`
    } else {
      return `${timeString} 후`
    }
  }
  
  localTime(date) {
    const options = {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false
    }
    
    return date.toLocaleString('ko-KR', options)
  }
  
  formatTime(date) {
    const format = this.formatValue || 'YYYY-MM-DD HH:mm'
    
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')
    const seconds = String(date.getSeconds()).padStart(2, '0')
    
    return format
      .replace('YYYY', year)
      .replace('MM', month)
      .replace('DD', day)
      .replace('HH', hours)
      .replace('mm', minutes)
      .replace('ss', seconds)
  }
  
  startUpdating() {
    this.updateTimer = setInterval(() => {
      this.updateTime()
    }, this.updateIntervalValue)
  }
  
  stopUpdating() {
    if (this.updateTimer) {
      clearInterval(this.updateTimer)
    }
  }
}