class DashboardController < ApplicationController
  def index
    @year    = params[:year]&.to_i  || Date.today.year
    @quarter = params[:quarter]&.to_i || current_quarter

    @report = Modelo303Calculator.new(
      user:    current_user,
      year:    @year,
      quarter: @quarter
    ).calculate

    @recent_invoices = current_user.invoices.order(invoice_date: :desc).limit(5)
  end

  private

  def current_quarter
    ((Date.today.month - 1) / 3) + 1
  end
end
