import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form", "title", "submitButton",
    "stakeholdersList", "stakeholderRow",
    "teamLeadsList", "teamLeadRow",
    "objectivesList", "objectiveRow"
  ]

  connect() {
    console.log("Milestone form controller connected")
    this.setupFormValidation()
  }

  setupFormValidation() {
    if (this.hasFormTarget) {
      this.formTarget.addEventListener('submit', (e) => {
        if (!this.validateForm()) {
          e.preventDefault()
        }
      })
    }
  }

  validateForm() {
    let isValid = true

    // Validate title
    if (this.hasTitleTarget && !this.titleTarget.value.trim()) {
      this.showError(this.titleTarget, "Title is required")
      isValid = false
    }

    // Validate dates
    const startDate = this.formTarget.querySelector('[name="milestone[planned_start]"]')
    const endDate = this.formTarget.querySelector('[name="milestone[planned_end]"]')
    
    if (startDate && endDate) {
      if (new Date(startDate.value) > new Date(endDate.value)) {
        this.showError(endDate, "End date must be after start date")
        isValid = false
      }
    }

    return isValid
  }

  showError(field, message) {
    field.classList.add('border-red-500')
    
    // Remove existing error message
    const existingError = field.parentElement.querySelector('.error-message')
    if (existingError) {
      existingError.remove()
    }
    
    // Add new error message
    const errorDiv = document.createElement('div')
    errorDiv.className = 'error-message text-red-500 text-sm mt-1'
    errorDiv.textContent = message
    field.parentElement.appendChild(errorDiv)
    
    // Remove error on input
    field.addEventListener('input', () => {
      field.classList.remove('border-red-500')
      const error = field.parentElement.querySelector('.error-message')
      if (error) error.remove()
    }, { once: true })
  }

  // Add stakeholder row
  addStakeholder(event) {
    event.preventDefault()
    
    const template = this.createStakeholderTemplate()
    this.stakeholdersListTarget.insertAdjacentHTML('beforeend', template)
  }

  createStakeholderTemplate() {
    return `
      <div class="flex gap-2" data-milestone-form-target="stakeholderRow">
        <select name="milestone[stakeholder_ids][]" 
                class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value="">Select stakeholder</option>
          ${this.getUserOptions()}
        </select>
        <input type="text" 
               name="milestone[stakeholder_roles][]" 
               placeholder="Role"
               class="w-32 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500">
        <button type="button" 
                data-action="click->milestone-form#removeStakeholder"
                class="px-3 py-2 text-red-600 hover:bg-red-50 rounded-md">
          Remove
        </button>
      </div>
    `
  }

  // Remove stakeholder row
  removeStakeholder(event) {
    event.preventDefault()
    const row = event.currentTarget.closest('[data-milestone-form-target="stakeholderRow"]')
    if (row) {
      row.remove()
    }
  }

  // Add team lead row
  addTeamLead(event) {
    event.preventDefault()
    
    const template = this.createTeamLeadTemplate()
    this.teamLeadsListTarget.insertAdjacentHTML('beforeend', template)
  }

  createTeamLeadTemplate() {
    return `
      <div class="flex gap-2" data-milestone-form-target="teamLeadRow">
        <select name="milestone[team_lead_ids][]" 
                class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value="">Select team lead</option>
          ${this.getUserOptions()}
        </select>
        <select name="milestone[team_ids][]" 
                class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value="">Select team</option>
          ${this.getTeamOptions()}
        </select>
        <button type="button" 
                data-action="click->milestone-form#removeTeamLead"
                class="px-3 py-2 text-red-600 hover:bg-red-50 rounded-md">
          Remove
        </button>
      </div>
    `
  }

  // Remove team lead row
  removeTeamLead(event) {
    event.preventDefault()
    const row = event.currentTarget.closest('[data-milestone-form-target="teamLeadRow"]')
    if (row) {
      row.remove()
    }
  }

  // Add objective row
  addObjective(event) {
    event.preventDefault()
    
    const template = this.createObjectiveTemplate()
    this.objectivesListTarget.insertAdjacentHTML('beforeend', template)
  }

  createObjectiveTemplate() {
    return `
      <div class="p-4 border border-gray-200 rounded-md" data-milestone-form-target="objectiveRow">
        <div class="grid grid-cols-1 gap-3">
          <input type="text" 
                 name="milestone[objectives][][title]" 
                 placeholder="Objective title"
                 class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500">
          <textarea name="milestone[objectives][][description]" 
                    rows="2"
                    placeholder="Objective description"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"></textarea>
          <button type="button" 
                  data-action="click->milestone-form#removeObjective"
                  class="text-red-600 hover:bg-red-50 rounded-md px-2 py-1 text-sm">
            Remove Objective
          </button>
        </div>
      </div>
    `
  }

  // Remove objective row
  removeObjective(event) {
    event.preventDefault()
    const row = event.currentTarget.closest('[data-milestone-form-target="objectiveRow"]')
    if (row) {
      row.remove()
    }
  }

  // Update owner snapshot
  updateOwner(event) {
    const userId = event.target.value
    console.log('Owner updated to:', userId)
    // Could update UI to show owner details
  }

  // Close modal
  close(event) {
    event.preventDefault()
    
    // If in a turbo frame, remove the frame
    const modal = this.element.closest('turbo-frame[id="modal"]')
    if (modal) {
      modal.innerHTML = ''
    }
    
    // Or navigate back
    if (window.history.length > 1) {
      window.history.back()
    } else {
      window.location.href = '/milestones'
    }
  }

  // Get user options (would be populated from data attributes or API)
  getUserOptions() {
    // This would normally be populated from the server
    return `
      <option value="1">John Doe</option>
      <option value="2">Jane Smith</option>
      <option value="3">Bob Johnson</option>
    `
  }

  // Get team options (would be populated from data attributes or API)
  getTeamOptions() {
    // This would normally be populated from the server
    return `
      <option value="1">Backend Team</option>
      <option value="2">Frontend Team</option>
      <option value="3">DevOps Team</option>
    `
  }
}