import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loadingOverlay", "lastUpdated"]
  
  static values = {
    autoRefresh: { type: Boolean, default: true },
    refreshInterval: { type: Number, default: 30000 } // 30초
  }
  
  connect() {
    console.log("Dashboard metrics controller connected")
    this.setupAutoRefresh()
    this.updateLastUpdated()
  }
  
  disconnect() {
    this.clearAutoRefresh()
  }
  
  // 자동 새로고침 설정
  setupAutoRefresh() {
    if (this.autoRefreshValue && this.refreshIntervalValue > 0) {
      this.refreshTimer = setInterval(() => {
        this.refreshMetrics()
      }, this.refreshIntervalValue)
      console.log(`Dashboard auto-refresh enabled: ${this.refreshIntervalValue}ms`)
    }
  }
  
  clearAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
  }
  
  // 수동 새로고침
  async refresh() {
    await this.refreshMetrics()
  }
  
  // 메트릭 새로고침
  async refreshMetrics() {
    try {
      this.showLoading()
      
      // Turbo Stream 우선 시도
      const turboResponse = await fetch('/dashboard/metrics', {
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (turboResponse.ok && turboResponse.headers.get('content-type')?.includes('turbo-stream')) {
        const streamContent = await turboResponse.text()
        Turbo.renderStreamMessage(streamContent)
        this.updateLastUpdated()
        console.log("Dashboard metrics refreshed via Turbo Stream")
        return
      }
      
      // JSON 폴백
      const jsonResponse = await fetch('/dashboard/metrics', {
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
      
      if (data.success && data.metrics) {
        this.updateMetricsDisplay(data.metrics, data.charts)
        this.updateLastUpdated()
        console.log("Dashboard metrics refreshed via JSON")
      } else {
        console.warn("No metrics data received")
      }
    } catch (error) {
      console.error("Failed to refresh dashboard metrics:", error)
      this.showError('메트릭 업데이트에 실패했습니다')
    } finally {
      this.hideLoading()
    }
  }
  
  // 특정 메트릭 업데이트 (JSON 응답 처리용)
  updateMetricsDisplay(metrics, charts) {
    // 팀 속도 업데이트
    this.updateMetricValue('velocity', metrics.velocity, '작업/주')
    
    // 완료율 업데이트
    this.updateMetricValue('completion-rate', metrics.completion_rate, '%')
    
    // 평균 처리 시간 업데이트
    this.updateMetricValue('cycle-time', metrics.average_cycle_time, '일')
    
    // 용량 활용도 업데이트 (계산 필요)
    if (metrics.workload_distribution && metrics.capacity) {
      const totalWorkload = Object.values(metrics.workload_distribution).reduce((sum, hours) => sum + hours, 0)
      const utilization = (totalWorkload / metrics.capacity * 100).toFixed(1)
      this.updateMetricValue('capacity-utilization', utilization, '%')
    }
    
    // 오늘 완료된 작업 수 업데이트
    this.updateMetricValue('tasks-today', metrics.tasks_completed_today, '개')
    
    // 지연된 작업 수 업데이트
    this.updateMetricValue('overdue-tasks', metrics.overdue_tasks_count, '개')
    
    // 우선순위 높은 작업 수 업데이트
    this.updateMetricValue('priority-tasks', metrics.high_priority_tasks_count, '개')
    
    // 차트 업데이트 (있는 경우)
    if (charts) {
      this.updateCharts(charts)
    }
  }
  
  updateMetricValue(metricName, value, unit = '') {
    const element = this.element.querySelector(`[data-metric="${metricName}"]`)
    if (element) {
      if (typeof value === 'number') {
        element.textContent = `${value.toFixed(1)}${unit}`
      } else {
        element.textContent = `${value}${unit}`
      }
      
      // 값 변경 애니메이션
      this.animateValueChange(element)
    }
  }
  
  animateValueChange(element) {
    element.classList.add('animate-pulse')
    setTimeout(() => {
      element.classList.remove('animate-pulse')
    }, 1000)
  }
  
  // 차트 업데이트
  updateCharts(chartData) {
    // 속도 트렌드 차트 업데이트
    if (chartData.velocity_trend) {
      this.updateVelocityChart(chartData.velocity_trend)
    }
    
    // 번다운 차트 업데이트
    if (chartData.burndown_data) {
      this.updateBurndownChart(chartData.burndown_data)
    }
    
    // 업무 분배 차트 업데이트
    if (chartData.workload_distribution) {
      this.updateWorkloadChart(chartData.workload_distribution)
    }
  }
  
  updateVelocityChart(velocityData) {
    const chartContainer = this.element.querySelector('#velocity-chart')
    if (!chartContainer || !velocityData.length) return
    
    try {
      // 간단한 선 차트 SVG 생성
      const maxVelocity = Math.max(...velocityData.map(d => d.velocity))
      const width = chartContainer.offsetWidth || 300
      const height = 150
      const padding = 30
      
      const points = velocityData.map((point, index) => {
        const x = padding + (index / (velocityData.length - 1)) * (width - 2 * padding)
        const y = height - padding - (point.velocity / maxVelocity) * (height - 2 * padding)
        return `${x.toFixed(2)},${y.toFixed(2)}`
      }).join(' ')
      
      const svg = `
        <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
          <polyline points="${points}" fill="none" stroke="#3b82f6" stroke-width="2"/>
          ${velocityData.map((point, index) => {
            const x = padding + (index / (velocityData.length - 1)) * (width - 2 * padding)
            const y = height - padding - (point.velocity / maxVelocity) * (height - 2 * padding)
            return `<circle cx="${x}" cy="${y}" r="3" fill="#3b82f6"/>`
          }).join('')}
        </svg>
      `
      
      chartContainer.innerHTML = svg
    } catch (error) {
      console.error('Failed to update velocity chart:', error)
    }
  }
  
  updateBurndownChart(burndownData) {
    const chartContainer = this.element.querySelector('#burndown-chart')
    if (!chartContainer || !burndownData.length) return
    
    try {
      const maxRemaining = Math.max(...burndownData.map(d => d.remaining))
      const width = chartContainer.offsetWidth || 300
      const height = 150
      const padding = 30
      
      // 실제 번다운 라인
      const actualPoints = burndownData.map((point, index) => {
        const x = padding + (index / (burndownData.length - 1)) * (width - 2 * padding)
        const y = height - padding - (point.remaining / maxRemaining) * (height - 2 * padding)
        return `${x.toFixed(2)},${y.toFixed(2)}`
      }).join(' ')
      
      // 이상적인 번다운 라인 (선형)
      const idealStart = burndownData[0]?.remaining || 0
      const idealPoints = burndownData.map((_, index) => {
        const x = padding + (index / (burndownData.length - 1)) * (width - 2 * padding)
        const remainingRatio = (burndownData.length - 1 - index) / (burndownData.length - 1)
        const idealRemaining = idealStart * remainingRatio
        const y = height - padding - (idealRemaining / maxRemaining) * (height - 2 * padding)
        return `${x.toFixed(2)},${y.toFixed(2)}`
      }).join(' ')
      
      const svg = `
        <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
          <polyline points="${idealPoints}" fill="none" stroke="#9ca3af" stroke-width="1" stroke-dasharray="5,5"/>
          <polyline points="${actualPoints}" fill="none" stroke="#ef4444" stroke-width="2"/>
        </svg>
      `
      
      chartContainer.innerHTML = svg
    } catch (error) {
      console.error('Failed to update burndown chart:', error)
    }
  }
  
  updateWorkloadChart(workloadData) {
    const chartContainer = this.element.querySelector('#workload-chart')
    if (!chartContainer || !Object.keys(workloadData).length) return
    
    try {
      const workloadArray = Object.entries(workloadData).map(([userId, hours]) => ({
        userId: parseInt(userId),
        hours: hours
      })).sort((a, b) => b.hours - a.hours).slice(0, 8) // 상위 8명만
      
      const maxHours = Math.max(...workloadArray.map(w => w.hours))
      const width = chartContainer.offsetWidth || 300
      const height = 150
      const padding = 30
      const barWidth = (width - 2 * padding) / workloadArray.length * 0.8
      
      const bars = workloadArray.map((workload, index) => {
        const x = padding + index * (width - 2 * padding) / workloadArray.length
        const barHeight = (workload.hours / maxHours) * (height - 2 * padding)
        const y = height - padding - barHeight
        const color = workload.hours > 40 ? '#ef4444' : workload.hours > 30 ? '#f59e0b' : '#3b82f6'
        
        return `<rect x="${x}" y="${y}" width="${barWidth}" height="${barHeight}" fill="${color}"/>`
      }).join('')
      
      const svg = `
        <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
          ${bars}
        </svg>
      `
      
      chartContainer.innerHTML = svg
    } catch (error) {
      console.error('Failed to update workload chart:', error)
    }
  }
  
  // UI 상태 관리
  showLoading() {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.classList.remove('hidden')
    }
  }
  
  hideLoading() {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.classList.add('hidden')
    }
  }
  
  updateLastUpdated() {
    if (this.hasLastUpdatedTarget) {
      const now = new Date()
      this.lastUpdatedTarget.textContent = now.toLocaleTimeString('ko-KR', {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
      })
    }
  }
  
  showError(message) {
    // 간단한 에러 표시 (실제로는 toast 시스템 사용)
    console.error('Dashboard Metrics:', message)
    
    // 에러 상태 표시
    const errorElement = this.element.querySelector('.error-message')
    if (errorElement) {
      errorElement.textContent = message
      errorElement.classList.remove('hidden')
      
      setTimeout(() => {
        errorElement.classList.add('hidden')
      }, 5000)
    }
  }
  
  // 키보드 단축키
  handleKeydown(event) {
    // R 키: 수동 새로고침
    if (event.key === 'r' && event.ctrlKey) {
      event.preventDefault()
      this.refresh()
    }
    
    // A 키: 자동 새로고침 토글
    if (event.key === 'a' && event.ctrlKey) {
      event.preventDefault()
      this.toggleAutoRefresh()
    }
  }
  
  toggleAutoRefresh() {
    this.autoRefreshValue = !this.autoRefreshValue
    
    if (this.autoRefreshValue) {
      this.setupAutoRefresh()
      this.showToast('자동 새로고침이 활성화되었습니다', 'info')
    } else {
      this.clearAutoRefresh()
      this.showToast('자동 새로고침이 비활성화되었습니다', 'info')
    }
  }
  
  showToast(message, type = 'info') {
    const event = new CustomEvent('toast:show', { 
      detail: { 
        message: message, 
        type: type,
        duration: 3000
      } 
    })
    window.dispatchEvent(event)
  }
  
  // 연결 시 이벤트 리스너 추가
  addEventListeners() {
    document.addEventListener('keydown', this.handleKeydown.bind(this))
  }
  
  // 연결 해제 시 이벤트 리스너 제거
  removeEventListeners() {
    document.removeEventListener('keydown', this.handleKeydown.bind(this))
  }
}