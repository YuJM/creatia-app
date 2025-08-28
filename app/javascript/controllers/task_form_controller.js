import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "titleField",
    "priorityField", 
    "dueDateField",
    "assigneeField",
    "descriptionField",
    "submitButton",
    "validationMessage",
    "validationList",
    "loadingOverlay",
    "loadingMessage"
  ]
  
  connect() {
    console.log("Task form controller connected")
    this.setupValidation()
    this.setupAutoSave()
  }
  
  disconnect() {
    this.clearAutoSave()
  }
  
  // 실시간 검증 설정
  setupValidation() {
    if (this.hasTitleFieldTarget) {
      this.titleFieldTarget.addEventListener('input', () => {
        this.validateTitle()
        this.updateSubmitButtonState()
      })
    }
    
    if (this.hasPriorityFieldTarget) {
      this.priorityFieldTarget.addEventListener('change', () => {
        this.validatePriority()
        this.updateSubmitButtonState()
      })
    }
    
    if (this.hasDueDateFieldTarget) {
      this.dueDateFieldTarget.addEventListener('change', () => {
        this.validateDueDate()
        this.updateSubmitButtonState()
      })
    }
  }
  
  // 자동 저장 설정 (Draft 기능)
  setupAutoSave() {
    this.autoSaveTimer = null
    this.autoSaveKey = `task_draft_${Date.now()}`
    
    // 기존 드래프트 로드
    this.loadDraft()
    
    // 필드 변경 감지
    this.element.addEventListener('input', () => {
      this.scheduleAutoSave()
    })
    
    this.element.addEventListener('change', () => {
      this.scheduleAutoSave()
    })
  }
  
  scheduleAutoSave() {
    if (this.autoSaveTimer) {
      clearTimeout(this.autoSaveTimer)
    }
    
    this.autoSaveTimer = setTimeout(() => {
      this.saveDraft()
    }, 2000) // 2초 후 자동 저장
  }
  
  saveDraft() {
    const formData = this.getFormData()
    
    // 제목이 있는 경우에만 저장
    if (formData.title && formData.title.trim()) {
      localStorage.setItem(this.autoSaveKey, JSON.stringify({
        ...formData,
        savedAt: new Date().toISOString()
      }))
      
      this.showAutoSaveIndicator()
    }
  }
  
  loadDraft() {
    try {
      // 최근 드래프트들 확인
      const drafts = this.getRecentDrafts()
      
      if (drafts.length > 0) {
        const latestDraft = drafts[0]
        this.showDraftRestoreOption(latestDraft)
      }
    } catch (error) {
      console.error('Draft loading failed:', error)
    }
  }
  
  getRecentDrafts() {
    const drafts = []
    
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i)
      if (key && key.startsWith('task_draft_')) {
        try {
          const draft = JSON.parse(localStorage.getItem(key))
          if (draft && draft.title) {
            drafts.push({ key, ...draft })
          }
        } catch (error) {
          // 잘못된 형식의 드래프트 삭제
          localStorage.removeItem(key)
        }
      }
    }
    
    // 저장 시간 순 정렬
    return drafts.sort((a, b) => new Date(b.savedAt) - new Date(a.savedAt))
  }
  
  showDraftRestoreOption(draft) {
    const draftAge = Date.now() - new Date(draft.savedAt).getTime()
    const hoursAgo = Math.floor(draftAge / (1000 * 60 * 60))
    
    // 24시간 이내의 드래프트만 표시
    if (hoursAgo > 24) return
    
    const draftHtml = `
      <div class="draft-restore mb-4 p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3 flex-1">
            <h3 class="text-sm font-medium text-yellow-800">저장된 드래프트 발견</h3>
            <div class="mt-1 text-sm text-yellow-700">
              <p>"${draft.title}" - ${hoursAgo}시간 전 저장됨</p>
            </div>
            <div class="mt-3 flex space-x-2">
              <button type="button" 
                      class="bg-yellow-600 hover:bg-yellow-700 text-white text-xs px-3 py-1 rounded"
                      data-action="click->task-form#restoreDraft"
                      data-draft-key="${draft.key}">
                복원하기
              </button>
              <button type="button" 
                      class="bg-white hover:bg-gray-50 text-yellow-800 text-xs px-3 py-1 border border-yellow-300 rounded"
                      data-action="click->task-form#dismissDraft">
                무시하기
              </button>
            </div>
          </div>
        </div>
      </div>
    `
    
    this.element.insertAdjacentHTML('afterbegin', draftHtml)
  }
  
  restoreDraft(event) {
    const draftKey = event.target.dataset.draftKey
    
    try {
      const draftData = JSON.parse(localStorage.getItem(draftKey))
      
      if (draftData) {
        this.populateForm(draftData)
        this.dismissDraft(event)
        this.showToast('드래프트가 복원되었습니다', 'info')
      }
    } catch (error) {
      console.error('Draft restoration failed:', error)
      this.showToast('드래프트 복원에 실패했습니다', 'error')
    }
  }
  
  dismissDraft(event) {
    const draftRestore = event.target.closest('.draft-restore')
    if (draftRestore) {
      draftRestore.remove()
    }
  }
  
  populateForm(data) {
    if (this.hasTitleFieldTarget && data.title) {
      this.titleFieldTarget.value = data.title
    }
    
    if (this.hasPriorityFieldTarget && data.priority) {
      this.priorityFieldTarget.value = data.priority
    }
    
    if (this.hasDueDateFieldTarget && data.due_date) {
      this.dueDateFieldTarget.value = data.due_date
    }
    
    if (this.hasAssigneeFieldTarget && data.assigned_user_id) {
      this.assigneeFieldTarget.value = data.assigned_user_id
    }
    
    // Rich text area 복원은 복잡하므로 일단 스킵
    // if (this.hasDescriptionFieldTarget && data.description) {
    //   this.descriptionFieldTarget.value = data.description
    // }
  }
  
  getFormData() {
    return {
      title: this.hasTitleFieldTarget ? this.titleFieldTarget.value : '',
      priority: this.hasPriorityFieldTarget ? this.priorityFieldTarget.value : '',
      due_date: this.hasDueDateFieldTarget ? this.dueDateFieldTarget.value : '',
      assigned_user_id: this.hasAssigneeFieldTarget ? this.assigneeFieldTarget.value : '',
      description: this.hasDescriptionFieldTarget ? this.descriptionFieldTarget.value : ''
    }
  }
  
  clearAutoSave() {
    if (this.autoSaveTimer) {
      clearTimeout(this.autoSaveTimer)
    }
  }
  
  showAutoSaveIndicator() {
    // 기존 인디케이터 제거
    const existing = this.element.querySelector('.auto-save-indicator')
    if (existing) existing.remove()
    
    // 새 인디케이터 표시
    const indicator = document.createElement('div')
    indicator.className = 'auto-save-indicator fixed top-4 right-4 bg-green-600 text-white px-3 py-1 rounded shadow-lg text-sm z-50'
    indicator.textContent = '✓ 자동 저장됨'
    document.body.appendChild(indicator)
    
    // 2초 후 제거
    setTimeout(() => {
      indicator.remove()
    }, 2000)
  }
  
  // 폼 검증
  validateForm() {
    const errors = []
    
    if (!this.validateTitle()) {
      errors.push('작업 제목을 입력해주세요')
    }
    
    if (!this.validatePriority()) {
      errors.push('우선순위를 선택해주세요')
    }
    
    if (!this.validateDueDate()) {
      errors.push('올바른 마감일을 선택해주세요')
    }
    
    if (errors.length > 0) {
      this.showValidationErrors(errors)
      return false
    } else {
      this.hideValidationErrors()
      return true
    }
  }
  
  validateTitle() {
    if (!this.hasTitleFieldTarget) return true
    
    const title = this.titleFieldTarget.value.trim()
    const isValid = title.length >= 3 && title.length <= 200
    
    this.updateFieldValidation(this.titleFieldTarget, isValid)
    return isValid
  }
  
  validatePriority() {
    if (!this.hasPriorityFieldTarget) return true
    
    const priority = this.priorityFieldTarget.value
    const isValid = ['low', 'medium', 'high', 'urgent'].includes(priority)
    
    this.updateFieldValidation(this.priorityFieldTarget, isValid)
    return isValid
  }
  
  validateDueDate() {
    if (!this.hasDueDateFieldTarget) return true
    
    const dueDate = this.dueDateFieldTarget.value
    if (!dueDate) return true // 선택사항
    
    const selectedDate = new Date(dueDate)
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    
    const isValid = selectedDate >= today
    this.updateFieldValidation(this.dueDateFieldTarget, isValid)
    return isValid
  }
  
  updateFieldValidation(field, isValid) {
    if (isValid) {
      field.classList.remove('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
      field.classList.add('border-gray-300', 'focus:border-blue-500', 'focus:ring-blue-500')
    } else {
      field.classList.remove('border-gray-300', 'focus:border-blue-500', 'focus:ring-blue-500')
      field.classList.add('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
    }
  }
  
  showValidationErrors(errors) {
    if (!this.hasValidationMessageTarget || !this.hasValidationListTarget) return
    
    this.validationListTarget.innerHTML = ''
    errors.forEach(error => {
      const li = document.createElement('li')
      li.textContent = error
      this.validationListTarget.appendChild(li)
    })
    
    this.validationMessageTarget.classList.remove('hidden')
    
    // 오류 메시지로 스크롤
    this.validationMessageTarget.scrollIntoView({ 
      behavior: 'smooth', 
      block: 'center' 
    })
  }
  
  hideValidationErrors() {
    if (this.hasValidationMessageTarget) {
      this.validationMessageTarget.classList.add('hidden')
    }
  }
  
  updateSubmitButtonState() {
    if (!this.hasSubmitButtonTarget) return
    
    const isFormValid = this.validateTitle() && this.validatePriority() && this.validateDueDate()
    
    if (isFormValid) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
    } else {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add('opacity-50', 'cursor-not-allowed')
    }
  }
  
  // 폼 제출 처리
  handleSubmit(event) {
    console.log("Form submission handled by Turbo")
    
    // GitHub 연동이 활성화된 경우 특별 처리
    const githubCheckbox = document.getElementById('create_github_branch')
    if (githubCheckbox && githubCheckbox.checked) {
      this.handleGithubBranchCreation()
    }
    
    this.showLoading('작업을 생성하고 있습니다...')
    
    // 성공 시 드래프트 삭제
    this.clearDrafts()
  }
  
  handleGithubBranchCreation() {
    const githubController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller*="github-integration"]'), 
      'github-integration'
    )
    
    if (githubController) {
      githubController.showBranchCreationStatus('creating')
      this.updateLoadingMessage('GitHub 브랜치를 생성하고 있습니다...')
    }
  }
  
  showLoading(message = '처리 중...') {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.classList.remove('hidden')
    }
    
    if (this.hasLoadingMessageTarget) {
      this.loadingMessageTarget.textContent = message
    }
  }
  
  hideLoading() {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.classList.add('hidden')
    }
  }
  
  updateLoadingMessage(message) {
    if (this.hasLoadingMessageTarget) {
      this.loadingMessageTarget.textContent = message
    }
  }
  
  clearDrafts() {
    // 현재 드래프트 삭제
    if (this.autoSaveKey) {
      localStorage.removeItem(this.autoSaveKey)
    }
    
    // 오래된 드래프트들 정리 (7일 이상)
    const cutoff = Date.now() - (7 * 24 * 60 * 60 * 1000)
    
    for (let i = localStorage.length - 1; i >= 0; i--) {
      const key = localStorage.key(i)
      if (key && key.startsWith('task_draft_')) {
        try {
          const draft = JSON.parse(localStorage.getItem(key))
          if (draft && new Date(draft.savedAt).getTime() < cutoff) {
            localStorage.removeItem(key)
          }
        } catch (error) {
          localStorage.removeItem(key)
        }
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
}