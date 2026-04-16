# Comprueba claves API de Gemini y Groq con peticiones ligeras (listado de modelos).
class AiIntegrationKeyChecker
  GEMINI_MODELS_URL = "https://generativelanguage.googleapis.com/v1beta/models"
  GROQ_MODELS_URL   = "https://api.groq.com/openai/v1/models"

  def self.call(provider:, api_key:, faraday: nil)
    new(provider: provider, api_key: api_key, faraday: faraday).call
  end

  def initialize(provider:, api_key:, faraday: nil)
    @provider          = provider.to_s
    @api_key           = api_key.to_s.strip
    @faraday_injected  = faraday
  end

  def call
    return failure("Introduce una clave en el campo o guarda una antes de comprobar.") if @api_key.blank?

    case @provider
    when "gemini" then check_gemini
    when "groq" then check_groq
    else failure("Proveedor no válido.")
    end
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    failure("No se pudo conectar (#{e.class.name.demodulize}). Revisa tu red o inténtalo más tarde.")
  rescue Faraday::Error => e
    failure("Error de red: #{e.message}")
  end

  private

  def check_gemini
    r = http.get(GEMINI_MODELS_URL) do |req|
      req.headers["x-goog-api-key"] = @api_key
      req.params["pageSize"] = "1"
    end
    interpret_gemini(r)
  end

  def check_groq
    r = http.get(GROQ_MODELS_URL) do |req|
      req.headers["Authorization"] = "Bearer #{@api_key}"
    end
    interpret_groq(r)
  end

  def http
    return @faraday_injected if @faraday_injected

    @faraday ||= Faraday.new do |f|
      f.request :json
      f.response :json, content_type: /\bjson\b/
      f.options.timeout = 15
      f.options.open_timeout = 5
    end
  end

  def interpret_gemini(r)
    body = r.body.is_a?(Hash) ? r.body : {}

    case r.status
    when 200
      return failure("Respuesta inesperada de Google.") unless body["models"].is_a?(Array)

      success("La clave de Gemini es válida y la API responde.")
    when 429
      success("La clave parece válida; Google devolvió límite de cuota (429). Prueba más tarde.")
    when 400, 401, 403
      failure(api_error_message(body) || "Clave rechazada o API no habilitada para este proyecto.")
    else
      failure("Google respondió con código #{r.status}.")
    end
  end

  def interpret_groq(r)
    body = r.body.is_a?(Hash) ? r.body : {}

    case r.status
    when 200
      return failure("Respuesta inesperada de Groq.") unless body["data"].is_a?(Array)

      success("La clave de Groq es válida y la API responde.")
    when 429
      success("La clave parece válida; Groq devolvió límite de cuota (429). Prueba más tarde.")
    when 401, 403
      failure(api_error_message(body) || "Clave rechazada o sin permiso.")
    else
      failure("Groq respondió con código #{r.status}.")
    end
  end

  def api_error_message(body)
    err = body["error"]
    return unless err.is_a?(Hash)

    err["message"].presence || err["Message"].presence
  end

  def success(message)
    { ok: true, message: message }
  end

  def failure(message)
    { ok: false, message: message }
  end
end
