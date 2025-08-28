// e2e 테스트용 도메인 헬퍼
export class DomainHelper {
  private static baseDomain: string = process.env.BASE_DOMAIN || 'creatia.local';
  private static port: string = process.env.PORT || '3000';

  /**
   * 기본 도메인을 반환 (환경변수 또는 기본값)
   */
  static getBaseDomain(): string {
    return this.baseDomain;
  }

  /**
   * 포트가 포함된 전체 도메인 반환
   */
  static getFullDomain(): string {
    return `${this.baseDomain}:${this.port}`;
  }

  /**
   * 서브도메인 URL 생성
   */
  static getSubdomainUrl(subdomain: string, path: string = ''): string {
    const url = `http://${subdomain}.${this.getFullDomain()}`;
    return path ? `${url}/${path}` : url;
  }

  /**
   * 메인 도메인 URL 생성
   */
  static getMainUrl(path: string = ''): string {
    const url = `http://${this.getFullDomain()}`;
    return path ? `${url}/${path}` : url;
  }

  /**
   * auth 서브도메인 URL
   */
  static getAuthUrl(path: string = ''): string {
    return this.getSubdomainUrl('auth', path);
  }

  /**
   * api 서브도메인 URL
   */
  static getApiUrl(path: string = ''): string {
    return this.getSubdomainUrl('api', path);
  }

  /**
   * admin 서브도메인 URL
   */
  static getAdminUrl(path: string = ''): string {
    return this.getSubdomainUrl('admin', path);
  }

  /**
   * 조직 도메인 URL
   */
  static getOrganizationUrl(orgSubdomain: string, path: string = ''): string {
    return this.getSubdomainUrl(orgSubdomain, path);
  }

  /**
   * 테스트용 이메일 생성 (기본 도메인 사용)
   */
  static getTestEmail(username: string): string {
    return `${username}@${this.baseDomain}`;
  }

  /**
   * URL 매칭용 정규식 생성
   */
  static getUrlPattern(subdomain: string, path?: string): RegExp {
    const domainPattern = `${subdomain}\\.${this.baseDomain.replace('.', '\\.')}`;
    if (path) {
      return new RegExp(`${domainPattern}.*${path}`);
    }
    return new RegExp(domainPattern);
  }
}