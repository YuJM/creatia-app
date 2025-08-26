require 'rails_helper'

RSpec.describe PagesController, type: :controller do
  describe "GET #home" do
    it "성공적으로 응답을 반환한다" do
      get :home
      expect(response).to be_successful
    end

    it "200 상태 코드를 반환한다" do
      get :home
      expect(response).to have_http_status(:ok)
    end

    it "home 템플릿을 렌더링한다" do
      get :home
      expect(response).to render_template(:home)
    end
  end
end