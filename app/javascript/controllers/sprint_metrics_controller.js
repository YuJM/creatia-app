import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "burndownChart", 
    "velocityChart",
    "riskList", 
    "dependencyGraph",
    "progressBar",
    "utilizationGauge",
    "loadingOverlay"
  ]
  
  static values = {
    sprintId: Number,
    refreshInterval: { type: Number, default: 30000 },
    autoRefresh: { type: Boolean, default: true }
  }
  
  connect() {
    console.log("Sprint metrics controller connected for sprint", this.sprintIdValue)
    this.charts = {}
    this.initializeCharts()
    this.loadMetrics()
    
    if (this.autoRefreshValue) {
      this.startAutoRefresh()
    }
  }
  
  disconnect() {
    this.stopAutoRefresh()
    this.destroyCharts()
  }
  
  // 메트릭 로드
  async loadMetrics() {
    try {
      this.showLoading(true)
      
      const [sprintData, dependencyData, riskData] = await Promise.all([
        this.fetchSprintMetrics(),
        this.fetchDependencyAnalysis(),
        this.fetchRiskAssessment()
      ])
      
      this.updateAllVisualizations(sprintData, dependencyData, riskData)
      this.showToast('메트릭이 업데이트되었습니다', 'success')
      
    } catch (error) {
      console.error("Failed to load metrics:", error)
      this.showToast('메트릭 로드에 실패했습니다', 'error')
    } finally {
      this.showLoading(false)
    }
  }
  
  async fetchSprintMetrics() {
    const response = await fetch(`/sprints/${this.sprintIdValue}/metrics`, {
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    
    if (!response.ok) throw new Error('Failed to fetch sprint metrics')
    return response.json()
  }
  
  async fetchDependencyAnalysis() {
    const response = await fetch(`/sprints/${this.sprintIdValue}/dependency_analysis`, {
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    
    if (!response.ok) throw new Error('Failed to fetch dependency analysis')
    return response.json()
  }
  
  async fetchRiskAssessment() {
    const response = await fetch(`/sprints/${this.sprintIdValue}/risk_assessment`, {
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    
    if (!response.ok) throw new Error('Failed to fetch risk assessment')
    return response.json()
  }
  
  // 차트 초기화
  initializeCharts() {
    if (this.hasBurndownChartTarget) {
      this.initBurndownChart()
    }
    
    if (this.hasVelocityChartTarget) {
      this.initVelocityChart()
    }
  }
  
  initBurndownChart() {
    const canvas = this.burndownChartTarget
    const ctx = canvas.getContext('2d')
    
    this.charts.burndown = new Chart(ctx, {
      type: 'line',
      data: {
        labels: [],
        datasets: [
          {
            label: '실제',
            data: [],
            borderColor: '#ef4444',
            backgroundColor: '#ef444420',
            tension: 0.1
          },
          {
            label: '이상적',
            data: [],
            borderColor: '#3b82f6',
            backgroundColor: '#3b82f620',
            borderDash: [5, 5],
            tension: 0
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: true,
            position: 'top'
          },
          tooltip: {
            mode: 'index',
            intersect: false
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: '남은 작업'
            }
          },
          x: {
            title: {
              display: true,
              text: '날짜'
            }
          }
        }
      }
    })
  }
  
  initVelocityChart() {
    const canvas = this.velocityChartTarget
    const ctx = canvas.getContext('2d')
    
    this.charts.velocity = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: [],
        datasets: [
          {
            label: '완료 작업',
            data: [],
            backgroundColor: '#10b981',
            borderColor: '#059669',
            borderWidth: 1
          },
          {
            label: '평균',
            data: [],
            type: 'line',
            borderColor: '#f59e0b',
            backgroundColor: 'transparent',
            borderWidth: 2,
            borderDash: [5, 5]
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: true
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: '작업 수'
            }
          }
        }
      }
    })
  }
  
  // 모든 시각화 업데이트
  updateAllVisualizations(sprintData, dependencyData, riskData) {
    this.updateBurndownChart(sprintData.burndown)
    this.updateVelocityChart(sprintData.velocity)
    this.updateProgressBar(sprintData.progress)
    this.updateUtilizationGauge(sprintData.utilization)
    this.updateRiskList(riskData.risks)
    this.updateDependencyAnalysis(dependencyData)
  }
  
  updateBurndownChart(burndownData) {
    if (!this.charts.burndown || !burndownData) return
    
    this.charts.burndown.data.labels = burndownData.dates
    this.charts.burndown.data.datasets[0].data = burndownData.actual
    this.charts.burndown.data.datasets[1].data = burndownData.ideal
    this.charts.burndown.update()
  }
  
  updateVelocityChart(velocityData) {
    if (!this.charts.velocity || !velocityData) return
    
    this.charts.velocity.data.labels = velocityData.sprints
    this.charts.velocity.data.datasets[0].data = velocityData.completed
    this.charts.velocity.data.datasets[1].data = velocityData.average
    this.charts.velocity.update()
  }
  
  updateProgressBar(progress) {
    if (!this.hasProgressBarTarget) return
    
    const progressBar = this.progressBarTarget
    const progressValue = progressBar.querySelector('.progress-value')
    const progressFill = progressBar.querySelector('.progress-fill')
    
    if (progressValue) {
      progressValue.textContent = `${progress}%`
    }
    
    if (progressFill) {
      progressFill.style.width = `${progress}%`
      
      // 진행률에 따른 색상 변경
      if (progress >= 90) {
        progressFill.className = 'progress-fill bg-green-500'
      } else if (progress >= 70) {
        progressFill.className = 'progress-fill bg-blue-500'
      } else if (progress >= 50) {
        progressFill.className = 'progress-fill bg-yellow-500'
      } else {
        progressFill.className = 'progress-fill bg-red-500'
      }
    }
  }
  
  updateUtilizationGauge(utilization) {
    if (!this.hasUtilizationGaugeTarget) return
    
    const gauge = this.utilizationGaugeTarget
    const gaugeValue = gauge.querySelector('.gauge-value')
    const gaugeFill = gauge.querySelector('.gauge-fill')
    
    if (gaugeValue) {
      gaugeValue.textContent = `${utilization}%`
    }
    
    if (gaugeFill) {
      // 반원 게이지 업데이트 (180도 회전)
      const rotation = Math.min(utilization * 1.8, 180)
      gaugeFill.style.transform = `rotate(${rotation}deg)`
      
      // 활용도에 따른 색상 변경
      if (utilization > 100) {
        gaugeFill.className = 'gauge-fill bg-red-500'
      } else if (utilization > 80) {
        gaugeFill.className = 'gauge-fill bg-yellow-500'
      } else {
        gaugeFill.className = 'gauge-fill bg-green-500'
      }
    }
  }
  
  updateRiskList(risks) {
    if (!this.hasRiskListTarget) return
    
    const riskList = this.riskListTarget
    
    if (!risks || risks.length === 0) {
      riskList.innerHTML = `
        <div class="text-center py-8 text-gray-500">
          <div class="text-2xl mb-2">✅</div>
          <p>식별된 리스크가 없습니다</p>
        </div>
      `
      return
    }
    
    const riskItems = risks.map(risk => {
      const severityClass = this.getRiskSeverityClass(risk.severity)
      const icon = this.getRiskIcon(risk.severity)
      
      return `
        <div class="risk-item p-3 border rounded-lg mb-2 ${severityClass}">
          <div class="flex items-start space-x-2">
            <span class="text-lg">${icon}</span>
            <div class="flex-1">
              <h4 class="font-medium text-gray-900">${risk.name}</h4>
              <p class="text-sm text-gray-600 mt-1">${risk.description}</p>
              <div class="flex items-center space-x-4 mt-2 text-xs text-gray-500">
                <span>확률: ${risk.probability}%</span>
                <span>영향도: ${risk.impact}/10</span>
                <span>점수: ${risk.score}</span>
              </div>
            </div>
          </div>
        </div>
      `
    }).join('')
    
    riskList.innerHTML = riskItems
  }
  
  updateDependencyAnalysis(dependencyData) {
    if (!this.hasDependencyGraphTarget) return
    
    const graphContainer = this.dependencyGraphTarget
    
    // 임계 경로 표시
    if (dependencyData.critical_path && dependencyData.critical_path.length > 0) {
      const criticalPathHtml = `
        <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg">
          <h4 class="font-medium text-red-900 mb-2">🎯 임계 경로</h4>
          <div class="flex flex-wrap gap-2">
            ${dependencyData.critical_path.map(taskId => 
              `<span class="px-2 py-1 bg-red-100 text-red-800 rounded text-sm">Task #${taskId}</span>`
            ).join('')}
          </div>
        </div>
      `
      graphContainer.innerHTML = criticalPathHtml
    }
    
    // 병목 작업 표시
    if (dependencyData.bottlenecks && dependencyData.bottlenecks.length > 0) {
      const bottlenecksHtml = `
        <div class="p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
          <h4 class="font-medium text-yellow-900 mb-2">⚠️ 병목 작업</h4>
          <div class="flex flex-wrap gap-2">
            ${dependencyData.bottlenecks.map(taskId => 
              `<span class="px-2 py-1 bg-yellow-100 text-yellow-800 rounded text-sm">Task #${taskId}</span>`
            ).join('')}
          </div>
        </div>
      `
      graphContainer.innerHTML += bottlenecksHtml
    }
    
    // 예상 완료일 표시
    if (dependencyData.completion_date) {
      const completionHtml = `
        <div class="mt-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
          <div class="flex items-center justify-between">
            <span class="text-sm font-medium text-blue-900">예상 완료일</span>
            <span class="text-lg font-bold text-blue-600">
              ${new Date(dependencyData.completion_date).toLocaleDateString('ko-KR')}
            </span>
          </div>
        </div>
      `
      graphContainer.innerHTML += completionHtml
    }
  }
  
  // 자동 새로고침
  startAutoRefresh() {
    if (this.refreshIntervalValue > 0) {
      this.refreshTimer = setInterval(() => {
        this.loadMetricsQuietly()
      }, this.refreshIntervalValue)
    }
  }
  
  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
  }
  
  async loadMetricsQuietly() {
    try {
      const [sprintData, dependencyData, riskData] = await Promise.all([
        this.fetchSprintMetrics(),
        this.fetchDependencyAnalysis(),
        this.fetchRiskAssessment()
      ])
      
      this.updateAllVisualizations(sprintData, dependencyData, riskData)
    } catch (error) {
      console.error("Auto-refresh failed:", error)
    }
  }
  
  // 수동 새로고침
  refresh() {
    this.loadMetrics()
  }
  
  toggleAutoRefresh() {
    this.autoRefreshValue = !this.autoRefreshValue
    
    if (this.autoRefreshValue) {
      this.startAutoRefresh()
      this.showToast('자동 새로고침이 활성화되었습니다', 'info')
    } else {
      this.stopAutoRefresh()
      this.showToast('자동 새로고침이 비활성화되었습니다', 'info')
    }
  }
  
  // 헬퍼 메서드들
  getRiskSeverityClass(severity) {
    switch(severity) {
      case 'critical':
        return 'border-red-500 bg-red-50'
      case 'high':
        return 'border-orange-500 bg-orange-50'
      case 'medium':
        return 'border-yellow-500 bg-yellow-50'
      case 'low':
        return 'border-green-500 bg-green-50'
      default:
        return 'border-gray-300 bg-gray-50'
    }
  }
  
  getRiskIcon(severity) {
    switch(severity) {
      case 'critical':
        return '🚨'
      case 'high':
        return '⚠️'
      case 'medium':
        return '📊'
      case 'low':
        return 'ℹ️'
      default:
        return '📝'
    }
  }
  
  showLoading(show) {
    if (this.hasLoadingOverlayTarget) {
      if (show) {
        this.loadingOverlayTarget.classList.remove('hidden')
      } else {
        this.loadingOverlayTarget.classList.add('hidden')
      }
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
  
  destroyCharts() {
    Object.values(this.charts).forEach(chart => {
      if (chart) {
        chart.destroy()
      }
    })
    this.charts = {}
  }
}