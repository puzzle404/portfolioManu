module FinanceHelper
  # "8.000", "29.790,79", "1.500" — Argentine formatting, no trailing ".0".
  def money(value)
    number_with_precision(value || 0, precision: 2, delimiter: ".", separator: ",", strip_insignificant_zeros: true)
  end
end
