import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview"]

  connect() {
    this.tags = this.parseCurrentTags()
    this.updatePreview()
  }

  parseCurrentTags() {
    const input = this.element
    const value = input.value.trim()
    
    if (!value) return []
    
    return value.split(',').map(tag => tag.trim()).filter(tag => tag.length > 0)
  }

  handleKeydown(event) {
    if (event.key === 'Enter') {
      event.preventDefault()
      this.addTag()
    }
  }

  addTag() {
    const input = this.element
    const value = input.value.trim()
    
    if (!value) return
    
    // Check if value contains comma (multiple tags)
    const newTags = value.split(',').map(tag => tag.trim()).filter(tag => tag.length > 0)
    
    newTags.forEach(tag => {
      if (!this.tags.includes(tag)) {
        this.tags.push(tag)
      }
    })
    
    // Update input with all tags
    input.value = this.tags.join(', ')
    
    // Update preview
    this.updatePreview()
  }

  removeTag(event) {
    event.preventDefault()
    
    const tagElement = event.currentTarget.closest('.tag-item')
    const tagText = tagElement.dataset.tag
    
    this.tags = this.tags.filter(tag => tag !== tagText)
    
    // Update input
    this.element.value = this.tags.join(', ')
    
    // Update preview
    this.updatePreview()
  }

  updatePreview() {
    if (!this.hasPreviewTarget) return
    
    this.previewTarget.innerHTML = ''
    
    this.tags.forEach(tag => {
      const tagElement = document.createElement('span')
      tagElement.className = 'tag-item inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800 dark:bg-indigo-900/30 dark:text-indigo-400'
      tagElement.dataset.tag = tag
      
      tagElement.innerHTML = `
        ${tag}
        <button type="button" 
                class="ml-1 inline-flex items-center justify-center w-4 h-4 text-indigo-400 hover:text-indigo-600"
                data-action="click->tag-input#removeTag">
          <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
          </svg>
        </button>
      `
      
      this.previewTarget.appendChild(tagElement)
    })
  }
}