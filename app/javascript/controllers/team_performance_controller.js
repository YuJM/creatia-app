import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "velocityTrend",
    "capacityGauge", 
    "teamHealthScore",
    "memberWorkload",
    "performanceMetrics",
    "loadingIndicator"
  ]
  
  static values = {
    teamId: Number,
    refreshInterval: { type: Number, default: 60000 }, // 1분
    autoRefresh: { type: Boolean, default: true }
  }
  
  connect() {
    console.log("Team performance controller connected")
    this.charts = {}
    this.initializeVisualizations()
    this.loadTeamMetrics()
    
    if (this.autoRefreshValue) {
      this.startAutoRefresh()
    }
    
    // 실시간 업데이트를 위한 WebSocket 연결 (옵션)
    this.setupRealtimeUpdates()
  }
  
  disconnect() {
    this.stopAutoRefresh()
    this.disconnectRealtime()
    this.destroyCharts()
  }
  
  // 팀 메트릭 로드
  async loadTeamMetrics() {
    try {
      this.showLoading(true)
      
      const response = await fetch('/dashboard/team_metrics', {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (!response.ok) throw new Error('Failed to load team metrics')
      
      const data = await response.json()
      this.updateAllMetrics(data.team_metrics)
      
    } catch (error) {
      console.error("Failed to load team metrics:", error)
      this.showError('팀 메트릭을 로드할 수 없습니다')
    } finally {
      this.showLoading(false)
    }
  }
  
  // 시각화 초기화
  initializeVisualizations() {
    if (this.hasVelocityTrendTarget) {
      this.initVelocityTrendChart()
    }
    
    if (this.hasCapacityGaugeTarget) {
      this.initCapacityGauge()
    }
    
    if (this.hasMemberWorkloadTarget) {
      this.initWorkloadChart()
    }
  }
  
  initVelocityTrendChart() {
    const canvas = this.velocityTrendTarget
    const ctx = canvas.getContext('2d')
    
    this.charts.velocityTrend = new Chart(ctx, {
      type: 'line',
      data: {
        labels: [],
        datasets: [
          {
            label: '팀 속도',
            data: [],
            borderColor: '#3b82f6',
            backgroundColor: '#3b82f620',
            tension: 0.3,
            fill: true
          },
          {
            label: '평균',
            data: [],
            borderColor: '#10b981',
            borderDash: [5, 5],
            borderWidth: 2,
            fill: false
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
            callbacks: {
              label: function(context) {
                return context.dataset.label + ': ' + context.parsed.y + ' 작업/스프린트'
              }
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: '완료 작업 수'
            }
          },
          x: {
            title: {
              display: true,
              text: '스프린트'
            }
          }
        }
      }
    })
  }
  
  initCapacityGauge() {
    const canvas = this.capacityGaugeTarget
    const ctx = canvas.getContext('2d')
    
    this.charts.capacityGauge = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: ['할당됨', '가용'],
        datasets: [{
          data: [0, 100],
          backgroundColor: ['#3b82f6', '#e5e7eb'],
          borderWidth: 0
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        circumference: 180,
        rotation: 270,
        cutout: '70%',
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return context.label + ': ' + context.parsed + '%'
              }
            }
          }
        }
      }
    })
  }
  
  initWorkloadChart() {
    const canvas = this.memberWorkloadTarget
    const ctx = canvas.getContext('2d')
    
    this.charts.workload = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: [],
        datasets: [{
          label: '할당된 시간',
          data: [],
          backgroundColor: [],
          borderColor: [],
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: 'y',
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return context.parsed.x + ' 시간'
              }
            }
          }
        },
        scales: {
          x: {
            beginAtZero: true,
            max: 40,
            title: {
              display: true,
              text: '주간 할당 시간'
            }
          }
        }
      }
    })
  }
  
  // 모든 메트릭 업데이트
  updateAllMetrics(metrics) {
    this.updateVelocityTrend(metrics.velocity_history)
    this.updateCapacityGauge(metrics.capacity_utilization)
    this.updateTeamHealthScore(metrics.health_score)
    this.updateMemberWorkload(metrics.member_workloads)
    this.updatePerformanceMetrics(metrics)
  }
  
  updateVelocityTrend(velocityData) {
    if (!this.charts.velocityTrend || !velocityData) return
    
    const labels = velocityData.map(d => d.sprint)
    const values = velocityData.map(d => d.velocity)
    const average = values.reduce((a, b) => a + b, 0) / values.length
    
    this.charts.velocityTrend.data.labels = labels
    this.charts.velocityTrend.data.datasets[0].data = values
    this.charts.velocityTrend.data.datasets[1].data = Array(values.length).fill(average)
    this.charts.velocityTrend.update()
    
    // 트렌드 분석 표시
    this.updateVelocityTrendAnalysis(values)
  }
  
  updateVelocityTrendAnalysis(values) {
    if (values.length < 2) return
    
    const recent = values.slice(-3)
    const trend = recent[recent.length - 1] - recent[0]
    
    let trendText, trendClass, trendIcon
    
    if (trend > 0) {
      trendText = `상승 추세 (+${trend.toFixed(1)})`
      trendClass = 'text-green-600'
      trendIcon = '📈'
    } else if (trend < 0) {
      trendText = `하락 추세 (${trend.toFixed(1)})`
      trendClass = 'text-red-600'
      trendIcon = '📉'
    } else {
      trendText = '안정적'
      trendClass = 'text-blue-600'
      trendIcon = '📊'
    }
    
    const trendElement = document.querySelector('[data-velocity-trend-analysis]')
    if (trendElement) {
      trendElement.innerHTML = `
        <span class="${trendClass} flex items-center space-x-1">
          <span>${trendIcon}</span>
          <span>${trendText}</span>
        </span>
      `
    }
  }
  
  updateCapacityGauge(utilization) {
    if (!this.charts.capacityGauge) return
    
    const allocated = Math.min(utilization, 100)
    const available = Math.max(100 - allocated, 0)
    
    // 색상 설정
    let color
    if (allocated > 90) {
      color = '#ef4444' // red
    } else if (allocated > 75) {
      color = '#f59e0b' // yellow
    } else {
      color = '#3b82f6' // blue
    }
    
    this.charts.capacityGauge.data.datasets[0].data = [allocated, available]
    this.charts.capacityGauge.data.datasets[0].backgroundColor[0] = color
    this.charts.capacityGauge.update()
    
    // 게이지 중앙 텍스트 업데이트
    const gaugeText = document.querySelector('[data-capacity-gauge-text]')
    if (gaugeText) {
      gaugeText.innerHTML = `
        <div class="text-center">
          <div class="text-3xl font-bold" style="color: ${color}">${allocated}%</div>
          <div class="text-sm text-gray-600">용량 활용률</div>
        </div>
      `
    }
  }
  
  updateTeamHealthScore(healthScore) {
    if (!this.hasTeamHealthScoreTarget) return
    
    const scoreElement = this.teamHealthScoreTarget
    const score = Math.round(healthScore)
    
    let status, statusClass, statusIcon
    
    if (score >= 80) {
      status = '매우 건강'
      statusClass = 'bg-green-100 text-green-800'
      statusIcon = '💚'
    } else if (score >= 60) {
      status = '건강'
      statusClass = 'bg-blue-100 text-blue-800'
      statusIcon = '💙'
    } else if (score >= 40) {
      status = '주의 필요'
      statusClass = 'bg-yellow-100 text-yellow-800'
      statusIcon = '💛'
    } else {
      status = '위험'
      statusClass = 'bg-red-100 text-red-800'
      statusIcon = '❤️'
    }
    
    scoreElement.innerHTML = `
      <div class="p-6 bg-white rounded-lg shadow">
        <h3 class="text-lg font-medium text-gray-900 mb-4">팀 건강도</h3>
        <div class="flex items-center justify-center">
          <div class="text-center">
            <div class="text-5xl mb-2">${statusIcon}</div>
            <div class="text-3xl font-bold text-gray-900">${score}</div>
            <div class="mt-2 px-3 py-1 rounded-full ${statusClass} text-sm font-medium">
              ${status}
            </div>
          </div>
        </div>
        <div class="mt-4 space-y-2">
          ${this.renderHealthFactors(healthScore)}
        </div>
      </div>
    `
  }
  
  renderHealthFactors(score) {
    const factors = [
      { name: '업무 균형', value: this.calculateWorkloadBalance(), max: 25 },
      { name: '생산성', value: this.calculateProductivity(), max: 25 },
      { name: '품질', value: this.calculateQuality(), max: 25 },
      { name: '만족도', value: this.calculateSatisfaction(), max: 25 }
    ]
    
    return factors.map(factor => `
      <div class="flex items-center justify-between text-sm">
        <span class="text-gray-600">${factor.name}</span>
        <div class="flex items-center space-x-2">
          <div class="w-24 bg-gray-200 rounded-full h-2">
            <div class="bg-blue-500 h-2 rounded-full" style="width: ${(factor.value/factor.max)*100}%"></div>
          </div>
          <span class="text-gray-900 font-medium">${factor.value}/${factor.max}</span>
        </div>
      </div>
    `).join('')
  }
  
  updateMemberWorkload(workloads) {
    if (!this.charts.workload || !workloads) return
    
    const members = Object.keys(workloads)
    const hours = Object.values(workloads)
    
    // 색상 설정 (과부하 상태별)
    const colors = hours.map(h => {
      if (h > 40) return '#ef4444' // red - 과부하
      if (h > 35) return '#f59e0b' // yellow - 높음
      if (h > 20) return '#3b82f6' // blue - 정상
      return '#10b981' // green - 여유
    })
    
    this.charts.workload.data.labels = members
    this.charts.workload.data.datasets[0].data = hours
    this.charts.workload.data.datasets[0].backgroundColor = colors
    this.charts.workload.data.datasets[0].borderColor = colors
    this.charts.workload.update()
    
    // 과부하 경고 표시
    this.showOverloadWarnings(members, hours)
  }
  
  showOverloadWarnings(members, hours) {
    const overloaded = members.filter((_, i) => hours[i] > 40)
    
    if (overloaded.length > 0) {
      const warningElement = document.querySelector('[data-overload-warning]')
      if (warningElement) {
        warningElement.innerHTML = `
          <div class="p-3 bg-red-50 border border-red-200 rounded-lg">
            <div class="flex items-center">
              <span class="text-red-600 mr-2">⚠️</span>
              <span class="text-sm text-red-800">
                ${overloaded.length}명의 팀원이 과부하 상태입니다
              </span>
            </div>
          </div>
        `
        warningElement.classList.remove('hidden')
      }
    }
  }
  
  updatePerformanceMetrics(metrics) {
    if (!this.hasPerformanceMetricsTarget) return
    
    const metricsElement = this.performanceMetricsTarget
    
    metricsElement.innerHTML = `
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        ${this.renderMetricCard('완료율', metrics.completion_rate, '%', 'green')}
        ${this.renderMetricCard('효율성', metrics.efficiency_ratio, '', 'blue')}
        ${this.renderMetricCard('평균 속도', metrics.average_velocity, '작업/주', 'purple')}
        ${this.renderMetricCard('블록 작업', metrics.blocked_tasks, '개', metrics.blocked_tasks > 5 ? 'red' : 'gray')}
      </div>
    `
  }
  
  renderMetricCard(label, value, unit, color) {
    const colorClasses = {
      green: 'bg-green-100 text-green-800',
      blue: 'bg-blue-100 text-blue-800',
      purple: 'bg-purple-100 text-purple-800',
      red: 'bg-red-100 text-red-800',
      gray: 'bg-gray-100 text-gray-800'
    }
    
    return `
      <div class="bg-white p-4 rounded-lg shadow">
        <div class="text-xs text-gray-600 uppercase tracking-wide">${label}</div>
        <div class="mt-2 flex items-baseline">
          <span class="text-2xl font-bold text-gray-900">${value}</span>
          <span class="ml-1 text-sm text-gray-600">${unit}</span>
        </div>
        <div class="mt-2">
          <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${colorClasses[color]}">
            ${this.getMetricStatus(label, value)}
          </span>
        </div>
      </div>
    `
  }
  
  getMetricStatus(metric, value) {
    switch(metric) {
      case '완료율':
        return value >= 90 ? '우수' : value >= 70 ? '양호' : '개선 필요'
      case '효율성':
        return value >= 1 ? '효율적' : '비효율적'
      case '평균 속도':
        return value >= 15 ? '빠름' : value >= 10 ? '보통' : '느림'
      case '블록 작업':
        return value <= 2 ? '양호' : value <= 5 ? '주의' : '위험'
      default:
        return '측정중'
    }
  }
  
  // 실시간 업데이트 설정 (ActionCable)
  setupRealtimeUpdates() {
    // ActionCable subscription for real-time updates
    if (typeof App !== 'undefined' && App.cable) {
      this.channel = App.cable.subscriptions.create(
        { channel: "TeamMetricsChannel", team_id: this.teamIdValue },
        {
          received: (data) => {
            console.log("Received real-time update:", data)
            this.updateAllMetrics(data)
          }
        }
      )
    }
  }
  
  disconnectRealtime() {
    if (this.channel) {
      this.channel.unsubscribe()
    }
  }
  
  // 자동 새로고침
  startAutoRefresh() {
    if (this.refreshIntervalValue > 0) {
      this.refreshTimer = setInterval(() => {
        this.loadTeamMetrics()
      }, this.refreshIntervalValue)
    }
  }
  
  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
  }
  
  // 헬퍼 메서드들
  calculateWorkloadBalance() {
    // 실제로는 서버에서 계산된 값을 사용
    return Math.floor(Math.random() * 25)
  }
  
  calculateProductivity() {
    return Math.floor(Math.random() * 25)
  }
  
  calculateQuality() {
    return Math.floor(Math.random() * 25)
  }
  
  calculateSatisfaction() {
    return Math.floor(Math.random() * 25)
  }
  
  showLoading(show) {
    if (this.hasLoadingIndicatorTarget) {
      if (show) {
        this.loadingIndicatorTarget.classList.remove('hidden')
      } else {
        this.loadingIndicatorTarget.classList.add('hidden')
      }
    }
  }
  
  showError(message) {
    console.error(message)
    // Toast notification
    const event = new CustomEvent('toast:show', { 
      detail: { 
        message: message, 
        type: 'error',
        duration: 5000
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