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

  # El trimestre natural más reciente ya cerrado (día anterior al inicio del trimestre en curso).
  # Ej.: en enero–marzo → T4 del año anterior; desde el 1 de abril → T1 del mismo año.
  def self.last_complete_quarter_for(date = Date.today)
    q = quarter_for(date)
    y = year_for(date)
    first_month_of_quarter = ((q - 1) * 3) + 1
    last_day_previous       = Date.new(y, first_month_of_quarter, 1) - 1

    [ year_for(last_day_previous), quarter_for(last_day_previous) ]
  end

  # Inclusive date range for a calendar quarter (Q1 = ene–mar), for SQL ranges and filters.
  def self.date_range_for_year_quarter(year, quarter)
    start_month = ((quarter - 1) * 3) + 1
    end_month   = start_month + 2
    start = Date.new(year, start_month, 1)
    last  = Date.new(year, end_month, -1)
    [ start, last ]
  end
end
