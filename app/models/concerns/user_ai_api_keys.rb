# Cifrado en reposo de claves API (Gemini / Groq) por usuario, con MessageEncryptor + secret_key_base.
module UserAiApiKeys
  extend ActiveSupport::Concern

  SALT = "SoloIva::UserAiApiKeys::v1"

  class_methods do
    def user_ai_key_encryptor
      @user_ai_key_encryptor ||= ActiveSupport::MessageEncryptor.new(
        ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(SALT, 32),
        cipher:     "aes-256-gcm",
        serializer: JSON
      )
    end

    def encrypt_user_ai_token(plain)
      return nil if plain.blank?

      user_ai_key_encryptor.encrypt_and_sign(plain.to_s.strip)
    end

    def decrypt_user_ai_token(blob)
      return nil if blob.blank?

      user_ai_key_encryptor.decrypt_and_verify(blob)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError, TypeError
      nil
    end
  end

  def gemini_api_key
    self.class.decrypt_user_ai_token(read_attribute(:encrypted_gemini_api_key))
  end

  def gemini_api_key=(plain)
    write_attribute(:encrypted_gemini_api_key, self.class.encrypt_user_ai_token(plain))
  end

  def groq_api_key
    self.class.decrypt_user_ai_token(read_attribute(:encrypted_groq_api_key))
  end

  def groq_api_key=(plain)
    write_attribute(:encrypted_groq_api_key, self.class.encrypt_user_ai_token(plain))
  end

  def gemini_api_key_configured?
    encrypted_gemini_api_key.present?
  end

  def groq_api_key_configured?
    encrypted_groq_api_key.present?
  end
end
