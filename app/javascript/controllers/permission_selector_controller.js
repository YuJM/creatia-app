import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox"]

  toggleResource(event) {
    event.preventDefault()
    const resource = event.currentTarget.dataset.resource
    const resourceCheckboxes = this.checkboxTargets.filter(
      checkbox => checkbox.dataset.resource === resource
    )
    
    const allChecked = resourceCheckboxes.every(checkbox => checkbox.checked)
    
    resourceCheckboxes.forEach(checkbox => {
      checkbox.checked = !allChecked
    })
  }

  selectPreset(event) {
    event.preventDefault()
    const preset = event.currentTarget.dataset.preset
    
    // 먼저 모든 체크박스 해제
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    
    // 프리셋에 따라 선택
    switch(preset) {
      case 'viewer':
        this.selectActions(['read'])
        break
      case 'member':
        this.selectActions(['read', 'create', 'update'])
        break
      case 'admin':
        this.selectActions(['read', 'create', 'update', 'manage'])
        break
    }
  }

  selectActions(actions) {
    this.checkboxTargets.forEach(checkbox => {
      if (actions.includes(checkbox.dataset.action)) {
        checkbox.checked = true
      }
    })
  }

  clearAll(event) {
    event.preventDefault()
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
  }

  connect() {
    console.log("Permission selector connected")
  }
}