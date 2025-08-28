import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loadingOverlay", "workloadChart", "riskIndicator"]
  
  static values = { 
    sprintId: Number,
    autoRefresh: { type: Boolean, default: false },
    refreshInterval: { type: Number, default: 60000 } // 1분
  }
  
  connect() {
    console.log("Sprint plan controller connected for sprint", this.sprintIdValue)
    this.setupAutoRefresh()
    this.setupInteractions()
  }
  
  disconnect() {
    this.clearAutoRefresh()
    this.clearInteractions()
  }
  
  // 자동 새로고침 설정
  setupAutoRefresh() {
    if (this.autoRefreshValue && this.refreshIntervalValue > 0) {
      this.refreshTimer = setInterval(() => {
        this.refreshPlan()
      }, this.refreshIntervalValue)
      console.log(`Sprint plan auto-refresh enabled: ${this.refreshIntervalValue}ms`)
    }
  }
  
  clearAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
  }
  
  // 상호작용 설정
  setupInteractions() {
    // 툴팁 초기화
    this.initializeTooltips()
    
    // 차트 초기화 
    this.initializeCharts()
    
    // 키보드 단축키 설정
    document.addEventListener('keydown', this.handleKeydown.bind(this))
  }
  
  clearInteractions() {
    document.removeEventListener('keydown', this.handleKeydown.bind(this))
  }
  
  // Sprint 계획 새로고침
  async refresh() {
    await this.refreshPlan()
  }
  
  async refreshPlan() {
    if (!this.sprintIdValue) {
      console.error("No sprint ID provided for plan refresh")
      return
    }
    
    try {
      this.showLoading()
      
      const response = await fetch(`/sprints/${this.sprintIdValue}/plan`, {
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok && response.headers.get('content-type')?.includes('turbo-stream')) {
        const streamContent = await response.text()
        Turbo.renderStreamMessage(streamContent)
        
        // 차트 다시 초기화
        this.initializeCharts()
        
        console.log("Sprint plan refreshed successfully")
      } else {
        throw new Error(`Failed to refresh sprint plan: ${response.status}`)
      }
    } catch (error) {
      console.error("Failed to refresh sprint plan:", error)
      this.showToast('계획 새로고침에 실패했습니다', 'error')
    } finally {
      this.hideLoading()
    }
  }
  
  // 업무 분배 시각화
  initializeCharts() {
    this.initializeWorkloadChart()
    this.initializeRiskIndicators()
  }
  
  initializeWorkloadChart() {
    if (!this.hasWorkloadChartTarget) return
    
    const chartData = this.extractWorkloadData()
    if (chartData.length === 0) return
    
    this.renderWorkloadChart(chartData)
  }
  
  extractWorkloadData() {
    const workloadItems = this.element.querySelectorAll('[data-user-workload]')
    return Array.from(workloadItems).map(item => ({
      user: item.dataset.userName || 'Unknown',
      hours: parseFloat(item.dataset.userHours) || 0,
      percentage: parseFloat(item.dataset.userPercentage) || 0,
      status: item.dataset.userStatus || 'unknown'
    })).filter(data => data.hours > 0)
  }
  
  renderWorkloadChart(data) {
    const chartContainer = this.workloadChartTarget
    
    // 간단한 가로 바 차트 생성
    const maxHours = Math.max(...data.map(d => d.hours))
    const barHeight = 24
    const chartHeight = data.length * (barHeight + 8)
    
    const svg = this.createSVGElement('svg', {
      width: '100%',
      height: chartHeight,
      viewBox: `0 0 400 ${chartHeight}`
    })
    
    data.forEach((user, index) => {
      const y = index * (barHeight + 8)
      const barWidth = (user.hours / maxHours) * 300
      const color = this.getStatusColor(user.status)
      
      // 배경 바
      svg.appendChild(this.createSVGElement('rect', {
        x: 80,
        y: y,
        width: 300,
        height: barHeight,
        fill: '#f3f4f6',
        rx: 4
      }))
      
      // 실제 바
      svg.appendChild(this.createSVGElement('rect', {
        x: 80,
        y: y,
        width: barWidth,
        height: barHeight,
        fill: color,
        rx: 4
      }))
      
      // 사용자 이름
      svg.appendChild(this.createSVGElement('text', {
        x: 5,
        y: y + barHeight / 2 + 4,
        'font-size': 12,
        'font-weight': 'medium',
        fill: '#374151'
      })).textContent = user.user
      
      // 시간 표시
      svg.appendChild(this.createSVGElement('text', {
        x: 390,
        y: y + barHeight / 2 + 4,
        'font-size': 12,
        'text-anchor': 'end',
        fill: '#6b7280'
      })).textContent = `${user.hours}h`
    })
    
    chartContainer.innerHTML = ''
    chartContainer.appendChild(svg)
  }
  
  createSVGElement(tagName, attributes) {
    const element = document.createElementNS('http://www.w3.org/2000/svg', tagName)
    Object.entries(attributes).forEach(([key, value]) => {
      element.setAttribute(key, value)
    })
    return element
  }
  
  getStatusColor(status) {
    const colors = {
      '여유': '#10b981',
      '적정': '#3b82f6',
      '포화': '#f59e0b',
      '과부하': '#ef4444'
    }
    return colors[status] || '#6b7280'
  }
  
  // 리스크 인디케이터 초기화
  initializeRiskIndicators() {
    if (!this.hasRiskIndicatorTarget) return
    
    const riskElements = this.element.querySelectorAll('[data-risk-level]')
    riskElements.forEach(element => {
      const riskLevel = element.dataset.riskLevel
      this.animateRiskIndicator(element, riskLevel)
    })
  }
  
  animateRiskIndicator(element, level) {
    const colors = {
      'low': '#10b981',
      'medium': '#f59e0b', 
      'high': '#ef4444'
    }
    
    const color = colors[level] || '#6b7280'
    element.style.borderLeftColor = color
    
    // 펄스 애니메이션 추가 (높은 리스크인 경우)
    if (level === 'high') {
      element.classList.add('animate-pulse')
    }
  }
  
  // 툴팁 초기화
  initializeTooltips() {
    const tooltipTriggers = this.element.querySelectorAll('[data-tooltip]')
    tooltipTriggers.forEach(trigger => {
      trigger.addEventListener('mouseenter', this.showTooltip.bind(this))
      trigger.addEventListener('mouseleave', this.hideTooltip.bind(this))
    })
  }
  
  showTooltip(event) {
    const trigger = event.target
    const tooltipText = trigger.dataset.tooltip
    
    if (!tooltipText) return
    
    const tooltip = document.createElement('div')
    tooltip.id = 'sprint-plan-tooltip'
    tooltip.className = 'absolute z-50 px-2 py-1 text-sm text-white bg-gray-900 rounded shadow-lg pointer-events-none'
    tooltip.textContent = tooltipText
    
    // 위치 계산
    const rect = trigger.getBoundingClientRect()
    tooltip.style.left = rect.left + 'px'
    tooltip.style.top = (rect.top - 30) + 'px'
    
    document.body.appendChild(tooltip)
  }
  
  hideTooltip(event) {
    const tooltip = document.getElementById('sprint-plan-tooltip')
    if (tooltip) {
      tooltip.remove()
    }
  }
  
  // 권장사항 확인 처리
  acknowledgeRecommendation(event) {
    const recommendationElement = event.target.closest('[data-recommendation]')
    if (!recommendationElement) return
    
    const recommendationType = recommendationElement.dataset.recommendation
    
    // 서버에 확인 상태 전송 (선택사항)
    this.sendRecommendationAck(recommendationType)
    
    // UI 업데이트
    recommendationElement.classList.add('opacity-50')
    const button = recommendationElement.querySelector('button')
    if (button) {
      button.textContent = '✓ 확인됨'
      button.disabled = true
    }
  }
  
  async sendRecommendationAck(type) {
    try {
      await fetch(`/sprints/${this.sprintIdValue}/recommendations/${type}/acknowledge`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        }
      })
    } catch (error) {
      console.warn('Failed to acknowledge recommendation:', error)
    }
  }
  
  // 사용자 업무 재분배 제안
  suggestRebalance(event) {
    const userElement = event.target.closest('[data-user-workload]')
    if (!userElement) return
    
    const userName = userElement.dataset.userName
    const userHours = parseFloat(userElement.dataset.userHours)
    
    if (userHours > 40) { // 과부하 기준
      this.showRebalanceModal(userName, userHours)
    }
  }
  
  showRebalanceModal(userName, hours) {
    const modalHtml = `
      <div id="rebalance-modal" class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
        <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
          <div class="mt-3">
            <h3 class="text-lg font-medium text-gray-900 mb-3">업무 재분배 제안</h3>
            <p class="text-sm text-gray-600 mb-4">
              ${userName}님의 업무량이 ${hours}시간으로 과부하 상태입니다. 
              일부 작업을 다른 팀원에게 재분배하는 것을 고려해보세요.
            </p>
            <div class="flex justify-end space-x-3">
              <button type="button" onclick="document.getElementById('rebalance-modal').remove()" 
                      class="bg-gray-300 hover:bg-gray-400 text-gray-800 font-medium py-2 px-4 rounded">
                나중에
              </button>
              <button type="button" onclick="window.open('/tasks?assigned_user=${userName}', '_blank'); document.getElementById('rebalance-modal').remove()" 
                      class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded">
                작업 보기
              </button>
            </div>
          </div>
        </div>
      </div>
    `
    
    document.body.insertAdjacentHTML('beforeend', modalHtml)
  }
  
  // 로딩 상태 관리
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
  
  // 키보드 단축키 처리
  handleKeydown(event) {
    // R 키: 계획 새로고침
    if (event.key === 'r' && event.ctrlKey) {
      event.preventDefault()
      this.refreshPlan()
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
  
  // 유틸리티 메서드들
  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
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
}