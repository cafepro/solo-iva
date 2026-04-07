# Converts a date into its fiscal quarter (1–4) and year.
# Used across the app wherever quarter-based grouping is needed.
module QuarterCalculator
  def self.quarter_for(date)
    ((date.month - 1) / 3) + 1
  end

  def self.year_for(date)
    date.year
  end

  def self.current_quarter
    quarter_for(Date.today)
  end

  def self.current_year
    year_for(Date.today)
  end
end
