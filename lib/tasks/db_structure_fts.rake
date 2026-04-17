# SQLite's FTS5 CREATE VIRTUAL TABLE implicitly creates shadow tables
# (messages_fts_data / _idx / _docsize / _config). Those names are reserved by
# SQLite and cannot be created directly — but Rails' structure dumper emits
# them anyway, so db:schema:load explodes with
#   "object name reserved for internal use: messages_fts_data"
#
# Post-process the dump to strip those lines. The virtual table CREATE
# recreates them automatically on load.
Rake::Task["db:schema:dump"].enhance do
  path = Rails.root.join("db/structure.sql")
  next unless path.exist?

  cleaned = path.read.lines.reject do |line|
    line =~ /\ACREATE TABLE IF NOT EXISTS '[a-z_]+_fts_(data|idx|docsize|config)'/
  end.join

  path.write(cleaned)
end
