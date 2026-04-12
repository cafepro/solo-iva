class BillingProfilesController < ApplicationController
  def show
    # Recarga explícita: evita mostrar un usuario en memoria desactualizado (p. ej. tras guardar con Turbo).
    @user = current_user.reload
  end

  def update
    @user = current_user
    if @user.update(billing_profile_params)
      redirect_to billing_profile_path, notice: "Datos de facturación y numeración guardados."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def billing_profile_params
    params.require(:user).permit(
      :billing_display_name, :billing_nif, :billing_address_line,
      :billing_postal_code, :billing_city, :billing_province, :billing_country,
      :billing_phone, :billing_email, :paypal_email, :iban, :payment_methods_note,
      :invoice_number_prefix, :invoice_number_digit_count, :invoice_number_next
    )
  end
end
