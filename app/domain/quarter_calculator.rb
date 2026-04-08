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

  # Inclusive date range for a calendar quarter (Q1 = ene–mar), for SQL ranges and filters.
  def self.date_range_for_year_quarter(year, quarter)
    month = ((quarter - 1) * 3) + 1
    start = Date.new(year, month, 1)
    [ start, start.end_of_quarter ]
  end
end
