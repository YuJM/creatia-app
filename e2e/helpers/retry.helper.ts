import { Page } from '@playwright/test';

/**
 * 재시도 로직을 제공하는 헬퍼 클래스
 * 네트워크 불안정성을 처리하기 위한 유틸리티
 */
export class RetryHelper {
  /**
   * 지정된 함수를 재시도하며 실행
   * @param fn 실행할 함수
   * @param maxRetries 최대 재시도 횟수
   * @param delay 재시도 간 지연 시간 (ms)
   * @returns 함수 실행 결과
   */
  static async withRetry<T>(
    fn: () => Promise<T>,
    maxRetries: number = 3,
    delay: number = 1000
  ): Promise<T> {
    let lastError: Error | undefined;
    
    for (let i = 0; i <= maxRetries; i++) {
      try {
        return await fn();
      } catch (error) {
        lastError = error as Error;
        
        if (i < maxRetries) {
          console.log(`Attempt ${i + 1} failed, retrying in ${delay}ms...`);
          await this.sleep(delay);
          // 지수 백오프: 재시도마다 지연 시간 증가
          delay = Math.min(delay * 2, 10000);
        }
      }
    }
    
    throw lastError || new Error('Max retries exceeded');
  }
  
  /**
   * 페이지 네비게이션을 재시도하며 실행
   * @param page Playwright 페이지 객체
   * @param url 이동할 URL
   * @param options 네비게이션 옵션
   */
  static async navigateWithRetry(
    page: Page,
    url: string,
    options: {
      waitUntil?: 'load' | 'domcontentloaded' | 'networkidle';
      timeout?: number;
      maxRetries?: number;
    } = {}
  ): Promise<void> {
    const { waitUntil = 'networkidle', timeout = 30000, maxRetries = 3 } = options;
    
    await this.withRetry(
      async () => {
        await page.goto(url, { waitUntil, timeout });
      },
      maxRetries,
      2000
    );
  }
  
  /**
   * 요소가 나타날 때까지 재시도하며 대기
   * @param page Playwright 페이지 객체
   * @param selector 대기할 요소의 선택자
   * @param options 대기 옵션
   */
  static async waitForSelectorWithRetry(
    page: Page,
    selector: string,
    options: {
      timeout?: number;
      state?: 'attached' | 'detached' | 'visible' | 'hidden';
      maxRetries?: number;
    } = {}
  ): Promise<void> {
    const { timeout = 10000, state = 'visible', maxRetries = 3 } = options;
    
    await this.withRetry(
      async () => {
        await page.waitForSelector(selector, { timeout, state });
      },
      maxRetries,
      1000
    );
  }
  
  /**
   * 네트워크 요청을 재시도하며 실행
   * @param requestFn 네트워크 요청 함수
   * @param validateFn 응답 검증 함수
   * @param maxRetries 최대 재시도 횟수
   */
  static async networkRequestWithRetry<T>(
    requestFn: () => Promise<T>,
    validateFn?: (response: T) => boolean,
    maxRetries: number = 3
  ): Promise<T> {
    return await this.withRetry(
      async () => {
        const response = await requestFn();
        
        if (validateFn && !validateFn(response)) {
          throw new Error('Response validation failed');
        }
        
        return response;
      },
      maxRetries,
      1500
    );
  }
  
  /**
   * 조건이 충족될 때까지 재시도
   * @param conditionFn 조건 확인 함수
   * @param timeout 최대 대기 시간 (ms)
   * @param interval 확인 간격 (ms)
   */
  static async waitForCondition(
    conditionFn: () => Promise<boolean>,
    timeout: number = 30000,
    interval: number = 500
  ): Promise<void> {
    const startTime = Date.now();
    
    while (Date.now() - startTime < timeout) {
      if (await conditionFn()) {
        return;
      }
      await this.sleep(interval);
    }
    
    throw new Error(`Condition not met within ${timeout}ms`);
  }
  
  /**
   * 안정적인 요소 클릭 (재시도 포함)
   * @param page Playwright 페이지 객체
   * @param selector 클릭할 요소의 선택자
   * @param maxRetries 최대 재시도 횟수
   */
  static async clickWithRetry(
    page: Page,
    selector: string,
    maxRetries: number = 3
  ): Promise<void> {
    await this.withRetry(
      async () => {
        // 요소가 클릭 가능한 상태가 될 때까지 대기
        await page.waitForSelector(selector, { state: 'visible', timeout: 5000 });
        
        // 요소가 안정화되도록 짧은 대기
        await this.sleep(100);
        
        // 클릭 시도
        await page.click(selector);
      },
      maxRetries,
      1000
    );
  }
  
  /**
   * 텍스트 입력을 재시도하며 실행
   * @param page Playwright 페이지 객체
   * @param selector 입력 필드 선택자
   * @param text 입력할 텍스트
   * @param maxRetries 최대 재시도 횟수
   */
  static async fillWithRetry(
    page: Page,
    selector: string,
    text: string,
    maxRetries: number = 3
  ): Promise<void> {
    await this.withRetry(
      async () => {
        await page.waitForSelector(selector, { state: 'visible', timeout: 5000 });
        await page.fill(selector, text);
        
        // 입력이 제대로 되었는지 확인
        const value = await page.inputValue(selector);
        if (value !== text) {
          throw new Error(`Input value mismatch. Expected: ${text}, Got: ${value}`);
        }
      },
      maxRetries,
      500
    );
  }
  
  /**
   * 지정된 시간만큼 대기
   * @param ms 대기 시간 (밀리초)
   */
  private static sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
  
  /**
   * 네트워크가 안정될 때까지 대기
   * @param page Playwright 페이지 객체
   * @param timeout 최대 대기 시간
   */
  static async waitForNetworkIdle(
    page: Page,
    timeout: number = 10000
  ): Promise<void> {
    try {
      await page.waitForLoadState('networkidle', { timeout });
    } catch (error) {
      console.warn('Network did not become idle within timeout, continuing...');
    }
  }
  
  /**
   * 페이지 리로드를 재시도하며 실행
   * @param page Playwright 페이지 객체
   * @param maxRetries 최대 재시도 횟수
   */
  static async reloadWithRetry(
    page: Page,
    maxRetries: number = 3
  ): Promise<void> {
    await this.withRetry(
      async () => {
        await page.reload({ waitUntil: 'networkidle', timeout: 30000 });
      },
      maxRetries,
      2000
    );
  }
}