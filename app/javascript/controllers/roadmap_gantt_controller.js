import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loadingOverlay", "chartContainer"]
  
  static values = {
    serviceId: { type: Number, default: 0 },
    showCriticalPath: { type: Boolean, default: true },
    showDependencies: { type: Boolean, default: true },
    showMilestones: { type: Boolean, default: true },
    autoRefresh: { type: Boolean, default: false },
    refreshInterval: { type: Number, default: 90000 } // 1.5분
  }
  
  connect() {
    console.log("Roadmap Gantt controller connected")
    this.selectedTasks = new Set()
    this.setupEventListeners()
    this.initializeTooltips()
    this.setupChartInteractions()
    
    if (this.autoRefreshValue) {
      this.setupAutoRefresh()
    }
  }
  
  disconnect() {
    this.clearAutoRefresh()
    this.removeEventListeners()
    this.cleanupTooltips()
  }
  
  // 새로고침 기능
  async refresh() {
    try {
      this.showLoading()
      
      const response = await fetch(`/roadmaps/gantt?service_id=${this.serviceIdValue}`, {
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok && response.headers.get('content-type')?.includes('turbo-stream')) {
        const streamContent = await response.text()
        Turbo.renderStreamMessage(streamContent)
        this.reinitializeChart()
        console.log("Gantt chart refreshed via Turbo Stream")
      } else {
        // JSON 폴백
        const jsonResponse = await fetch(`/roadmaps/gantt?service_id=${this.serviceIdValue}`, {
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
          }
        })
        
        if (jsonResponse.ok) {
          const data = await jsonResponse.json()
          this.updateGanttData(data)
          console.log("Gantt chart refreshed via JSON")
        }
      }
    } catch (error) {
      console.error("Failed to refresh Gantt chart:", error)
      this.showError('간트 차트 업데이트에 실패했습니다')
    } finally {
      this.hideLoading()
    }
  }
  
  // 작업 선택 처리
  selectTask(event) {
    const taskId = parseInt(event.currentTarget.dataset.taskId)
    const taskRow = event.currentTarget
    
    if (event.ctrlKey || event.metaKey) {
      // 다중 선택
      this.toggleTaskSelection(taskId, taskRow)
    } else {
      // 단일 선택
      this.clearTaskSelection()
      this.selectSingleTask(taskId, taskRow)
    }
    
    this.updateSelectionInfo()
    this.showTaskDetails(taskId)
    
    console.log("Selected tasks:", Array.from(this.selectedTasks))
  }
  
  selectSingleTask(taskId, taskRow) {
    this.selectedTasks.clear()
    this.selectedTasks.add(taskId)
    
    // UI 업데이트
    taskRow.classList.add('bg-blue-50', 'border-l-4', 'border-blue-500')
  }
  
  toggleTaskSelection(taskId, taskRow) {
    if (this.selectedTasks.has(taskId)) {
      this.selectedTasks.delete(taskId)
      taskRow.classList.remove('bg-blue-50', 'border-l-4', 'border-blue-500')
    } else {
      this.selectedTasks.add(taskId)
      taskRow.classList.add('bg-blue-50', 'border-l-4', 'border-blue-500')
    }
  }
  
  clearTaskSelection() {
    this.selectedTasks.clear()
    
    // UI 정리
    this.element.querySelectorAll('[data-task-id]').forEach(row => {
      row.classList.remove('bg-blue-50', 'border-l-4', 'border-blue-500')
    })
  }
  
  // 표시 옵션 토글
  toggleCriticalPath() {
    this.showCriticalPathValue = !this.showCriticalPathValue
    this.updateChartVisibility()
    
    const message = this.showCriticalPathValue ? 
      '임계경로가 표시됩니다' : 
      '임계경로가 숨겨집니다'
    this.showToast(message, 'info')
  }
  
  toggleDependencies() {
    this.showDependenciesValue = !this.showDependenciesValue
    this.updateChartVisibility()
    
    const message = this.showDependenciesValue ? 
      '의존성이 표시됩니다' : 
      '의존성이 숨겨집니다'
    this.showToast(message, 'info')
  }
  
  toggleMilestones() {
    this.showMilestonesValue = !this.showMilestonesValue
    this.updateChartVisibility()
    
    const message = this.showMilestonesValue ? 
      '마일스톤이 표시됩니다' : 
      '마일스톤이 숨겨집니다'
    this.showToast(message, 'info')
  }
  
  // 차트 가시성 업데이트
  updateChartVisibility() {
    const chart = this.chartContainerTarget
    if (!chart) return
    
    // 임계경로 표시/숨김
    const criticalPathElements = chart.querySelectorAll('.critical-path')
    criticalPathElements.forEach(element => {
      element.style.display = this.showCriticalPathValue ? 'block' : 'none'
    })
    
    // 의존성 라인 표시/숨김
    const dependencyLines = chart.querySelectorAll('.dependency-lines')
    dependencyLines.forEach(element => {
      element.style.display = this.showDependenciesValue ? 'block' : 'none'
    })
    
    // 마일스톤 마커 표시/숨김
    const milestoneMarkers = chart.querySelectorAll('.milestone-marker')
    milestoneMarkers.forEach(element => {
      element.style.display = this.showMilestonesValue ? 'block' : 'none'
    })
  }
  
  // 확대/축소 기능
  zoomIn() {
    this.adjustZoom(1.25)
  }
  
  zoomOut() {
    this.adjustZoom(0.8)
  }
  
  resetZoom() {
    this.adjustZoom(1, true)
  }
  
  adjustZoom(factor, reset = false) {
    const container = this.chartContainerTarget
    if (!container) return
    
    const currentScale = reset ? 1 : (parseFloat(container.dataset.scale) || 1)
    const newScale = reset ? 1 : currentScale * factor
    
    // 스케일 제한
    const minScale = 0.3
    const maxScale = 5.0
    const finalScale = Math.min(Math.max(newScale, minScale), maxScale)
    
    container.dataset.scale = finalScale
    
    // SVG 스케일 조정
    const svg = container.querySelector('svg')
    if (svg) {
      svg.style.transform = `scale(${finalScale})`
      svg.style.transformOrigin = 'top left'
    }
    
    console.log(`Gantt zoom adjusted to ${finalScale}x`)
  }
  
  // 작업 필터링
  filterTasks(criteria) {
    const tasks = this.element.querySelectorAll('[data-task-id]')
    
    tasks.forEach(task => {
      const shouldShow = this.matchesFilterCriteria(task, criteria)
      task.style.display = shouldShow ? 'flex' : 'none'
    })
  }
  
  matchesFilterCriteria(taskElement, criteria) {
    if (!criteria || Object.keys(criteria).length === 0) return true
    
    const taskId = taskElement.dataset.taskId
    const taskData = this.getTaskData(taskId)
    
    // 상태 필터
    if (criteria.status && criteria.status.length > 0) {
      if (!criteria.status.includes(taskData.status)) return false
    }
    
    // 우선순위 필터
    if (criteria.priority && criteria.priority.length > 0) {
      if (!criteria.priority.includes(taskData.priority)) return false
    }
    
    // 담당자 필터
    if (criteria.assignee && criteria.assignee.length > 0) {
      const hasMatchingAssignee = taskData.assignees.some(assignee =>
        criteria.assignee.includes(assignee)
      )
      if (!hasMatchingAssignee) return false
    }
    
    // Epic 필터
    if (criteria.epic && criteria.epic.length > 0) {
      if (!criteria.epic.includes(taskData.epic_label)) return false
    }
    
    return true
  }
  
  // 작업 데이터 가져오기
  getTaskData(taskId) {
    const taskElement = this.element.querySelector(`[data-task-id="${taskId}"]`)
    if (!taskElement) return {}
    
    return {
      id: parseInt(taskId),
      status: taskElement.dataset.status || '',
      priority: taskElement.dataset.priority || '',
      assignees: (taskElement.dataset.assignees || '').split(',').filter(a => a.trim()),
      epic_label: taskElement.dataset.epic || '',
      progress: parseInt(taskElement.dataset.progress) || 0
    }
  }
  
  // 자동 새로고침 설정
  setupAutoRefresh() {
    if (this.autoRefreshValue && this.refreshIntervalValue > 0) {
      this.refreshTimer = setInterval(() => {
        this.refresh()
      }, this.refreshIntervalValue)
      console.log(`Gantt auto-refresh enabled: ${this.refreshIntervalValue}ms`)
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
    
    // 작업 바 hover 효과
    this.element.addEventListener('mouseenter', this.handleTaskHover.bind(this), { capture: true })
    this.element.addEventListener('mouseleave', this.handleTaskLeave.bind(this), { capture: true })
    
    // 윈도우 리사이즈 처리
    this.resizeHandler = this.handleResize.bind(this)
    window.addEventListener('resize', this.resizeHandler)
    
    // 차트 스크롤 동기화
    this.setupScrollSync()
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
    
    // Escape: 선택 해제
    if (event.key === 'Escape') {
      this.clearTaskSelection()
    }
    
    // Delete: 선택된 작업 삭제 (확인 후)
    if (event.key === 'Delete' && this.selectedTasks.size > 0) {
      this.confirmDeleteTasks()
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
  
  // 작업 hover 처리
  handleTaskHover(event) {
    const taskBar = event.target.closest('.task-bar')
    const taskRow = event.target.closest('[data-task-id]')
    
    if (taskBar || taskRow) {
      const taskId = (taskBar || taskRow).dataset.taskId || 
                    (taskBar || taskRow).closest('[data-task-id]').dataset.taskId
      this.showTaskTooltip(taskId, event)
    }
  }
  
  handleTaskLeave(event) {
    this.hideTooltip()
  }
  
  // 윈도우 리사이즈 처리
  handleResize() {
    if (this.chartContainerTarget) {
      this.recalculateGanttLayout()
    }
  }
  
  // 차트 상호작용 설정
  setupChartInteractions() {
    const container = this.chartContainerTarget
    if (!container) return
    
    // 드래그 스크롤 구현
    let isDragging = false
    let lastX = 0
    let lastY = 0
    
    container.addEventListener('mousedown', (e) => {
      if (e.button === 1) { // 마우스 휠 클릭
        isDragging = true
        lastX = e.clientX
        lastY = e.clientY
        container.style.cursor = 'grabbing'
        e.preventDefault()
      }
    })
    
    container.addEventListener('mousemove', (e) => {
      if (isDragging) {
        const deltaX = e.clientX - lastX
        const deltaY = e.clientY - lastY
        
        container.scrollLeft -= deltaX
        container.scrollTop -= deltaY
        
        lastX = e.clientX
        lastY = e.clientY
      }
    })
    
    container.addEventListener('mouseup', () => {
      isDragging = false
      container.style.cursor = 'default'
    })
    
    // 마우스 휠 줌
    container.addEventListener('wheel', (e) => {
      if (e.ctrlKey) {
        e.preventDefault()
        const zoomFactor = e.deltaY > 0 ? 0.9 : 1.1
        this.adjustZoom(zoomFactor)
      }
    })
  }
  
  // 스크롤 동기화 설정
  setupScrollSync() {
    const chartArea = this.element.querySelector('.gantt-chart-container')
    const taskLabels = this.element.querySelector('.task-labels')
    
    if (chartArea && taskLabels) {
      chartArea.addEventListener('scroll', () => {
        taskLabels.scrollTop = chartArea.scrollTop
      })
    }
  }
  
  // 툴팁 기능
  initializeTooltips() {
    this.tooltip = document.createElement('div')
    this.tooltip.className = 'absolute bg-gray-900 text-white text-sm rounded-lg py-3 px-4 pointer-events-none z-50 opacity-0 transition-opacity duration-200 shadow-lg'
    this.tooltip.style.maxWidth = '300px'
    document.body.appendChild(this.tooltip)
  }
  
  cleanupTooltips() {
    if (this.tooltip) {
      document.body.removeChild(this.tooltip)
      this.tooltip = null
    }
  }
  
  showTaskTooltip(taskId, event) {
    if (!this.tooltip) return
    
    const taskData = this.getTaskData(taskId)
    const taskElement = this.element.querySelector(`[data-task-id="${taskId}"]`)
    
    this.tooltip.innerHTML = `
      <div class="font-medium mb-2">${taskData.title || `Task #${taskId}`}</div>
      <div class="space-y-1 text-xs">
        <div class="flex justify-between">
          <span>상태:</span>
          <span class="capitalize">${taskData.status}</span>
        </div>
        <div class="flex justify-between">
          <span>진행률:</span>
          <span>${taskData.progress}%</span>
        </div>
        <div class="flex justify-between">
          <span>우선순위:</span>
          <span class="capitalize">${taskData.priority}</span>
        </div>
        <div class="flex justify-between">
          <span>담당자:</span>
          <span>${taskData.assignees.join(', ') || '없음'}</span>
        </div>
      </div>
    `
    
    const rect = taskElement.getBoundingClientRect()
    this.tooltip.style.left = `${event.clientX + 10}px`
    this.tooltip.style.top = `${event.clientY - this.tooltip.offsetHeight - 10}px`
    this.tooltip.style.opacity = '1'
  }
  
  hideTooltip() {
    if (this.tooltip) {
      this.tooltip.style.opacity = '0'
    }
  }
  
  // 작업 상세 정보 표시
  showTaskDetails(taskId) {
    const detailsContainer = this.element.querySelector('.task-details')
    if (!detailsContainer) return
    
    const taskData = this.getTaskData(taskId)
    
    detailsContainer.innerHTML = `
      <div class="task-details-content p-4">
        <h3 class="text-lg font-semibold mb-3">${taskData.title || `작업 #${taskId}`}</h3>
        
        <div class="grid grid-cols-2 gap-4 mb-4">
          <div>
            <label class="text-sm font-medium text-gray-700">상태</label>
            <p class="capitalize">${taskData.status}</p>
          </div>
          <div>
            <label class="text-sm font-medium text-gray-700">우선순위</label>
            <p class="capitalize">${taskData.priority}</p>
          </div>
        </div>
        
        <div class="mb-4">
          <label class="text-sm font-medium text-gray-700">진행률</label>
          <div class="mt-1">
            <div class="flex justify-between text-sm mb-1">
              <span>완료도</span>
              <span>${taskData.progress}%</span>
            </div>
            <div class="w-full bg-gray-200 rounded-full h-2">
              <div class="bg-blue-500 h-2 rounded-full transition-all duration-300" 
                   style="width: ${taskData.progress}%"></div>
            </div>
          </div>
        </div>
        
        <div class="mb-4">
          <label class="text-sm font-medium text-gray-700">담당자</label>
          <p>${taskData.assignees.join(', ') || '담당자 없음'}</p>
        </div>
      </div>
    `
    
    detailsContainer.classList.remove('hidden')
  }
  
  // 선택 정보 업데이트
  updateSelectionInfo() {
    const infoContainer = this.element.querySelector('.selection-info')
    if (!infoContainer) return
    
    const selectedCount = this.selectedTasks.size
    
    if (selectedCount === 0) {
      infoContainer.classList.add('hidden')
    } else {
      infoContainer.classList.remove('hidden')
      infoContainer.innerHTML = `
        <div class="flex items-center justify-between p-3 bg-blue-50 border border-blue-200 rounded-lg">
          <span class="text-sm text-blue-800">
            ${selectedCount}개 작업 선택됨
          </span>
          <div class="flex items-center space-x-2">
            <button class="text-xs bg-blue-500 text-white px-2 py-1 rounded hover:bg-blue-600"
                    data-action="click->roadmap-gantt#editSelectedTasks">
              편집
            </button>
            <button class="text-xs bg-gray-500 text-white px-2 py-1 rounded hover:bg-gray-600"
                    data-action="click->roadmap-gantt#clearTaskSelection">
              선택 해제
            </button>
          </div>
        </div>
      `
    }
  }
  
  // 간트 차트 레이아웃 재계산
  recalculateGanttLayout() {
    const container = this.chartContainerTarget
    if (!container) return
    
    // SVG 크기 재조정
    const svg = container.querySelector('svg')
    if (svg) {
      const containerWidth = container.offsetWidth
      svg.setAttribute('width', containerWidth)
      
      // 작업 바 위치 재계산
      this.recalculateTaskBarPositions()
    }
  }
  
  recalculateTaskBarPositions() {
    // 작업 바들의 위치를 컨테이너 크기에 맞게 재계산
    const taskBars = this.element.querySelectorAll('.task-bar')
    
    taskBars.forEach(bar => {
      const left = parseFloat(bar.dataset.left) || 0
      const width = parseFloat(bar.dataset.width) || 0
      
      // 반응형 위치 재계산
      bar.style.left = `${left}%`
      bar.style.width = `${width}%`
    })
  }
  
  // 차트 재초기화
  reinitializeChart() {
    this.updateChartVisibility()
    this.setupChartInteractions()
    this.recalculateGanttLayout()
  }
  
  // 데이터 업데이트 (JSON 응답 처리)
  updateGanttData(data) {
    if (!data.success || !data.gantt) {
      console.error('Invalid Gantt data received')
      return
    }
    
    // 차트 데이터 업데이트
    this.reinitializeChart()
    
    console.log("Gantt data updated successfully")
  }
  
  // 작업 삭제 확인
  confirmDeleteTasks() {
    if (this.selectedTasks.size === 0) return
    
    const confirmed = confirm(
      `선택된 ${this.selectedTasks.size}개 작업을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.`
    )
    
    if (confirmed) {
      this.deleteTasks(Array.from(this.selectedTasks))
    }
  }
  
  async deleteTasks(taskIds) {
    try {
      const response = await fetch('/tasks/bulk_delete', {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ task_ids: taskIds })
      })
      
      if (response.ok) {
        this.showToast(`${taskIds.length}개 작업이 삭제되었습니다`, 'success')
        this.clearTaskSelection()
        this.refresh()
      } else {
        throw new Error('Failed to delete tasks')
      }
    } catch (error) {
      console.error('Error deleting tasks:', error)
      this.showError('작업 삭제에 실패했습니다')
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
  
  showError(message) {
    console.error('Gantt Error:', message)
    this.showToast(message, 'error')
  }
  
  showToast(message, type = 'info') {
    const event = new CustomEvent('toast:show', { 
      detail: { 
        message: message, 
        type: type,
        duration: 4000
      } 
    })
    window.dispatchEvent(event)
  }
}