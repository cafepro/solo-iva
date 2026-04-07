class ReportsController < ApplicationController
  def modelo303
    @year    = params[:year]&.to_i    || QuarterCalculator.current_year
    @quarter = params[:quarter]&.to_i || QuarterCalculator.current_quarter

    @report = CalculateModelo303.new(user: current_user, year: @year, quarter: @quarter)
                                .call.to_h
  end
end
