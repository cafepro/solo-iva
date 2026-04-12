require "spec_helper"
require "date"
require_relative "../../app/domain/quarter_calculator"

RSpec.describe QuarterCalculator do
  describe ".quarter_for" do
    {
      Date.new(2024, 1, 15)  => 1,
      Date.new(2024, 3, 31)  => 1,
      Date.new(2024, 4, 1)   => 2,
      Date.new(2024, 6, 30)  => 2,
      Date.new(2024, 7, 1)   => 3,
      Date.new(2024, 9, 30)  => 3,
      Date.new(2024, 10, 1)  => 4,
      Date.new(2024, 12, 31) => 4
    }.each do |date, expected_quarter|
      it "returns #{expected_quarter} for #{date}" do
        expect(described_class.quarter_for(date)).to eq(expected_quarter)
      end
    end
  end

  describe ".year_for" do
    it "returns the year of the given date" do
      expect(described_class.year_for(Date.new(2024, 6, 15))).to eq(2024)
    end
  end

  describe ".current_quarter" do
    it "returns the quarter for today" do
      expected = described_class.quarter_for(Date.today)
      expect(described_class.current_quarter).to eq(expected)
    end
  end

  describe ".current_year" do
    it "returns the current year" do
      expect(described_class.current_year).to eq(Date.today.year)
    end
  end

  describe ".last_complete_quarter_for" do
    it "en Q1 devuelve T4 del año anterior" do
      expect(described_class.last_complete_quarter_for(Date.new(2026, 2, 10))).to eq([ 2025, 4 ])
    end

    it "el 1 de abril devuelve T1 del mismo año" do
      expect(described_class.last_complete_quarter_for(Date.new(2026, 4, 1))).to eq([ 2026, 1 ])
    end

    it "en Q3 devuelve T2 del mismo año" do
      expect(described_class.last_complete_quarter_for(Date.new(2026, 8, 1))).to eq([ 2026, 2 ])
    end
  end

  describe ".date_range_for_year_quarter" do
    it "returns first and last day of the calendar quarter" do
      start_date, end_date = described_class.date_range_for_year_quarter(2025, 1)
      expect(start_date).to eq(Date.new(2025, 1, 1))
      expect(end_date).to eq(Date.new(2025, 3, 31))
    end
  end
end
