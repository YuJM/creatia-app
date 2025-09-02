import { Controller } from "@hotwired/stimulus"
import { patch } from "@rails/request.js"

export default class extends Controller {
  static targets = ["columns", "dropzone", "dropIndicator"]
  
  connect() {
    console.log("Sprint board controller connected")
    this.draggedElement = null
    this.setupDropZones()
  }

  setupDropZones() {
    this.dropzoneTargets.forEach(zone => {
      zone.addEventListener('dragover', this.handleDragOver.bind(this))
      zone.addEventListener('drop', this.handleDrop.bind(this))
      zone.addEventListener('dragleave', this.handleDragLeave.bind(this))
    })
  }

  // Drag start - store the dragged element
  dragStart(event) {
    this.draggedElement = event.currentTarget
    const taskId = event.currentTarget.dataset.taskId
    
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', taskId)
    
    // Add visual feedback
    event.currentTarget.classList.add('opacity-50')
    
    // Show drop indicators
    this.showDropIndicators()
  }

  // Drag end - cleanup
  dragEnd(event) {
    event.currentTarget.classList.remove('opacity-50')
    this.hideDropIndicators()
    this.draggedElement = null
  }

  // Handle drag over drop zone
  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'
    
    const dropzone = event.currentTarget
    const afterElement = this.getDragAfterElement(dropzone, event.clientY)
    
    if (this.draggedElement && dropzone !== this.draggedElement.parentElement) {
      dropzone.classList.add('bg-blue-50')
    }
    
    // Show where the card will be inserted
    if (this.draggedElement && afterElement == null) {
      dropzone.appendChild(this.draggedElement)
    } else if (this.draggedElement && afterElement) {
      dropzone.insertBefore(this.draggedElement, afterElement)
    }
  }

  // Handle drop
  async handleDrop(event) {
    event.preventDefault()
    
    const dropzone = event.currentTarget
    const taskId = event.dataTransfer.getData('text/plain')
    const newStatus = dropzone.dataset.status
    const sprintId = this.element.dataset.sprintId
    
    dropzone.classList.remove('bg-blue-50')
    
    // Update task status on server
    try {
      const response = await patch(`/sprints/${sprintId}/tasks/${taskId}/update_status`, {
        body: JSON.stringify({ status: newStatus }),
        responseKind: "turbo-stream"
      })
      
      if (response.ok) {
        console.log(`Task ${taskId} moved to ${newStatus}`)
      } else {
        console.error('Failed to update task status')
        // Revert the visual change if server update fails
        window.location.reload()
      }
    } catch (error) {
      console.error('Error updating task status:', error)
      window.location.reload()
    }
    
    this.hideDropIndicators()
  }

  // Handle drag leave
  handleDragLeave(event) {
    if (event.currentTarget === event.target) {
      event.currentTarget.classList.remove('bg-blue-50')
    }
  }

  // Get the element after which the dragged element should be inserted
  getDragAfterElement(container, y) {
    const draggableElements = [...container.querySelectorAll('.task-card:not(.opacity-50)')]
    
    return draggableElements.reduce((closest, child) => {
      const box = child.getBoundingClientRect()
      const offset = y - box.top - box.height / 2
      
      if (offset < 0 && offset > closest.offset) {
        return { offset: offset, element: child }
      } else {
        return closest
      }
    }, { offset: Number.NEGATIVE_INFINITY }).element
  }

  // Show drop indicators
  showDropIndicators() {
    this.dropIndicatorTargets.forEach(indicator => {
      indicator.classList.remove('hidden')
    })
  }

  // Hide drop indicators
  hideDropIndicators() {
    this.dropIndicatorTargets.forEach(indicator => {
      indicator.classList.add('hidden')
    })
    
    this.dropzoneTargets.forEach(zone => {
      zone.classList.remove('bg-blue-50')
    })
  }

  // Filter tasks by assignee
  filterByAssignee(event) {
    const assigneeId = event.target.value
    const tasks = this.element.querySelectorAll('.task-card')
    
    tasks.forEach(task => {
      if (assigneeId === '' || task.dataset.assigneeId === assigneeId) {
        task.style.display = ''
      } else {
        task.style.display = 'none'
      }
    })
  }

  // Filter tasks by priority
  filterByPriority(event) {
    const priority = event.target.value
    const tasks = this.element.querySelectorAll('.task-card')
    
    tasks.forEach(task => {
      if (priority === '' || task.dataset.priority === priority) {
        task.style.display = ''
      } else {
        task.style.display = 'none'
      }
    })
  }

  // Quick edit task
  quickEdit(event) {
    event.preventDefault()
    const taskCard = event.currentTarget.closest('.task-card')
    const taskId = taskCard.dataset.taskId
    
    // Open edit modal or inline edit
    console.log('Quick edit task:', taskId)
  }

  // Expand/collapse columns
  toggleColumn(event) {
    const column = event.currentTarget.closest('.sprint-column')
    const body = column.querySelector('[data-sprint-board-target="dropzone"]')
    
    if (body) {
      body.classList.toggle('hidden')
      event.currentTarget.classList.toggle('rotate-180')
    }
  }

  // Update sprint capacity
  async updateCapacity(event) {
    const sprintId = this.element.dataset.sprintId
    const newCapacity = event.target.value
    
    try {
      const response = await patch(`/sprints/${sprintId}`, {
        body: JSON.stringify({ sprint: { team_capacity: newCapacity } }),
        responseKind: "turbo-stream"
      })
      
      if (response.ok) {
        console.log('Sprint capacity updated')
      }
    } catch (error) {
      console.error('Error updating capacity:', error)
    }
  }

  // Refresh board
  refreshBoard() {
    Turbo.visit(window.location.href)
  }
}