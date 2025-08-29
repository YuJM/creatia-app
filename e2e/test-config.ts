/**
 * E2E 테스트 환경 설정
 */
export const testConfig = {
  // 기본 도메인
  baseDomain: process.env.BASE_DOMAIN || 'creatia.local',
  port: process.env.PORT || '3000',
  
  // 테스트 계정
  testUsers: {
    admin: {
      email: 'admin@creatia.local',
      password: 'password123'
    },
    demo: {
      email: 'demo@creatia.local',
      password: 'password123'
    }
  },
  
  // 테스트용 조직/서브도메인
  testOrganizations: {
    demo: {
      subdomain: 'demo',
      name: 'Demo Organization'
    },
    test: {
      subdomain: 'test',
      name: 'Test Organization'
    }
  },
  
  // URL 생성 헬퍼
  urls: {
    auth: (path = '') => `http://auth.creatia.local:3000${path ? '/' + path : ''}`,
    organization: (subdomain: string, path = '') => `http://${subdomain}.creatia.local:3000${path ? '/' + path : ''}`,
    main: (path = '') => `http://creatia.local:3000${path ? '/' + path : ''}`
  },
  
  // Devise 경로
  devisePaths: {
    login: '/login',
    logout: '/logout',
    register: '/register',
    organizationSelection: '/organization_selection',
    switchOrganization: '/switch_to_organization'
  },
  
  // 폼 필드 이름 (Devise 기본값)
  formFields: {
    email: 'user[email]',
    password: 'user[password]',
    rememberMe: 'user[remember_me]'
  },
  
  // 타임아웃 설정
  timeouts: {
    navigation: 30000,
    action: 10000,
    waitForUrl: 10000
  }
};