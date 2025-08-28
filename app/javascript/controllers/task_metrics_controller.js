import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "completionPercent", 
    "progressBar", 
    "estimatedHours", 
    "actualHours", 
    "efficiencyStatus", 
    "remainingInfo",
    "loading"
  ]
  static values = { 
    taskId: Number,
    refreshInterval: { type: Number, default: 30000 } // 30초
  }
  
  connect() {
    console.log("TaskMetrics controller connected for task", this.taskIdValue)
    this.refreshMetrics()
    this.startAutoRefresh()
  }
  
  disconnect() {
    this.stopAutoRefresh()
  }
  
  refresh() {
    console.log("Manual refresh requested")
    this.refreshMetrics()
  }
  
  async refreshMetrics() {
    if (!this.taskIdValue) {
      console.error("No task ID provided")
      return
    }
    
    try {
      this.showLoading(true)
      
      // Turbo Stream을 우선 시도, 실패시 JSON으로 폴백
      const turboResponse = await fetch(`/tasks/${this.taskIdValue}/metrics`, {
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (turboResponse.ok && turboResponse.headers.get('content-type')?.includes('turbo-stream')) {
        // Turbo Stream 응답 처리 - Turbo가 자동으로 DOM을 업데이트
        const streamContent = await turboResponse.text()
        Turbo.renderStreamMessage(streamContent)
        this.showToast('메트릭이 업데이트되었습니다', 'success')
        return
      }
      
      // JSON 폴백
      const jsonResponse = await fetch(`/tasks/${this.taskIdValue}/metrics`, {
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (!jsonResponse.ok) {
        throw new Error(`HTTP error! status: ${jsonResponse.status}`)
      }
      
      const data = await jsonResponse.json()
      
      if (data.metrics) {
        this.updateMetrics(data.metrics, data.user_friendly)
        this.showToast('메트릭이 업데이트되었습니다', 'success')
      } else {
        console.warn("No metrics data received")
      }
    } catch (error) {
      console.error("Failed to refresh metrics:", error)
      this.showToast('메트릭 업데이트에 실패했습니다', 'error')
    } finally {
      this.showLoading(false)
    }
  }
  
  updateMetrics(metrics, userFriendly) {
    console.log("Updating metrics:", metrics, userFriendly)
    
    // 완료율 업데이트
    if (this.hasCompletionPercentTarget) {
      this.completionPercentTarget.textContent = `${metrics.completion_percentage.toFixed(1)}%`
    }
    
    // 프로그레스 바 업데이트
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${metrics.completion_percentage}%`
      
      // 프로그레스 바 색상 변경
      this.progressBarTarget.classList.remove('bg-yellow-600', 'bg-blue-600', 'bg-green-600')
      if (metrics.completion_percentage >= 90) {
        this.progressBarTarget.classList.add('bg-green-600')
      } else if (metrics.completion_percentage >= 50) {
        this.progressBarTarget.classList.add('bg-blue-600')
      } else {
        this.progressBarTarget.classList.add('bg-yellow-600')
      }
    }
    
    // 시간 정보 업데이트
    if (this.hasEstimatedHoursTarget) {
      this.estimatedHoursTarget.textContent = metrics.estimated_hours || "미설정"
    }
    
    if (this.hasActualHoursTarget) {
      this.actualHoursTarget.textContent = metrics.actual_hours || "0"
    }
    
    // 효율성 상태 업데이트
    if (this.hasEfficiencyStatusTarget && userFriendly.efficiency_status) {
      const statusSpan = this.efficiencyStatusTarget.querySelector('span')
      if (statusSpan) {
        statusSpan.textContent = userFriendly.efficiency_status
      }
    }
    
    // 남은 작업 정보 업데이트
    if (this.hasRemainingInfoTarget) {
      const remaining = metrics.remaining_percentage
      if (remaining > 0) {
        this.remainingInfoTarget.innerHTML = `<strong>${remaining.toFixed(1)}%</strong> 작업이 남아있습니다`
      } else {
        this.remainingInfoTarget.innerHTML = `<strong>완료!</strong> 모든 작업이 완료되었습니다`
      }
    }
  }
  
  showLoading(show) {
    if (this.hasLoadingTarget) {
      if (show) {
        this.loadingTarget.classList.remove('hidden')
      } else {
        this.loadingTarget.classList.add('hidden')
      }
    }
  }
  
  startAutoRefresh() {
    // 자동 새로고침은 선택사항
    if (this.refreshIntervalValue > 0) {
      this.refreshTimer = setInterval(() => {
        this.refreshMetricsWithTurbo()
      }, this.refreshIntervalValue)
      console.log(`Auto-refresh started with interval: ${this.refreshIntervalValue}ms`)
    }
  }
  
  // Turbo Stream을 활용한 자동 새로고침
  async refreshMetricsWithTurbo() {
    if (!this.taskIdValue) {
      console.error("No task ID provided for auto-refresh")
      return
    }
    
    try {
      const response = await fetch(`/tasks/${this.taskIdValue}/metrics`, {
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok && response.headers.get('content-type')?.includes('turbo-stream')) {
        const streamContent = await response.text()
        Turbo.renderStreamMessage(streamContent)
        
        // 자동 새로고침의 경우 조용히 업데이트 (토스트 없음)
        console.log("Auto-refresh completed successfully")
      } else {
        console.warn("Auto-refresh failed, falling back to manual refresh")
        this.refreshMetrics()
      }
    } catch (error) {
      console.error("Auto-refresh failed:", error)
      // 자동 새로고침 실패시 조용히 무시 (사용자 경험을 해치지 않음)
    }
  }
  
  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
      console.log("Auto-refresh stopped")
    }
  }
  
  showToast(message, type = 'info') {
    // Hotwire Flash 또는 Alpine.js Toast 사용
    const event = new CustomEvent('toast:show', { 
      detail: { 
        message: message, 
        type: type,
        duration: 3000
      } 
    })
    window.dispatchEvent(event)
    
    // 기본 알림 (Toast 시스템이 없는 경우)
    if (type === 'error') {
      console.error('TaskMetrics: ', message)
    } else {
      console.info('TaskMetrics: ', message)
    }
  }
}