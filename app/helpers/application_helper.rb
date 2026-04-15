module ApplicationHelper
  # Título mostrado en la cabecera del área principal (layout con sidebar).
  # Preferir `content_for :section_title` cuando el título de pestaña (`content_for :title`) no convenga.
  def page_section_heading
    if content_for?(:section_title)
      content_for(:section_title)
    else
      t = content_for(:title).to_s.sub(/\s*—\s*SoloIVA\s*\z/, "").strip
      t.presence || "SoloIVA"
    end
  end
end
