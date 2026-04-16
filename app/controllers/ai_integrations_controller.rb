class AiIntegrationsController < ApplicationController
  def show
    @user = current_user.reload
  end

  # Comprueba la clave del campo (si viene rellena) o la guardada en cuenta.
  def check
    provider = check_params[:provider].to_s
    unless %w[gemini groq].include?(provider)
      render json: { ok: false, message: "Parámetro de proveedor no válido." }, status: :bad_request
      return
    end

    key = check_params[:api_key].presence || api_key_from_user(provider)
    result = AiIntegrationKeyChecker.call(provider: provider, api_key: key)

    status = result[:ok] ? :ok : :unprocessable_entity
    render json: { ok: result[:ok], message: result[:message] }, status: status
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

  def check_params
    params.permit(:provider, :api_key)
  end

  def api_key_from_user(provider)
    case provider
    when "gemini" then current_user.gemini_api_key
    when "groq" then current_user.groq_api_key
    end
  end

  def ai_integrations_params
    params.require(:user).permit(
      :gemini_api_key, :groq_api_key, :remove_gemini_api_key, :remove_groq_api_key
    )
  end
end
