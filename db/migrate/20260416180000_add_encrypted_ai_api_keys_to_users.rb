class AddEncryptedAiApiKeysToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :encrypted_gemini_api_key, :text
    add_column :users, :encrypted_groq_api_key, :text
  end
end
