module InvoicesHelper
  def sort_header(col, label, current_sort, current_dir, align: "left")
    active   = current_sort == col
    next_dir = active && current_dir == "asc" ? "desc" : "asc"
    arrow    = active ? (current_dir == "asc" ? " ↑" : " ↓") : ""

    link = link_to(
      invoices_path(sort: col, dir: next_dir, invoice_type: params[:invoice_type]),
      class: "inline-flex items-center gap-1 hover:text-gray-800 #{active ? 'text-gray-800 font-semibold' : ''}"
    ) { "#{label}#{arrow}".html_safe }

    content_tag(:th, link, class: "px-4 py-3 text-#{align}")
  end
end
