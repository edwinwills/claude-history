module StatsHelper
  # 1234 -> "1.2K", 3_400_000 -> "3.4M"
  def compact_number(n)
    number_to_human(n.to_i, units: { thousand: "K", million: "M", billion: "B", trillion: "T" },
                            format: "%n%u", precision: 3, significant: true)
  end

  def percent(fraction, precision: 0)
    return "—" if fraction.nil?
    "#{number_with_precision(fraction * 100, precision: precision)}%"
  end

  # Small "▲ 12%" / "▼ 8%" badge versus the previous period.
  def change_badge(current, previous)
    change = UsageStats.percent_change(current, previous)
    return content_tag(:span, "no prior data", class: "text-xs text-muted-foreground") if change.nil?

    up = change >= 0
    content_tag(:span, class: "text-xs #{up ? 'text-emerald-600 dark:text-emerald-400' : 'text-rose-600 dark:text-rose-400'}",
                       title: "vs previous period (#{number_with_delimiter(previous)})") do
      "#{up ? '▲' : '▼'} #{number_with_precision(change.abs, precision: 0)}% vs prev"
    end
  end
end
