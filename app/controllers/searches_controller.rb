class SearchesController < ApplicationController
  MAX_RESULTS = 100

  def show
    @query = params[:q].to_s.strip
    @results = []
    return if @query.blank?

    fts_query = build_fts_query(@query)

    ids = ActiveRecord::Base.connection.select_values(
      ActiveRecord::Base.sanitize_sql_array([
        "SELECT rowid FROM messages_fts WHERE messages_fts MATCH ? ORDER BY rank LIMIT ?",
        fts_query, MAX_RESULTS
      ])
    )

    messages = Message
      .where(id: ids)
      .includes(conversation: :project)
    messages = messages.sort_by { |m| ids.index(m.id) }

    @results = messages.group_by(&:conversation)
    @match_count = ids.length
  end

  private

  def build_fts_query(raw)
    tokens = raw.scan(/[\p{L}\p{N}_]+/)
    return '""' if tokens.empty?
    tokens.map { |t| %("#{t}") }.join(" ")
  end
end
