#!/usr/bin/env ruby
# Copy the runtime scaffold only. Configuration, hooks and imports are agent work.
require 'fileutils'
require 'tmpdir'
require 'open3'
require 'yaml'
require 'date'
require_relative 'link-codex-skills'

SOURCE = File.expand_path('../../../..', __dir__)
MARKER = '_meta/echo-wiki-instance.yaml'
PRESERVE = %w[AGENTS.md CLAUDE.md GEMINI.md .gitignore .env.example].freeze
SKILLS = CodexSkills::NAMES
EMPTY_DIRS = %w[raw/blogs/images raw/papers/images raw/people/images raw/substacks/images
                raw/github/images raw/media/images wiki/concepts wiki/people wiki/tools
                wiki/sources wiki/workspaces/my-notes output/reports].freeze

def stop(message)
  abort "BLOCKED: #{message}"
end

def exists?(path)
  File.exist?(path) || File.symlink?(path)
end

def safe_path!(root, relative)
  path = root
  relative.split('/').each do |part|
    path = File.join(path, part)
    stop "#{relative}: symlinked path; choose a real directory or resolve the link first." if File.symlink?(path)
    if path != File.join(root, relative) && exists?(path) && !File.directory?(path)
      stop "#{relative}: parent is a file; resolve the path conflict first."
    end
  end
end

def instance_marker(path)
  File.file?(path) ? YAML.safe_load(File.read(path)) : nil
rescue Psych::Exception
  nil
end

def run!(*args, env: {})
  out, err, result = Open3.capture3(env, *args)
  stop "#{args.first} failed: #{err}#{out}" unless result.success?
  out
end

if ARGV == ['--help']
  puts 'Usage: ruby bootstrap.rb --check|--apply /absolute/git-repository-root'
  puts 'Preview first. Adds runtime files only; preserves instructions, ignore rules, hooks and artifacts.'
  exit
end
mode, target_arg = ARGV
stop 'Usage: ruby bootstrap.rb --check|--apply /absolute/git-repository-root' unless ARGV.length == 2 && %w[--check --apply].include?(mode)
stop 'Target must be an existing Git repository root. Clone or initialize it first.' unless File.directory?(target_arg)
target = File.realpath(target_arg)
root = run!('git', '-C', target, 'rev-parse', '--show-toplevel').strip
stop 'Target must be the Git repository root, not a nested directory.' unless File.realpath(root) == target
stop 'Use a separate destination repository; do not install over the upstream checkout.' if target == File.realpath(SOURCE)
%w[.rebuild-lock .rebuild-state].each do |path|
  stop "#{path} exists; finish the active operation or have its owner resolve it before onboarding." if exists?(File.join(target, path))
end
safe_path!(target, MARKER)
if exists?(File.join(target, MARKER))
  stop "#{MARKER} is not a recognized instance marker; inspect it before proceeding." unless instance_marker(File.join(target, MARKER)) == {'onboarding_version' => 1}
  run!(File.join(SOURCE, 'hooks/repository-roots.sh'), env: {'ECHO_WIKI_ROOT' => target})
  required = %w[hooks/validate.sh hooks/reindex.sh hooks/pre-commit.sh hooks/token-count.sh
                hooks/rebuild-transaction.sh hooks/repository-roots.sh hooks/workspace-paths.sh
                _meta/schemas/frontmatter.yaml _meta/prompts/structure-check.md _meta/prompts/evidence-rules.md
                wiki/_index.md wiki/_backlinks.md]
  required += SKILLS.map { |name| ".claude/skills/#{name}/SKILL.md" }
  required.each do |relative|
    safe_path!(target, relative)
    stop "Instance is missing #{relative}; restore the runtime file before resuming. Do not reinstall over existing knowledge." unless File.file?(File.join(target, relative))
  end
  missing = CodexSkills.plan(target)
  missing.each { |name| puts "LINK .agents/skills/#{name} -> ../../.claude/skills/#{name}" }
  CodexSkills.with_writer(target) { CodexSkills.apply(target) } if mode == '--apply' && !missing.empty?
  puts "Already initialized. #{mode == '--check' ? 'Preview only; no files changed.' : 'Codex links ready; runtime and knowledge preserved.'} Continue verification in the onboard skill."
  exit
end
%w[_meta raw wiki].each do |path|
  stop "#{path} already exists. Preserve it; choose a separate repository or agree an explicit migration before retrying." if exists?(File.join(target, path))
end

missing = CodexSkills.plan(target, source_root: SOURCE)
missing.each { |name| puts "LINK .agents/skills/#{name} -> ../../.claude/skills/#{name}" }

# An allowlist excludes source receipts, compiled knowledge, secrets and development workflows.
files = %w[_meta/wiki.config.yaml _meta/schemas/frontmatter.yaml]
files += Dir.glob(File.join(SOURCE, '_meta/prompts/*.md')).map { |path| path.delete_prefix("#{SOURCE}/") }
files += Dir.glob(File.join(SOURCE, 'hooks/*.sh')).map { |path| path.delete_prefix("#{SOURCE}/") }
files += SKILLS.flat_map do |name|
  base = ".claude/skills/#{name}"
  stop "Missing upstream skill: #{name}. Obtain a complete Echo Wiki checkout." unless File.file?(File.join(SOURCE, base, 'SKILL.md'))
  Dir.glob(File.join(SOURCE, base, '**/*')).select { |path| File.file?(path) || File.symlink?(path) }.map { |path| path.delete_prefix("#{SOURCE}/") }
end
files += %w[wiki/.obsidian/app.json wiki/.obsidian/appearance.json wiki/.obsidian/graph.json]
files += PRESERVE

Dir.mktmpdir('echo-wiki-scaffold-') do |stage|
  files.each do |relative|
    input = relative == '.gitignore' ? '.claude/skills/onboard/assets/instance.gitignore' : relative
    safe_path!(SOURCE, input)
    stop "Missing upstream file: #{input}" unless File.file?(File.join(SOURCE, input))
    FileUtils.mkdir_p(File.dirname(File.join(stage, relative)))
    FileUtils.cp(File.join(SOURCE, input), File.join(stage, relative), preserve: true)
  end
  EMPTY_DIRS.each do |relative|
    FileUtils.mkdir_p(File.join(stage, relative))
    File.write(File.join(stage, relative, '.gitkeep'), '')
  end
  FileUtils.cp(File.join(SOURCE, 'LICENSE'), File.join(stage, '_meta/echo-wiki-license.txt'))
  run!(File.join(stage, 'hooks/reindex.sh'), env: {'ECHO_WIKI_ROOT' => stage})
  run!(File.join(stage, 'hooks/validate.sh'), '--all', env: {'ECHO_WIKI_ROOT' => stage})
  File.write(File.join(stage, MARKER), "onboarding_version: 1\n")
  outputs = Dir.glob(File.join(stage, '**/*'), File::FNM_DOTMATCH).select { |path| File.file?(path) }.map { |path| path.delete_prefix("#{stage}/") }.sort

  outputs.each do |relative|
    safe_path!(target, relative)
    path = File.join(target, relative)
    if exists?(path)
      stop "#{relative} already exists. Resolve this runtime-file conflict before retrying." unless PRESERVE.include?(relative) && File.file?(path)
      puts "PRESERVE #{relative} (agent must integrate Echo Wiki guidance/rules)"
    else
      puts "CREATE #{relative}"
    end
  end
  if mode == '--check'
    puts 'Preview only. No target files changed. Configure and verify after --apply.'
    next
  end

  token = run!(File.join(SOURCE, 'hooks/rebuild-transaction.sh'), 'writer-acquire', env: {'ECHO_WIKI_ROOT' => target}).strip
  begin
    # The completion marker is last; an interrupted partial install must be inspected.
    CodexSkills.plan(target, source_root: SOURCE)
    (outputs - [MARKER] + [MARKER]).each do |relative|
      CodexSkills.apply(target) if relative == MARKER
      safe_path!(target, relative)
      path = File.join(target, relative)
      next if PRESERVE.include?(relative) && File.file?(path)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, File::WRONLY | File::CREAT | File::EXCL, File.stat(File.join(stage, relative)).mode & 0o777) do |out|
        out.write(File.binread(File.join(stage, relative)))
      end
    end
  ensure
    run!(File.join(SOURCE, 'hooks/rebuild-transaction.sh'), 'writer-release', env: {'ECHO_WIKI_ROOT' => target, 'ECHO_WIKI_WRITER_TOKEN' => token})
  end
  puts 'Runtime scaffold installed. Configure domains, integrate instructions/hooks, and verify with the onboard skill. No artifacts imported; no commit or push made.'
end
