module ReportsHelper
  include ActionView::Helpers::NumberHelper

  # Spanish grouping for pasting into AEAT-style fields (e.g. 1.234,56).
  def modelo303_copy_value(amount)
    number_with_precision(amount.to_d, precision: 2, separator: ",", delimiter: ".")
  end
end
