#!/usr/bin/env ruby
# Expose the canonical Echo Wiki skills to Codex without copying definitions.
require 'fileutils'
require 'open3'

module CodexSkills
  NAMES = %w[onboard ingest compile rebuild index lint query context maintain].freeze
  SOURCE = File.expand_path('../../../..', __dir__)

  def self.stop(message)
    abort "BLOCKED: #{message}"
  end

  def self.real_directory!(root, relative, required: false)
    path = root
    relative.split('/').each do |part|
      path = File.join(path, part)
      stop "#{relative}: expected a real directory; resolve the path conflict first." if File.symlink?(path) || (File.exist?(path) && !File.directory?(path)) || (required && !File.directory?(path))
    end
  end

  def self.plan(root, source_root: root)
    real_directory!(root, '.agents/skills')
    NAMES.each do |name|
      relative = ".claude/skills/#{name}"
      real_directory!(source_root, relative, required: true)
      skill = File.join(source_root, relative, 'SKILL.md')
      stop "#{relative}/SKILL.md is missing or symlinked; restore the canonical skill first." unless File.file?(skill) && !File.symlink?(skill)
    end
    NAMES.select do |name|
      relative = ".agents/skills/#{name}"
      path = File.join(root, relative)
      if File.symlink?(path) && File.readlink(path) == "../../.claude/skills/#{name}"
        false
      elsif File.exist?(path) || File.symlink?(path)
        stop "#{relative} already exists and is not the expected Echo Wiki link. Preserve it and resolve this name conflict before retrying."
      else
        true
      end
    end
  end

  # The caller holds the ordinary writer lock. Recheck every path before writing.
  def self.apply(root)
    missing = plan(root)
    return if missing.empty?
    FileUtils.mkdir_p(File.join(root, '.agents/skills'))
    missing.each do |name|
      File.symlink("../../.claude/skills/#{name}", File.join(root, '.agents/skills', name))
    end
  end

  def self.with_writer(root)
    hook = File.join(SOURCE, 'hooks/rebuild-transaction.sh')
    env = {'ECHO_WIKI_ROOT' => root}
    token, err, status = Open3.capture3(env, hook, 'writer-acquire')
    stop err unless status.success?
    begin
      yield
    ensure
      _, err, status = Open3.capture3(env.merge('ECHO_WIKI_WRITER_TOKEN' => token.strip), hook, 'writer-release')
      stop err unless status.success?
    end
  end
end

if $PROGRAM_NAME == __FILE__
  mode, target = ARGV
  CodexSkills.stop 'Usage: ruby link-codex-skills.rb --check|--apply /absolute/git-repository-root' unless ARGV.length == 2 && %w[--check --apply].include?(mode) && File.directory?(target)
  target = File.realpath(target)
  root, _, status = Open3.capture3('git', '-C', target, 'rev-parse', '--show-toplevel')
  CodexSkills.stop 'Target must be the Git repository root.' unless status.success? && File.realpath(root.strip) == target
  %w[.rebuild-lock .rebuild-state].each do |relative|
    path = File.join(target, relative)
    CodexSkills.stop "#{relative} exists; finish the active operation before linking skills." if File.exist?(path) || File.symlink?(path)
  end
  missing = CodexSkills.plan(target)
  missing.each { |name| puts "LINK .agents/skills/#{name} -> ../../.claude/skills/#{name}" }
  if mode == '--check'
    puts 'Preview only. No files changed.'
  else
    CodexSkills.with_writer(target) { CodexSkills.apply(target) } unless missing.empty?
    puts 'Codex skill links ready. Verify discovery in Codex; restart the session if needed.'
  end
end
