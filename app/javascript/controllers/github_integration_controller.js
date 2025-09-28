import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "container",
    "enableCheckbox", 
    "branchPreview", 
    "branchName"
  ]
  
  static values = { 
    repository: String,
    enabled: Boolean 
  }
  
  connect() {
    console.log("GitHub integration controller connected")
    this.updateBranchName()
  }
  
  toggleBranchPreview() {
    const isChecked = this.enableCheckboxTarget.checked
    
    if (isChecked) {
      this.branchPreviewTarget.classList.remove('hidden')
      this.updateBranchName()
    } else {
      this.branchPreviewTarget.classList.add('hidden')
    }
  }
  
  updateBranchName() {
    if (!this.hasBranchNameTarget) return
    
    const titleField = document.querySelector('[data-task-form-target="titleField"]')
    const title = titleField ? titleField.value.trim() : ''
    
    // 브랜치명 생성 로직
    let branchName = this.generateBranchName(title)
    this.branchNameTarget.textContent = branchName
  }
  
  generateBranchName(title) {
    if (!title) {
      return 'feature/TASK-XXX-new-task'
    }
    
    // 한글과 특수문자를 영문으로 변환하고 정리
    let sanitized = title
      .toLowerCase()
      .replace(/[가-힣]/g, match => this.koreanToEnglish(match))
      .replace(/[^a-z0-9\s-]/g, '') // 영문, 숫자, 공백, 하이픈만 유지
      .replace(/\s+/g, '-') // 공백을 하이픈으로 변환
      .replace(/-+/g, '-') // 연속된 하이픈 정리
      .replace(/^-|-$/g, '') // 시작/끝의 하이픈 제거
      .slice(0, 50) // 최대 50글자로 제한
    
    // 빈 문자열인 경우 기본값
    if (!sanitized) {
      sanitized = 'new-task'
    }
    
    return `feature/TASK-XXX-${sanitized}`
  }
  
  // 간단한 한글 → 영문 변환 (주요 단어들)
  koreanToEnglish(korean) {
    const koreanMap = {
      '로그인': 'login',
      '회원가입': 'signup',
      '페이지': 'page',
      '버튼': 'button',
      '폼': 'form',
      '디자인': 'design',
      '개선': 'improve',
      '수정': 'fix',
      '추가': 'add',
      '삭제': 'delete',
      '생성': 'create',
      '업데이트': 'update',
      '기능': 'feature',
      '구현': 'implement',
      '테스트': 'test',
      '버그': 'bug',
      '오류': 'error',
      '성능': 'performance',
      '최적화': 'optimize',
      '보안': 'security',
      '인증': 'auth',
      '권한': 'permission',
      '관리': 'manage',
      '설정': 'config',
      '메뉴': 'menu',
      '검색': 'search',
      '필터': 'filter',
      '정렬': 'sort',
      '목록': 'list',
      '상세': 'detail',
      '프로필': 'profile',
      '대시보드': 'dashboard',
      '통계': 'stats',
      '리포트': 'report',
      '알림': 'notification',
      '메시지': 'message',
      '이메일': 'email',
      '파일': 'file',
      '이미지': 'image',
      '업로드': 'upload',
      '다운로드': 'download',
      '공유': 'share',
      '내보내기': 'export',
      '가져오기': 'import'
    }
    
    return koreanMap[korean] || korean
  }
  
  // 브랜치명 유효성 검사
  validateBranchName(branchName) {
    // Git 브랜치명 규칙
    const validPattern = /^[a-zA-Z0-9._\-\/]+$/
    const invalidPatterns = [
      /^\./,      // 점으로 시작 불가
      /\.$/,      // 점으로 끝 불가
      /\.\./,     // 연속된 점 불가
      /@\{/,      // @{ 불가
      /\s/,       // 공백 불가
      /~|\^|:/,   // 특수문자 불가
      /\[|\]/,    // 대괄호 불가
    ]
    
    if (!validPattern.test(branchName)) {
      return false
    }
    
    for (let pattern of invalidPatterns) {
      if (pattern.test(branchName)) {
        return false
      }
    }
    
    return branchName.length <= 100 // 길이 제한
  }
  
  // 브랜치 생성 상태 표시
  showBranchCreationStatus(status) {
    const container = this.containerTarget
    
    // 기존 상태 메시지 제거
    const existingStatus = container.querySelector('.branch-status')
    if (existingStatus) {
      existingStatus.remove()
    }
    
    let statusHtml = ''
    
    switch (status) {
      case 'creating':
        statusHtml = `
          <div class="branch-status mt-3 p-3 bg-blue-50 border border-blue-200 rounded">
            <div class="flex items-center">
              <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-blue-500" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <span class="text-sm text-blue-700">GitHub 브랜치를 생성하는 중...</span>
            </div>
          </div>
        `
        break
        
      case 'success':
        statusHtml = `
          <div class="branch-status mt-3 p-3 bg-green-50 border border-green-200 rounded">
            <div class="flex items-center">
              <svg class="mr-2 h-4 w-4 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
              </svg>
              <span class="text-sm text-green-700">GitHub 브랜치가 성공적으로 생성되었습니다!</span>
            </div>
          </div>
        `
        break
        
      case 'error':
        statusHtml = `
          <div class="branch-status mt-3 p-3 bg-red-50 border border-red-200 rounded">
            <div class="flex items-center">
              <svg class="mr-2 h-4 w-4 text-red-500" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
              </svg>
              <span class="text-sm text-red-700">브랜치 생성에 실패했습니다. 다시 시도해주세요.</span>
            </div>
          </div>
        `
        break
    }
    
    if (statusHtml) {
      container.insertAdjacentHTML('beforeend', statusHtml)
    }
  }
  
  // 브랜치 URL 표시
  showBranchUrl(branchUrl) {
    if (!this.hasBranchPreviewTarget) return
    
    const existingUrl = this.branchPreviewTarget.querySelector('.branch-url')
    if (existingUrl) {
      existingUrl.remove()
    }
    
    const urlHtml = `
      <div class="branch-url mt-2 p-2 bg-gray-50 rounded">
        <p class="text-xs text-gray-600 mb-1">브랜치 보기:</p>
        <a href="${branchUrl}" target="_blank" rel="noopener noreferrer" 
           class="text-xs text-blue-600 hover:text-blue-800 underline">
          ${branchUrl}
        </a>
      </div>
    `
    
    this.branchPreviewTarget.insertAdjacentHTML('beforeend', urlHtml)
  }
}