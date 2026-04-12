class GoogleDriveSettingsController < ApplicationController
  OAUTH_STATE_PURPOSE = :google_drive_oauth

  def show
  end

  def update
    if current_user.update(google_drive_settings_params)
      redirect_to google_drive_settings_path, notice: "Preferencias de Google Drive guardadas."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def authorize
    unless google_oauth_configured?
      redirect_to google_drive_settings_path, alert: "Falta configurar Google OAuth en la aplicación (credentials / variables de entorno)."
      return
    end

    state = oauth_verifier.generate({ "uid" => current_user.id }, expires_in: 15.minutes, purpose: OAUTH_STATE_PURPOSE)
    url   = GoogleDrive::OauthFlow.authorization_url(
      redirect_uri: callback_google_drive_settings_url,
      state:        state
    )
    redirect_to url, allow_other_host: true
  rescue GoogleDrive::Error => e
    redirect_to google_drive_settings_path, alert: e.message
  end

  def callback
    if params[:error].present?
      redirect_to google_drive_settings_path, alert: "No se conectó Google Drive (#{params[:error_description].presence || params[:error]})."
      return
    end

    if params[:state].blank?
      redirect_to google_drive_settings_path, alert: "Respuesta de Google incompleta. Inténtalo de nuevo."
      return
    end

    payload = oauth_verifier.verify(params[:state], purpose: OAUTH_STATE_PURPOSE)
    unless payload["uid"].to_i == current_user.id
      redirect_to google_drive_settings_path, alert: "Sesión no válida para completar la conexión. Inténtalo de nuevo."
      return
    end

    refresh = GoogleDrive::OauthFlow.exchange_code_for_refresh_token(
      code:         params[:code],
      redirect_uri: callback_google_drive_settings_url
    )

    current_user.update!(
      google_drive_refresh_token: refresh,
      google_drive_sync_enabled:  true
    )
    redirect_to google_drive_settings_path, notice: "Google Drive conectado. Las facturas recibidas nuevas se copiarán en tu carpeta."
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to google_drive_settings_path, alert: "El enlace de autorización ha caducado. Vuelve a pulsar «Conectar con Google»."
  rescue GoogleDrive::Error => e
    redirect_to google_drive_settings_path, alert: e.message
  end

  def disconnect
    current_user.update!(
      google_drive_refresh_token: nil,
      google_drive_sync_enabled:  false
    )
    redirect_to google_drive_settings_path, notice: "Google Drive desconectado."
  end

  private

  def google_oauth_configured?
    h = GoogleDrive::OauthCredentials.to_h
    h[:client_id].present? && h[:client_secret].present?
  end

  def oauth_verifier
    Rails.application.message_verifier("google_drive_oauth")
  end

  def google_drive_settings_params
    params.require(:user).permit(
      :google_drive_sync_enabled,
      :google_drive_folder_name,
      :google_drive_received_folder_name
    )
  end
end
