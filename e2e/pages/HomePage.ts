import { Page, Locator } from '@playwright/test';

/**
 * 홈페이지 Page Object Model
 * 페이지의 요소와 액션을 캡슐화
 */
export class HomePage {
  readonly page: Page;
  readonly mainContainer: Locator;
  readonly heading: Locator;
  readonly paragraph: Locator;

  constructor(page: Page) {
    this.page = page;
    this.mainContainer = page.locator('main.container');
    this.heading = page.locator('h1');
    this.paragraph = page.locator('p');
  }

  /**
   * 홈페이지로 이동
   */
  async goto() {
    await this.page.goto('/pages/home');
  }

  /**
   * 페이지가 로드될 때까지 대기
   */
  async waitForPageLoad() {
    await this.mainContainer.waitFor({ state: 'visible' });
  }

  /**
   * 제목 텍스트 가져오기
   */
  async getHeadingText(): Promise<string> {
    return await this.heading.textContent() || '';
  }

  /**
   * 단락 텍스트 가져오기
   */
  async getParagraphText(): Promise<string> {
    return await this.paragraph.textContent() || '';
  }

  /**
   * 특정 텍스트가 포함된 요소 찾기
   */
  async findElementByText(text: string): Promise<Locator> {
    return this.page.locator(`text=${text}`);
  }

  /**
   * 스크린샷 촬영
   */
  async takeScreenshot(name: string) {
    await this.page.screenshot({ 
      path: `e2e/screenshots/${name}.png`,
      fullPage: true 
    });
  }
}