# Formats and reserves the next invoice number for a user (emitidas).
# Must run inside the same DB transaction as +Invoice#save+ so a failed save rolls back the counter.
class AssignNextInvoiceNumber
  def initialize(user)
    @user = user
  end

  def preview
    @user.with_lock do
      format_number(@user.invoice_number_next)
    end
  end

  def consume!
    @user.with_lock do
      n = @user.invoice_number_next
      str = format_number(n)
      @user.update!(invoice_number_next: n + 1)
      str
    end
  end

  private

  def format_number(n)
    prefix = @user.invoice_number_prefix.presence || "F"
    digits = @user.invoice_number_digit_count.to_i.clamp(1, 12)
    "#{prefix}#{n.to_i.to_s.rjust(digits, '0')}"
  end
end
