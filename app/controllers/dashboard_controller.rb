class DashboardController < ApplicationController
  def index
    @year    = params[:year]&.to_i    || QuarterCalculator.current_year
    @quarter = params[:quarter]&.to_i || QuarterCalculator.current_quarter

    @report = CalculateModelo303.new(user: current_user, year: @year, quarter: @quarter)
                                .call.to_h

    @recent_invoices = current_user.invoices.order(invoice_date: :desc).limit(5)
  end
end
