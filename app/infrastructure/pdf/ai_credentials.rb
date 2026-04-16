module Pdf
  # Resolución de claves Gemini/Groq solo desde la cuenta del usuario (Integraciones con IA).
  module AiCredentials
    module_function

    def gemini_api_key_for(user)
      user&.gemini_api_key.presence
    end

    def groq_api_key_for(user)
      user&.groq_api_key.presence
    end
  end
end
