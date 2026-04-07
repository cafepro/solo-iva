class ReportsController < ApplicationController
  def modelo303
    @year    = params[:year]&.to_i  || Date.today.year
    @quarter = params[:quarter]&.to_i || current_quarter

    @report = Modelo303Calculator.new(
      user:    current_user,
      year:    @year,
      quarter: @quarter
    ).calculate
  end

  private

  def current_quarter
    ((Date.today.month - 1) / 3) + 1
  end
end
