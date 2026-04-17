module ApplicationHelper
  MARKDOWN_RENDERER = Redcarpet::Markdown.new(
    Redcarpet::Render::HTML.new(
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener" },
      escape_html: true
    ),
    autolink: true,
    fenced_code_blocks: true,
    tables: true,
    strikethrough: true,
    no_intra_emphasis: true,
    lax_spacing: true
  )

  def render_markdown(text)
    return "".html_safe if text.blank?
    MARKDOWN_RENDERER.render(text.to_s).html_safe
  end

  def relative_time(time)
    return "" if time.nil?
    secs = Time.current - time
    case
    when secs < 60     then "just now"
    when secs < 3_600  then "#{(secs / 60).to_i}m ago"
    when secs < 86_400 then "#{(secs / 3_600).to_i}h ago"
    when secs < 604_800 then "#{(secs / 86_400).to_i}d ago"
    else time.strftime("%Y-%m-%d")
    end
  end

  def snippet_around(text, query, radius: 120)
    return "" if text.blank?
    terms = query.to_s.scan(/[\p{L}\p{N}_]+/)
    return truncate_plain(text, 240) if terms.empty?

    re = Regexp.new(terms.map { |t| Regexp.escape(t) }.join("|"), Regexp::IGNORECASE)
    match = text.match(re)
    return truncate_plain(text, 240) unless match

    start = [ match.begin(0) - radius, 0 ].max
    stop  = [ match.begin(0) + radius, text.length ].min
    snippet = text[start...stop].to_s
    snippet = "…#{snippet}" if start > 0
    snippet = "#{snippet}…" if stop < text.length
    highlight(snippet, terms, highlighter: '<mark>\1</mark>')
  end

  def truncate_plain(text, length)
    return "" if text.blank?
    text.length > length ? text[0, length] + "…" : text
  end
end
