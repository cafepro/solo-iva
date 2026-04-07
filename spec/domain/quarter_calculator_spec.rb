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
end
