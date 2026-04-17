module ApplicationHelper
  # Renders a consistent pill for a conversation or project source.
  #   source: "code" | "desktop"
  #   size:   :md (default) | :sm
  SOURCE_META = {
    "code"    => { label: "Code",    icon: "⌨" },
    "desktop" => { label: "Desktop", icon: "◐" }
  }.freeze

  def source_badge(source, size: :md, class: nil)
    source = source.to_s
    meta = SOURCE_META[source] || { label: source.titleize, icon: "·" }

    base = "inline-flex items-center gap-1 rounded-full font-medium uppercase tracking-wide"
    sized = size == :sm ? "px-1.5 py-0 text-[9px]" : "px-2 py-0.5 text-[10px]"
    color = source == "desktop" ? "bg-secondary text-secondary-foreground" : "bg-primary/10 text-primary"
    extra = binding.local_variable_get(:class)

    content_tag(:span, class: "#{base} #{sized} #{color} #{extra}".strip, title: "Source: #{meta[:label]}") do
      concat content_tag(:span, meta[:icon], class: "opacity-70", "aria-hidden": "true")
      concat content_tag(:span, meta[:label])
    end
  end

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

  # claude.ai replaces content types its client can't render (artifacts,
  # images, tool results, etc.) with a text block containing a code fence:
  #
  #     ```
  #     This block is not supported on your current device yet.
  #     ```
  #
  # The original payload never reaches us, so the best we can do is surface
  # "something was here" instead of rendering the placeholder verbatim.
  UNSUPPORTED_BLOCK_PLACEHOLDER = "This block is not supported on your current device yet.".freeze

  def unsupported_placeholder_text?(text)
    text.to_s.include?(UNSUPPORTED_BLOCK_PLACEHOLDER)
  end

  def unsupported_block_notice
    content_tag(
      :div,
      class: "my-2 rounded-md border border-dashed border-border bg-muted/30 px-3 py-2 text-xs text-muted-foreground italic flex items-start gap-2"
    ) do
      concat content_tag(:span, "⚠", "aria-hidden": "true")
      concat content_tag(:span, "Unsupported content (likely an artifact, image, or tool result) — claude.ai replaced it with a placeholder in the export, so it can't be rendered here.")
    end
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
    # Strip placeholder padding so hits that land in the middle of a dud block
    # don't return a snippet dominated by the "not supported" text.
    text = text.to_s.gsub(UNSUPPORTED_BLOCK_PLACEHOLDER, "[unsupported content]")
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
