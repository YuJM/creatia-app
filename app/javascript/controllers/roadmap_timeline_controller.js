import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loadingOverlay", "chartContainer"]
  
  static values = {
    view: { type: String, default: "quarterly" },
    roadmapId: { type: Number, default: 0 },
    autoRefresh: { type: Boolean, default: false },
    refreshInterval: { type: Number, default: 60000 } // 1분
  }
  
  connect() {
    console.log("Roadmap timeline controller connected")
    this.setupEventListeners()
    this.initializeTooltips()
    this.setupTimelineNavigation()
    
    if (this.autoRefreshValue) {
      this.setupAutoRefresh()
    }
  }
  
  disconnect() {
    this.clearAutoRefresh()
    this.removeEventListeners()
  }
  
  // 새로고침 기능
  async refresh() {
    try {
      this.showLoading()
      
      const response = await fetch(`/roadmaps/${this.roadmapIdValue}/timeline`, {
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok && response.headers.get('content-type')?.includes('turbo-stream')) {
        const streamContent = await response.text()
        Turbo.renderStreamMessage(streamContent)
        console.log("Timeline refreshed via Turbo Stream")
      } else {
        // JSON 폴백
        const jsonResponse = await fetch(`/roadmaps/${this.roadmapIdValue}/timeline`, {
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
          }
        })
        
        if (jsonResponse.ok) {
          const data = await jsonResponse.json()
          this.updateTimelineData(data)
          console.log("Timeline refreshed via JSON")
        }
      }
    } catch (error) {
      console.error("Failed to refresh timeline:", error)
      this.showError('타임라인 업데이트에 실패했습니다')
    } finally {
      this.hideLoading()
    }
  }
  
  // 뷰 모드 변경
  changeView(event) {
    const newView = event.currentTarget.dataset.view
    if (newView && newView !== this.viewValue) {
      this.viewValue = newView
      this.refresh()
    }
  }
  
  // 타임라인 네비게이션
  navigateTimeline(event) {
    const direction = event.currentTarget.dataset.direction
    
    // 타임라인 스크롤 구현
    const container = this.chartContainerTarget
    const scrollAmount = container.offsetWidth * 0.8
    
    if (direction === 'prev') {
      container.scrollLeft -= scrollAmount
    } else if (direction === 'next') {
      container.scrollLeft += scrollAmount
    }
    
    // 부드러운 스크롤 애니메이션
    container.style.scrollBehavior = 'smooth'
    setTimeout(() => {
      container.style.scrollBehavior = 'auto'
    }, 500)
  }
  
  // 마일스톤 클릭 처리
  selectMilestone(event) {
    const milestoneId = event.currentTarget.dataset.milestoneId
    const milestoneCard = event.currentTarget
    
    // 기존 선택 제거
    this.element.querySelectorAll('.milestone-card').forEach(card => {
      card.classList.remove('ring-2', 'ring-blue-500', 'bg-blue-50')
    })
    
    // 새 선택 표시
    milestoneCard.classList.add('ring-2', 'ring-blue-500', 'bg-blue-50')
    
    // 마일스톤 상세 정보 표시
    this.showMilestoneDetails(milestoneId)
    
    console.log("Milestone selected:", milestoneId)
  }
  
  // 확대/축소 기능
  zoomIn() {
    this.adjustZoom(1.2)
  }
  
  zoomOut() {
    this.adjustZoom(0.8)
  }
  
  resetZoom() {
    this.adjustZoom(1, true)
  }
  
  adjustZoom(factor, reset = false) {
    const container = this.chartContainerTarget
    const currentScale = reset ? 1 : (parseFloat(container.dataset.scale) || 1)
    const newScale = reset ? 1 : currentScale * factor
    
    // 스케일 제한
    const minScale = 0.5
    const maxScale = 3.0
    const finalScale = Math.min(Math.max(newScale, minScale), maxScale)
    
    container.dataset.scale = finalScale
    container.style.transform = `scale(${finalScale})`
    container.style.transformOrigin = 'top left'
    
    console.log(`Zoom adjusted to ${finalScale}x`)
  }
  
  // 자동 새로고침 설정
  setupAutoRefresh() {
    if (this.autoRefreshValue && this.refreshIntervalValue > 0) {
      this.refreshTimer = setInterval(() => {
        this.refresh()
      }, this.refreshIntervalValue)
      console.log(`Timeline auto-refresh enabled: ${this.refreshIntervalValue}ms`)
    }
  }
  
  clearAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
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
  
  // 이벤트 리스너 설정
  setupEventListeners() {
    // 키보드 단축키
    this.keydownHandler = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.keydownHandler)
    
    // 마일스톤 hover 효과
    this.element.addEventListener('mouseenter', this.handleMilestoneHover.bind(this), { capture: true })
    this.element.addEventListener('mouseleave', this.handleMilestoneLeave.bind(this), { capture: true })
    
    // 윈도우 리사이즈 처리
    this.resizeHandler = this.handleResize.bind(this)
    window.addEventListener('resize', this.resizeHandler)
  }
  
  removeEventListeners() {
    if (this.keydownHandler) {
      document.removeEventListener('keydown', this.keydownHandler)
    }
    if (this.resizeHandler) {
      window.removeEventListener('resize', this.resizeHandler)
    }
  }
  
  // 키보드 단축키 처리
  handleKeydown(event) {
    // R 키: 새로고침
    if (event.key === 'r' && event.ctrlKey) {
      event.preventDefault()
      this.refresh()
    }
    
    // A 키: 자동 새로고침 토글
    if (event.key === 'a' && event.ctrlKey) {
      event.preventDefault()
      this.toggleAutoRefresh()
    }
    
    // 화살표 키: 타임라인 네비게이션
    if (event.key === 'ArrowLeft' && event.ctrlKey) {
      event.preventDefault()
      this.navigateTimeline({ currentTarget: { dataset: { direction: 'prev' } } })
    }
    
    if (event.key === 'ArrowRight' && event.ctrlKey) {
      event.preventDefault()
      this.navigateTimeline({ currentTarget: { dataset: { direction: 'next' } } })
    }
    
    // 줌 키
    if (event.key === '=' && event.ctrlKey) {
      event.preventDefault()
      this.zoomIn()
    }
    
    if (event.key === '-' && event.ctrlKey) {
      event.preventDefault()
      this.zoomOut()
    }
    
    if (event.key === '0' && event.ctrlKey) {
      event.preventDefault()
      this.resetZoom()
    }
  }
  
  // 마일스톤 hover 처리
  handleMilestoneHover(event) {
    const milestoneCard = event.target.closest('.milestone-card')
    if (milestoneCard) {
      this.showTooltip(milestoneCard)
    }
  }
  
  handleMilestoneLeave(event) {
    const milestoneCard = event.target.closest('.milestone-card')
    if (milestoneCard) {
      this.hideTooltip()
    }
  }
  
  // 윈도우 리사이즈 처리
  handleResize() {
    // 타임라인 차트 리사이즈 처리
    if (this.chartContainerTarget) {
      this.recalculatePositions()
    }
  }
  
  // 툴팁 기능
  initializeTooltips() {
    this.tooltip = document.createElement('div')
    this.tooltip.className = 'absolute bg-gray-900 text-white text-sm rounded py-2 px-3 pointer-events-none z-50 opacity-0 transition-opacity duration-200'
    document.body.appendChild(this.tooltip)
  }
  
  showTooltip(element) {
    const milestoneId = element.dataset.milestoneId
    if (!milestoneId) return
    
    const tooltipData = this.getMilestoneTooltipData(milestoneId)
    if (!tooltipData) return
    
    this.tooltip.innerHTML = `
      <div class="font-medium">${tooltipData.title}</div>
      <div class="text-xs mt-1">
        <div>진행률: ${tooltipData.progress}</div>
        <div>작업: ${tooltipData.tasks}</div>
        <div>위험도: ${tooltipData.risk}</div>
        <div>${tooltipData.days_remaining}</div>
      </div>
    `
    
    const rect = element.getBoundingClientRect()
    this.tooltip.style.left = `${rect.left + rect.width / 2}px`
    this.tooltip.style.top = `${rect.top - this.tooltip.offsetHeight - 8}px`
    this.tooltip.style.transform = 'translateX(-50%)'
    this.tooltip.style.opacity = '1'
  }
  
  hideTooltip() {
    if (this.tooltip) {
      this.tooltip.style.opacity = '0'
    }
  }
  
  getMilestoneTooltipData(milestoneId) {
    // 마일스톤 데이터에서 툴팁 정보 추출
    const milestoneElement = this.element.querySelector(`[data-milestone-id="${milestoneId}"]`)
    if (!milestoneElement) return null
    
    return {
      title: milestoneElement.querySelector('.milestone-title')?.textContent || 'Unknown',
      progress: milestoneElement.querySelector('.milestone-progress')?.textContent || '0%',
      tasks: milestoneElement.querySelector('.milestone-tasks')?.textContent || '0/0',
      risk: milestoneElement.querySelector('.milestone-risk')?.textContent || 'Unknown',
      days_remaining: milestoneElement.querySelector('.milestone-days')?.textContent || ''
    }
  }
  
  // 타임라인 네비게이션 설정
  setupTimelineNavigation() {
    const container = this.chartContainerTarget
    if (!container) return
    
    // 스크롤 이벤트로 네비게이션 버튼 상태 업데이트
    container.addEventListener('scroll', () => {
      const prevBtn = this.element.querySelector('[data-direction="prev"]')
      const nextBtn = this.element.querySelector('[data-direction="next"]')
      
      if (prevBtn && nextBtn) {
        prevBtn.disabled = container.scrollLeft <= 0
        nextBtn.disabled = container.scrollLeft >= (container.scrollWidth - container.clientWidth)
      }
    })
  }
  
  // 데이터 업데이트 (JSON 응답 처리)
  updateTimelineData(data) {
    if (!data.success || !data.timeline) {
      console.error('Invalid timeline data received')
      return
    }
    
    // 마일스톤 위치 재계산 및 업데이트
    this.recalculatePositions()
    
    // 상태 정보 업데이트
    this.updateStatusSummary(data.timeline)
    
    console.log("Timeline data updated successfully")
  }
  
  // 위치 재계산
  recalculatePositions() {
    const milestoneCards = this.element.querySelectorAll('.milestone-card')
    
    milestoneCards.forEach(card => {
      // 위치 재계산 로직
      const position = parseFloat(card.style.left)
      if (!isNaN(position)) {
        // 반응형 위치 조정
        const containerWidth = this.chartContainerTarget.offsetWidth
        const adjustedPosition = position * (containerWidth / 1000) // 기본 너비 대비 조정
        card.style.left = `${adjustedPosition}px`
      }
    })
  }
  
  // 상태 요약 업데이트
  updateStatusSummary(timelineData) {
    const summaryElements = this.element.querySelectorAll('[data-metric]')
    
    summaryElements.forEach(element => {
      const metric = element.dataset.metric
      const value = timelineData[metric]
      
      if (value !== undefined) {
        element.textContent = value
        this.animateValueChange(element)
      }
    })
  }
  
  // 값 변경 애니메이션
  animateValueChange(element) {
    element.classList.add('animate-pulse')
    setTimeout(() => {
      element.classList.remove('animate-pulse')
    }, 1000)
  }
  
  // 마일스톤 상세 정보 표시
  showMilestoneDetails(milestoneId) {
    // 마일스톤 상세 정보를 사이드바나 모달로 표시
    const detailsContainer = this.element.querySelector('.milestone-details')
    if (detailsContainer) {
      // 상세 정보 로드 및 표시
      this.loadMilestoneDetails(milestoneId)
        .then(details => {
          detailsContainer.innerHTML = this.renderMilestoneDetails(details)
          detailsContainer.classList.remove('hidden')
        })
        .catch(error => {
          console.error('Failed to load milestone details:', error)
        })
    }
  }
  
  async loadMilestoneDetails(milestoneId) {
    const response = await fetch(`/milestones/${milestoneId}`, {
      headers: {
        'Accept': 'application/json'
      }
    })
    
    if (!response.ok) {
      throw new Error('Failed to fetch milestone details')
    }
    
    return response.json()
  }
  
  renderMilestoneDetails(details) {
    return `
      <div class="milestone-details-content">
        <h3 class="text-lg font-semibold mb-2">${details.name}</h3>
        <p class="text-gray-600 mb-4">${details.description || '설명이 없습니다'}</p>
        
        <div class="space-y-2">
          <div class="flex justify-between">
            <span>목표일:</span>
            <span>${details.target_date}</span>
          </div>
          <div class="flex justify-between">
            <span>진행률:</span>
            <span>${details.progress}%</span>
          </div>
          <div class="flex justify-between">
            <span>작업 수:</span>
            <span>${details.tasks_count}개</span>
          </div>
          <div class="flex justify-between">
            <span>상태:</span>
            <span class="capitalize">${details.status}</span>
          </div>
        </div>
      </div>
    `
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
  
  showError(message) {
    console.error('Timeline Error:', message)
    this.showToast(message, 'error')
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