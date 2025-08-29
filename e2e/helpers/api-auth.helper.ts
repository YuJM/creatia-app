import { BrowserContext, APIRequestContext, Cookie } from '@playwright/test';

/**
 * API 기반 직접 인증 헬퍼
 * JWT 토큰을 API를 통해 직접 획득하여 빠른 인증 처리
 */
export class ApiAuthHelper {
  /**
   * API를 통한 직접 로그인
   * CSRF 토큰 없이 직접 API 엔드포인트 호출
   */
  static async loginViaAPI(
    context: BrowserContext,
    email: string = 'admin@creatia.local',
    password: string = 'password123'
  ): Promise<{ cookies: Cookie[], token?: string }> {
    const apiContext = context.request;
    
    try {
      // API 로그인 엔드포인트 호출
      const response = await apiContext.post('http://api.creatia.local:3000/v1/auth/login', {
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        data: {
          user: {
            email: email,
            password: password
          }
        }
      });
      
      // 응답 확인
      if (!response.ok()) {
        const body = await response.text();
        throw new Error(`API login failed: ${response.status()} - ${body}`);
      }
      
      const responseData = await response.json();
      
      // 쿠키 추출
      const cookies = await context.cookies();
      
      // JWT 토큰 확인
      const jwtAccessToken = cookies.find(c => c.name === 'jwt_access_token');
      const jwtRefreshToken = cookies.find(c => c.name === 'jwt_refresh_token');
      
      if (!jwtAccessToken || !jwtRefreshToken) {
        console.warn('JWT tokens not found in cookies after API login');
      }
      
      return {
        cookies,
        token: jwtAccessToken?.value
      };
    } catch (error) {
      console.error('API login error:', error);
      throw error;
    }
  }
  
  /**
   * JWT 토큰을 직접 생성하여 쿠키에 설정
   * 테스트용 빠른 인증 설정
   */
  static async setAuthCookies(
    context: BrowserContext,
    email: string = 'admin@creatia.local'
  ): Promise<void> {
    // 먼저 API 로그인으로 토큰 획득
    const { cookies } = await this.loginViaAPI(context, email);
    
    // JWT 쿠키를 .creatia.local 도메인으로 설정
    const authCookies = cookies
      .filter(c => c.name.includes('jwt') || c.name.includes('_creatia_session'))
      .map(cookie => ({
        ...cookie,
        domain: '.creatia.local',
        path: '/',
        httpOnly: true,
        sameSite: 'Lax' as const
      }));
    
    await context.addCookies(authCookies);
  }
  
  /**
   * 조직 전환 API 호출
   * 특정 조직으로 직접 전환
   */
  static async switchOrganizationViaAPI(
    apiContext: APIRequestContext,
    subdomain: string
  ): Promise<boolean> {
    try {
      const response = await apiContext.post('http://auth.creatia.local:3000/switch_to_organization', {
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        data: {
          subdomain: subdomain
        }
      });
      
      return response.ok();
    } catch (error) {
      console.error(`Failed to switch to organization ${subdomain}:`, error);
      return false;
    }
  }
  
  /**
   * 현재 사용자 정보 확인
   * API를 통해 인증 상태 검증
   */
  static async getCurrentUser(apiContext: APIRequestContext): Promise<any> {
    try {
      const response = await apiContext.get('http://api.creatia.local:3000/v1/auth/me', {
        headers: {
          'Accept': 'application/json'
        }
      });
      
      if (!response.ok()) {
        return null;
      }
      
      return await response.json();
    } catch (error) {
      console.error('Failed to get current user:', error);
      return null;
    }
  }
  
  /**
   * 로그아웃 API 호출
   */
  static async logoutViaAPI(apiContext: APIRequestContext): Promise<void> {
    try {
      await apiContext.post('http://api.creatia.local:3000/v1/auth/logout', {
        headers: {
          'Accept': 'application/json'
        }
      });
    } catch (error) {
      console.error('Logout failed:', error);
    }
  }
}