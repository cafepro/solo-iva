class ReportsController < ApplicationController
  def modelo303
    default_year, default_quarter = QuarterCalculator.last_complete_quarter_for
    @year    = params[:year].present?    ? params[:year].to_i    : default_year
    @quarter = params[:quarter].present? ? params[:quarter].to_i : default_quarter

    @report = CalculateModelo303.new(user: current_user, year: @year, quarter: @quarter)
                                .call.to_h
  end
end
