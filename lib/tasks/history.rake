namespace :history do
  desc "Import Claude Code conversation history from ~/.claude/projects"
  task sync: :environment do
    puts "Scanning #{ClaudeHistory::Importer::DEFAULT_ROOT}…"
    summary = ClaudeHistory::Importer.run(logger: Logger.new($stdout))
    puts summary.to_s
  end
end
