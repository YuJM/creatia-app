import { Page, BrowserContext, Cookie } from '@playwright/test';

export class AuthHelper {
  /**
   * JWT 기반 크로스 도메인 인증
   * Rails 애플리케이션의 JWT 토큰을 사용하여 모든 서브도메인에서 인증 유지
   */
  static async loginWithSession(
    page: Page, 
    context: BrowserContext,
    email: string = 'admin@creatia.local'
  ): Promise<Cookie[]> {
    // auth 서브도메인의 로그인 페이지로 이동 (Rails 라우트에 맞게 수정)
    await page.goto('http://auth.creatia.local:3000/login');
    
    // 로그인 폼 제출 (AuthUser 네임스페이스 필드명 사용)
    await page.fill('input[name="auth_user_user[email]"]', email);
    await page.fill('input[name="auth_user_user[password]"]', 'password123');
    
    // 로그인 버튼 클릭 (다양한 형태 지원)
    const submitButton = page.locator('input[type="submit"][value="로그인"], button[type="submit"]:has-text("로그인")');
    await submitButton.first().click();
    
    // 로그인 성공 후 조직 선택 페이지 또는 대시보드로 이동 대기
    await page.waitForURL(url => {
      const urlString = typeof url === 'string' ? url : url.toString();
      return urlString.includes('/organization_selection') || 
             urlString.includes('/dashboard') ||
             (urlString.includes('.creatia.local') && !urlString.includes('/login'));
    }, { timeout: 10000 });
    
    // JWT 토큰을 포함한 모든 쿠키 저장
    // .creatia.local 도메인의 쿠키를 가져옴
    const cookies = await context.cookies();
    
    // JWT 토큰이 제대로 설정되었는지 확인
    const jwtAccessToken = cookies.find(c => c.name === 'jwt_access_token');
    const jwtRefreshToken = cookies.find(c => c.name === 'jwt_refresh_token');
    
    if (!jwtAccessToken || !jwtRefreshToken) {
      console.warn('JWT tokens not found in cookies. Authentication may not work across subdomains.');
    }
    
    return cookies;
  }
  
  /**
   * 저장된 쿠키로 세션 복원
   * JWT 토큰을 모든 서브도메인에서 사용할 수 있도록 설정
   */
  static async restoreSession(context: BrowserContext, cookies: Cookie[]) {
    // JWT 쿠키를 .creatia.local 도메인으로 설정하여 모든 서브도메인에서 사용 가능하게 함
    const updatedCookies = cookies.map(cookie => {
      if (cookie.name === 'jwt_access_token' || cookie.name === 'jwt_refresh_token') {
        return {
          ...cookie,
          domain: '.creatia.local',
          path: '/',
          httpOnly: true,
          sameSite: 'Lax' as const
        };
      }
      return cookie;
    });
    
    await context.addCookies(updatedCookies);
  }
  
  /**
   * 특정 조직으로 직접 이동
   * JWT 토큰이 설정되어 있으면 바로 접근 가능
   */
  static async switchToOrganization(page: Page, subdomain: string) {
    const targetUrl = `http://${subdomain}.creatia.local:3000/dashboard`;
    
    // 조직 페이지로 이동
    const response = await page.goto(targetUrl, { waitUntil: 'networkidle' });
    
    // 리다이렉트 확인
    const currentUrl = page.url();
    
    // 로그인 페이지로 리다이렉트되면 인증 실패
    if (currentUrl.includes('/login')) {
      throw new Error(`Authentication failed when accessing ${subdomain} organization`);
    }
    
    // 대시보드 또는 애플리케이션 레이아웃 대기 (유연하게 처리)
    try {
      await page.waitForSelector('#layout-application, [data-layout="application"], main', { 
        timeout: 5000 
      });
    } catch (error) {
      // 레이아웃이 없어도 URL이 맞으면 성공으로 간주
      if (!currentUrl.includes(subdomain)) {
        throw new Error(`Failed to navigate to ${subdomain} organization`);
      }
    }
  }
  
  /**
   * 현재 사용자가 로그인되어 있는지 확인
   */
  static async isLoggedIn(page: Page): Promise<boolean> {
    try {
      // 로그아웃 버튼이나 사용자 메뉴가 있는지 확인
      const logoutButton = await page.locator('a[href*="logout"], button:has-text("로그아웃")').count();
      return logoutButton > 0;
    } catch {
      return false;
    }
  }
  
  /**
   * 로그아웃
   */
  static async logout(page: Page) {
    const logoutLink = page.locator('a[href*="logout"], a[href*="sign_out"], button').filter({ 
      hasText: /로그아웃|Logout|Sign out/i 
    });
    
    if (await logoutLink.count() > 0) {
      await logoutLink.first().click();
      await page.waitForURL(url => {
        const urlString = typeof url === 'string' ? url : url.toString();
        return urlString.includes('login') || urlString.includes('sign_in') || urlString === 'http://creatia.local/';
      }, { timeout: 5000 });
    }
  }
  
  /**
   * API를 통한 직접 인증 (가장 빠른 방법)
   * API 엔드포인트를 사용하여 JWT 토큰 직접 획득
   */
  static async loginViaAPI(
    context: BrowserContext,
    email: string = 'admin@creatia.local',
    password: string = 'password123'
  ): Promise<Cookie[]> {
    // API 요청을 위한 임시 페이지 생성
    const page = await context.newPage();
    
    try {
      // CSRF 토큰 획득을 위해 먼저 로그인 페이지 방문
      await page.goto('http://auth.creatia.local:3000/login');
      
      // 로그인 API 호출 (AuthUser 네임스페이스 사용)
      const response = await page.request.post('http://auth.creatia.local:3000/users/sign_in', {
        data: {
          'auth_user_user[email]': email,
          'auth_user_user[password]': password,
          'auth_user_user[remember_me]': '1'
        },
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      });
      
      if (!response.ok()) {
        throw new Error(`Login failed: ${response.status()} ${response.statusText()}`);
      }
      
      // 응답에서 쿠키 추출
      const cookies = await context.cookies();
      
      // JWT 토큰 확인
      const hasJwtTokens = cookies.some(c => 
        c.name === 'jwt_access_token' || c.name === 'jwt_refresh_token'
      );
      
      if (!hasJwtTokens) {
        console.warn('JWT tokens not found after API login');
      }
      
      return cookies;
    } finally {
      await page.close();
    }
  }
  
  /**
   * 현재 인증 상태를 확인하고 필요시 재인증
   */
  static async ensureAuthenticated(
    page: Page,
    context: BrowserContext,
    email: string = 'admin@creatia.local'
  ): Promise<void> {
    // 현재 페이지가 로그인 페이지인지 확인
    const currentUrl = page.url();
    
    if (currentUrl.includes('/sign_in') || currentUrl.includes('/login')) {
      // 재인증 필요
      const cookies = await this.loginWithSession(page, context, email);
      await this.restoreSession(context, cookies);
    }
  }
}