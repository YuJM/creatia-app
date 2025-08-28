import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loadingOverlay"]
  
  static values = { 
    sprintId: Number
  }
  
  connect() {
    console.log("Sprint card controller connected for sprint", this.sprintIdValue)
  }
  
  // 메트릭 새로고침
  async refreshMetrics() {
    if (!this.sprintIdValue) {
      console.error("No sprint ID provided for metrics refresh")
      return
    }
    
    try {
      this.showLoading()
      
      // Turbo Stream을 우선 시도
      const turboResponse = await fetch(`/sprints/${this.sprintIdValue}/metrics`, {
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (turboResponse.ok && turboResponse.headers.get('content-type')?.includes('turbo-stream')) {
        const streamContent = await turboResponse.text()
        Turbo.renderStreamMessage(streamContent)
        this.showToast('메트릭이 업데이트되었습니다', 'success')
        return
      }
      
      // JSON 폴백
      const jsonResponse = await fetch(`/sprints/${this.sprintIdValue}/metrics`, {
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
        // 메트릭 데이터 업데이트 (필요한 경우 DOM 직접 조작)
        this.updateMetricsDisplay(data.metrics, data.user_friendly)
        this.showToast('메트릭이 업데이트되었습니다', 'success')
      } else {
        console.warn("No metrics data received")
      }
    } catch (error) {
      console.error("Failed to refresh sprint metrics:", error)
      this.showToast('메트릭 업데이트에 실패했습니다', 'error')
    } finally {
      this.hideLoading()
    }
  }
  
  // Sprint 계획 로드
  async loadPlan(event) {
    event.preventDefault()
    
    if (!this.sprintIdValue) {
      console.error("No sprint ID provided for plan loading")
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
        
        // 모달 또는 사이드바 표시 로직
        this.showPlanModal()
      } else {
        throw new Error(`Failed to load sprint plan: ${response.status}`)
      }
    } catch (error) {
      console.error("Failed to load sprint plan:", error)
      this.showToast('스프린트 계획을 불러올 수 없습니다', 'error')
    } finally {
      this.hideLoading()
    }
  }
  
  // Sprint 계획 생성
  async generatePlan() {
    if (!this.sprintIdValue) {
      console.error("No sprint ID provided for plan generation")
      return
    }
    
    // 사용자 확인
    const confirmed = confirm("스프린트 계획을 새로 생성하시겠습니까? 시간이 다소 걸릴 수 있습니다.")
    if (!confirmed) return
    
    try {
      this.showLoading("계획을 생성하고 있습니다...")
      
      const response = await fetch(`/sprints/${this.sprintIdValue}/plan`, {
        method: 'POST',
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': this.getCSRFToken()
        }
      })
      
      if (response.ok && response.headers.get('content-type')?.includes('turbo-stream')) {
        const streamContent = await response.text()
        Turbo.renderStreamMessage(streamContent)
        this.showToast('스프린트 계획이 생성되었습니다', 'success')
        this.showPlanModal()
      } else {
        const errorData = await response.json().catch(() => ({}))
        throw new Error(errorData.message || `계획 생성 실패: ${response.status}`)
      }
    } catch (error) {
      console.error("Failed to generate sprint plan:", error)
      this.showToast(error.message || '계획 생성에 실패했습니다', 'error')
    } finally {
      this.hideLoading()
    }
  }
  
  // 메트릭 표시 업데이트 (JSON 응답 처리용)
  updateMetricsDisplay(metrics, userFriendly) {
    // 속도 업데이트
    const velocityElement = this.element.querySelector('[data-metric="velocity"]')
    if (velocityElement && metrics.velocity) {
      velocityElement.textContent = metrics.velocity.toFixed(1)
    }
    
    // 용량 업데이트
    const capacityElement = this.element.querySelector('[data-metric="capacity"]')
    if (capacityElement && metrics.capacity) {
      capacityElement.textContent = `${metrics.capacity.toFixed(1)}h`
    }
    
    // 완료율 업데이트
    const completionElement = this.element.querySelector('[data-metric="completion"]')
    if (completionElement && metrics.completion_rate) {
      completionElement.textContent = `${metrics.completion_rate.toFixed(1)}%`
    }
    
    // 번다운 트렌드 업데이트
    if (userFriendly && userFriendly.burndown_trend) {
      const trendElement = this.element.querySelector('[data-metric="burndown-trend"]')
      if (trendElement) {
        trendElement.textContent = userFriendly.burndown_trend
        
        // 트렌드에 따른 색상 변경
        trendElement.classList.remove('text-green-600', 'text-yellow-600', 'text-red-600')
        if (userFriendly.burndown_trend.includes('개선')) {
          trendElement.classList.add('text-green-600')
        } else if (userFriendly.burndown_trend.includes('정체')) {
          trendElement.classList.add('text-yellow-600')
        } else {
          trendElement.classList.add('text-red-600')
        }
      }
    }
  }
  
  // 계획 모달 표시
  showPlanModal() {
    // 모달이 있는 경우 표시
    const modal = document.getElementById('sprint-plan-modal')
    if (modal) {
      modal.classList.remove('hidden')
      document.body.classList.add('overflow-hidden')
    }
    
    // 사이드바가 있는 경우 표시  
    const sidebar = document.getElementById('sprint-plan-sidebar')
    if (sidebar) {
      sidebar.classList.remove('translate-x-full')
    }
  }
  
  // 계획 모달 숨김
  hidePlanModal() {
    const modal = document.getElementById('sprint-plan-modal')
    if (modal) {
      modal.classList.add('hidden')
      document.body.classList.remove('overflow-hidden')
    }
    
    const sidebar = document.getElementById('sprint-plan-sidebar')
    if (sidebar) {
      sidebar.classList.add('translate-x-full')
    }
  }
  
  // 로딩 상태 표시
  showLoading(message = "업데이트 중...") {
    if (this.hasLoadingOverlayTarget) {
      const messageElement = this.loadingOverlayTarget.querySelector('span')
      if (messageElement) {
        messageElement.textContent = message
      }
      this.loadingOverlayTarget.classList.remove('hidden')
    }
  }
  
  // 로딩 상태 숨김
  hideLoading() {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.classList.add('hidden')
    }
  }
  
  // CSRF 토큰 가져오기
  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }
  
  // 토스트 메시지 표시
  showToast(message, type = 'info') {
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
      console.error('Sprint Card: ', message)
    } else {
      console.info('Sprint Card: ', message)
    }
  }
  
  // 키보드 단축키 처리
  handleKeydown(event) {
    // R 키: 메트릭 새로고침
    if (event.key === 'r' && event.ctrlKey) {
      event.preventDefault()
      this.refreshMetrics()
    }
    
    // P 키: 계획 보기
    if (event.key === 'p' && event.ctrlKey) {
      event.preventDefault()
      this.loadPlan(event)
    }
    
    // ESC 키: 모달 닫기
    if (event.key === 'Escape') {
      this.hidePlanModal()
    }
  }
  
  // 연결 시 키보드 이벤트 리스너 추가
  addKeyboardListeners() {
    document.addEventListener('keydown', this.handleKeydown.bind(this))
  }
  
  // 연결 해제 시 키보드 이벤트 리스너 제거
  removeKeyboardListeners() {
    document.removeEventListener('keydown', this.handleKeydown.bind(this))
  }
}