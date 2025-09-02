import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  connect() {
    console.log("Timeline controller connected")
    this.setupTooltips()
    this.setupDragAndDrop()
  }

  // View mode changes (Month/Quarter/Year)
  changeView(event) {
    const viewMode = event.currentTarget.dataset.view
    const url = new URL(window.location)
    url.searchParams.set('view_mode', viewMode)
    
    Turbo.visit(url.toString())
  }

  // Navigate to previous period
  previous() {
    const url = new URL(window.location)
    const currentStart = url.searchParams.get('start_date')
    const viewMode = url.searchParams.get('view_mode') || 'quarter'
    
    let newStartDate
    if (currentStart) {
      const date = new Date(currentStart)
      
      switch(viewMode) {
        case 'month':
          date.setMonth(date.getMonth() - 1)
          break
        case 'quarter':
          date.setMonth(date.getMonth() - 3)
          break
        case 'year':
          date.setFullYear(date.getFullYear() - 1)
          break
      }
      
      newStartDate = date.toISOString().split('T')[0]
    }
    
    if (newStartDate) {
      url.searchParams.set('start_date', newStartDate)
      Turbo.visit(url.toString())
    }
  }

  // Navigate to next period
  next() {
    const url = new URL(window.location)
    const currentStart = url.searchParams.get('start_date')
    const viewMode = url.searchParams.get('view_mode') || 'quarter'
    
    let newStartDate
    if (currentStart) {
      const date = new Date(currentStart)
      
      switch(viewMode) {
        case 'month':
          date.setMonth(date.getMonth() + 1)
          break
        case 'quarter':
          date.setMonth(date.getMonth() + 3)
          break
        case 'year':
          date.setFullYear(date.getFullYear() + 1)
          break
      }
      
      newStartDate = date.toISOString().split('T')[0]
    } else {
      // Default to current date
      const date = new Date()
      newStartDate = date.toISOString().split('T')[0]
    }
    
    if (newStartDate) {
      url.searchParams.set('start_date', newStartDate)
      Turbo.visit(url.toString())
    }
  }

  // Navigate to today
  today() {
    const url = new URL(window.location)
    const today = new Date()
    const viewMode = url.searchParams.get('view_mode') || 'quarter'
    
    // Calculate start date based on view mode
    let startDate
    switch(viewMode) {
      case 'month':
        startDate = new Date(today.getFullYear(), today.getMonth(), 1)
        break
      case 'quarter':
        const quarter = Math.floor(today.getMonth() / 3)
        startDate = new Date(today.getFullYear(), quarter * 3, 1)
        break
      case 'year':
        startDate = new Date(today.getFullYear(), 0, 1)
        break
    }
    
    url.searchParams.set('start_date', startDate.toISOString().split('T')[0])
    Turbo.visit(url.toString())
  }

  // Setup tooltips for milestones
  setupTooltips() {
    const milestones = this.element.querySelectorAll('.milestone-bar')
    
    milestones.forEach(milestone => {
      milestone.addEventListener('mouseenter', (e) => {
        // Could integrate with a tooltip library here
        console.log('Hovering milestone:', milestone.dataset.milestoneId)
      })
    })
  }

  // Setup drag and drop for milestones (for reordering or date adjustment)
  setupDragAndDrop() {
    const milestones = this.element.querySelectorAll('.milestone-bar')
    
    milestones.forEach(milestone => {
      milestone.addEventListener('dragstart', (e) => {
        e.dataTransfer.effectAllowed = 'move'
        e.dataTransfer.setData('milestoneId', milestone.dataset.milestoneId)
        milestone.classList.add('opacity-50')
      })
      
      milestone.addEventListener('dragend', (e) => {
        milestone.classList.remove('opacity-50')
      })
    })
    
    // Setup drop zones if needed
    const timelineGrid = this.element.querySelector('.timeline-grid')
    if (timelineGrid) {
      timelineGrid.addEventListener('dragover', (e) => {
        e.preventDefault()
        e.dataTransfer.dropEffect = 'move'
      })
      
      timelineGrid.addEventListener('drop', (e) => {
        e.preventDefault()
        const milestoneId = e.dataTransfer.getData('milestoneId')
        
        // Calculate new date based on drop position
        const rect = timelineGrid.getBoundingClientRect()
        const x = e.clientX - rect.left
        const percentage = (x / rect.width) * 100
        
        console.log(`Dropped milestone ${milestoneId} at ${percentage}% position`)
        // Would send update to server here
      })
    }
  }

  // Zoom in/out functionality
  zoomIn() {
    const currentViewMode = this.element.dataset.viewMode || 'quarter'
    const zoomOrder = ['year', 'quarter', 'month']
    const currentIndex = zoomOrder.indexOf(currentViewMode)
    
    if (currentIndex < zoomOrder.length - 1) {
      const newViewMode = zoomOrder[currentIndex + 1]
      this.changeViewMode(newViewMode)
    }
  }

  zoomOut() {
    const currentViewMode = this.element.dataset.viewMode || 'quarter'
    const zoomOrder = ['year', 'quarter', 'month']
    const currentIndex = zoomOrder.indexOf(currentViewMode)
    
    if (currentIndex > 0) {
      const newViewMode = zoomOrder[currentIndex - 1]
      this.changeViewMode(newViewMode)
    }
  }

  changeViewMode(viewMode) {
    const url = new URL(window.location)
    url.searchParams.set('view_mode', viewMode)
    Turbo.visit(url.toString())
  }

  // Export timeline as image
  exportTimeline() {
    // Would implement export functionality here
    console.log('Exporting timeline...')
  }

  // Filter milestones
  filterByStatus(event) {
    const status = event.target.value
    const milestones = this.element.querySelectorAll('.milestone-row')
    
    milestones.forEach(milestone => {
      const milestoneStatus = milestone.dataset.status
      if (status === '' || milestoneStatus === status) {
        milestone.style.display = ''
      } else {
        milestone.style.display = 'none'
      }
    })
  }

  // Expand/collapse sprint details
  toggleSprints(event) {
    const milestoneRow = event.currentTarget.closest('.milestone-row')
    const sprintsContainer = milestoneRow.querySelector('.sprints-container')
    
    if (sprintsContainer) {
      sprintsContainer.classList.toggle('hidden')
      event.currentTarget.classList.toggle('rotate-90')
    }
  }
}