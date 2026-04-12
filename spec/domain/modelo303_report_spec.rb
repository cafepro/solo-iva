require "spec_helper"
require_relative "../../app/domain/modelo303_report"

RSpec.describe Modelo303Report do
  Modelo303Line = Struct.new(:iva_rate, :base_imponible, :iva_amount)

  let(:issued_lines) do
    [
      Modelo303Line.new(21, 1000.0, 210.0),
      Modelo303Line.new(10, 500.0, 50.0),
      Modelo303Line.new(4, 200.0, 8.0)
    ]
  end

  let(:received_lines) do
    [
      Modelo303Line.new(21, 300.0, 63.0),
      Modelo303Line.new(10, 100.0, 10.0)
    ]
  end

  subject(:report) { described_class.new(lines_issued: issued_lines, lines_received: received_lines) }

  describe "#to_h" do
    let(:result) { report.to_h }

    it "calculates base and cuota at 4 % (casillas 01 y 03)" do
      expect(result[:casilla_01]).to eq(200.0)
      expect(result[:casilla_03]).to eq(8.0)
    end

    it "calculates base and cuota at 10 % (casillas 04 y 06)" do
      expect(result[:casilla_04]).to eq(500.0)
      expect(result[:casilla_06]).to eq(50.0)
    end

    it "calculates base and cuota at 21 % (casillas 07 y 09)" do
      expect(result[:casilla_07]).to eq(1000.0)
      expect(result[:casilla_09]).to eq(210.0)
    end

    it "sums total cuota devengada (casilla 27)" do
      expect(result[:casilla_27]).to eq(268.0)
    end

    it "sums base deducible from received invoices (casilla 28)" do
      expect(result[:casilla_28]).to eq(400.0)
    end

    it "sums IVA deducible (casillas 29 y 45)" do
      expect(result[:casilla_29]).to eq(73.0)
      expect(result[:casilla_45]).to eq(73.0)
    end

    it "calculates resultado régimen general (casilla 46) y total (64)" do
      expect(result[:casilla_46]).to eq(268.0 - 73.0)
      expect(result[:casilla_64]).to eq(result[:casilla_46])
    end
  end

  context "with 0 % issued lines" do
    let(:issued_lines) { [ Modelo303Line.new(0, 100.0, 0.0) ] }
    let(:received_lines) { [] }

    it "uses casillas 150 y 152" do
      result = described_class.new(lines_issued: issued_lines, lines_received: received_lines).to_h
      expect(result[:casilla_150]).to eq(100.0)
      expect(result[:casilla_152]).to eq(0.0)
      expect(result[:casilla_27]).to eq(0.0)
    end
  end

  context "with no invoices" do
    subject(:empty_report) { described_class.new(lines_issued: [], lines_received: []) }

    it "returns zeros for totales" do
      result = empty_report.to_h
      expect(result[:casilla_64]).to eq(0.0)
      expect(result[:casilla_27]).to eq(0.0)
      expect(result[:casilla_45]).to eq(0.0)
    end
  end
end
