// app/javascript/controllers/burndown_chart_controller.js
import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from 'chart.js'

Chart.register(...registerables)

export default class extends Controller {
  static values = { 
    sprintId: String,
    data: Object 
  }
  
  connect() {
    this.loadChartData()
    this.initializeChart()
    
    // 실시간 업데이트를 위한 주기적 리로드
    this.refreshInterval = setInterval(() => {
      this.loadChartData()
    }, 30000) // 30초마다 갱신
  }
  
  disconnect() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
    }
    
    if (this.chart) {
      this.chart.destroy()
    }
  }
  
  async loadChartData() {
    if (this.hasDataValue) {
      // 데이터가 이미 제공된 경우
      this.renderChart(this.dataValue)
    } else {
      // 서버에서 데이터 가져오기
      try {
        const response = await fetch(`/web/services/${this.getServiceId()}/sprints/${this.sprintIdValue}/burndown.json`)
        const data = await response.json()
        this.renderChart(data)
      } catch (error) {
        console.error('Failed to load burndown data:', error)
      }
    }
  }
  
  initializeChart() {
    const ctx = this.element.querySelector('canvas').getContext('2d')
    
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: [],
        datasets: []
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: {
            display: true,
            text: 'Sprint Burndown Chart',
            font: {
              size: 16,
              weight: 'bold'
            }
          },
          legend: {
            display: true,
            position: 'bottom'
          },
          tooltip: {
            mode: 'index',
            intersect: false,
            callbacks: {
              label: function(context) {
                let label = context.dataset.label || ''
                if (label) {
                  label += ': '
                }
                label += context.parsed.y + ' points'
                return label
              }
            }
          }
        },
        scales: {
          x: {
            display: true,
            title: {
              display: true,
              text: 'Date'
            },
            grid: {
              display: false
            }
          },
          y: {
            display: true,
            title: {
              display: true,
              text: 'Story Points'
            },
            beginAtZero: true,
            grid: {
              borderDash: [5, 5]
            }
          }
        },
        interaction: {
          mode: 'nearest',
          axis: 'x',
          intersect: false
        }
      }
    })
  }
  
  renderChart(data) {
    if (!this.chart || !data) return
    
    // 날짜 레이블 생성
    const labels = this.generateDateLabels(data)
    
    // 이상적인 번다운 라인
    const idealData = data.ideal || []
    
    // 실제 번다운 데이터
    const actualData = data.actual || []
    
    // 차트 데이터 업데이트
    this.chart.data = {
      labels: labels,
      datasets: [
        {
          label: 'Ideal Burndown',
          data: idealData.map(d => d.remaining),
          borderColor: 'rgb(156, 163, 175)',
          backgroundColor: 'rgba(156, 163, 175, 0.1)',
          borderDash: [5, 5],
          tension: 0,
          pointRadius: 0
        },
        {
          label: 'Actual Burndown',
          data: actualData.map(d => d.remaining),
          borderColor: 'rgb(79, 70, 229)',
          backgroundColor: 'rgba(79, 70, 229, 0.1)',
          borderWidth: 2,
          tension: 0.1,
          pointRadius: 4,
          pointHoverRadius: 6
        }
      ]
    }
    
    // 남은 일수에 따른 경고 색상
    if (data.health_score < 50) {
      this.chart.data.datasets[1].borderColor = 'rgb(239, 68, 68)'
      this.chart.data.datasets[1].backgroundColor = 'rgba(239, 68, 68, 0.1)'
    } else if (data.health_score < 75) {
      this.chart.data.datasets[1].borderColor = 'rgb(245, 158, 11)'
      this.chart.data.datasets[1].backgroundColor = 'rgba(245, 158, 11, 0.1)'
    }
    
    this.chart.update()
    
    // 추가 메트릭 업데이트
    this.updateMetrics(data)
  }
  
  generateDateLabels(data) {
    const labels = []
    
    if (data.ideal && data.ideal.length > 0) {
      data.ideal.forEach(point => {
        const date = new Date(point.date)
        labels.push(date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }))
      })
    }
    
    return labels
  }
  
  updateMetrics(data) {
    // Health Score 업데이트
    const healthScoreEl = document.querySelector('[data-metric="health-score"]')
    if (healthScoreEl) {
      healthScoreEl.textContent = `${data.health_score}%`
      healthScoreEl.className = this.getHealthScoreClass(data.health_score)
    }
    
    // 남은 일수 업데이트
    const remainingDaysEl = document.querySelector('[data-metric="remaining-days"]')
    if (remainingDaysEl) {
      remainingDaysEl.textContent = `${data.remaining_days} days`
    }
    
    // 속도 메트릭 업데이트
    if (data.velocity) {
      const velocityEl = document.querySelector('[data-metric="velocity"]')
      if (velocityEl) {
        velocityEl.textContent = `${data.velocity} pts/day`
      }
    }
  }
  
  getHealthScoreClass(score) {
    if (score >= 75) {
      return 'text-green-600 font-semibold'
    } else if (score >= 50) {
      return 'text-yellow-600 font-semibold'
    } else {
      return 'text-red-600 font-semibold'
    }
  }
  
  getServiceId() {
    // URL에서 service ID 추출
    const pathParts = window.location.pathname.split('/')
    const serviceIndex = pathParts.indexOf('services')
    return pathParts[serviceIndex + 1]
  }
  
  // 수동 새로고침
  refresh() {
    this.loadChartData()
  }
}