class AiIntegrationsController < ApplicationController
  def show
    @user = current_user.reload
  end

  def update
    @user = current_user
    p = ai_integrations_params
    gem = p.delete(:gemini_api_key)
    groq_in = p.delete(:groq_api_key)
    rm_gem = ActiveModel::Type::Boolean.new.cast(p.delete(:remove_gemini_api_key))
    rm_groq = ActiveModel::Type::Boolean.new.cast(p.delete(:remove_groq_api_key))

    @user.encrypted_gemini_api_key = nil if rm_gem
    @user.encrypted_groq_api_key = nil if rm_groq
    @user.gemini_api_key = gem if gem.present?
    @user.groq_api_key = groq_in if groq_in.present?

    if @user.save
      redirect_to ai_integrations_path, notice: "Integraciones con IA guardadas."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def ai_integrations_params
    params.require(:user).permit(
      :gemini_api_key, :groq_api_key, :remove_gemini_api_key, :remove_groq_api_key
    )
  end
end
