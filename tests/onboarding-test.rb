# Run: ruby tests/onboarding-test.rb
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'find'

class OnboardingTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  SCRIPT = File.join(ROOT, '.claude/skills/onboard/scripts/bootstrap.rb')
  LINKER = File.join(ROOT, '.claude/skills/onboard/scripts/link-codex-skills.rb')
  SKILLS = %w[onboard ingest compile rebuild index lint query context maintain].freeze

  def setup
    @tmp = Dir.mktmpdir('echo-onboarding-')
    @target = File.join(@tmp, 'company knowledge')
    FileUtils.mkdir_p(@target)
    system('git', 'init', '-q', @target) || raise('git init failed')
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def run_bootstrap(mode = '--apply', target = @target, script = SCRIPT)
    out, err, status = Open3.capture3('ruby', script, mode, target)
    [out + err, status.success?]
  end

  def write(path, text)
    full = File.join(@target, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, text)
  end

  def snapshot(root = @target)
    Find.find(root).sort.map do |path|
      [path.delete_prefix(root), File.symlink?(path) ? File.readlink(path) : File.file?(path) ? File.binread(path) : :directory]
    end
  end

  def test_preview_does_not_write_and_apply_creates_valid_runtime
    before = snapshot
    out, success = run_bootstrap('--check')
    assert success, out
    assert_includes out, 'CREATE _meta/wiki.config.yaml'
    assert_equal before, snapshot
    out, success = run_bootstrap
    assert success, out
    assert_codex_links
    assert File.file?(File.join(@target, '.claude/skills/onboard/SKILL.md'))
    assert File.executable?(File.join(@target, 'hooks/validate.sh'))
    output, status = Open3.capture2e({'ECHO_WIKI_ROOT' => @target}, File.join(@target, 'hooks/validate.sh'), '--all')
    assert status.success?, output
    refute File.exist?(File.join(@target, '.github'))
    refute File.exist?(File.join(@target, 'package.json'))
  end

  def test_existing_artifacts_instructions_and_git_setup_are_preserved
    files = {
      'README.md' => 'Company documentation', 'docs/roadmap.md' => 'Approved roadmap',
      'mockups/home.html' => '<h1>Home</h1>', 'media/logo.bin' => "\x00\xff".b,
      'AGENTS.md' => 'Our rules', 'CLAUDE.md' => 'Our Claude rules',
      'GEMINI.md' => 'Our Gemini rules', '.gitignore' => '/private/',
      '.env.example' => 'COMPANY_TOKEN=',
      'hooks/custom.sh' => '# custom', '.git/hooks/pre-commit' => '# company hook',
      '.claude/skills/company/SKILL.md' => 'Existing company skill',
      '.agents/skills/company/SKILL.md' => 'Existing Codex skill'
    }
    files.each { |path, text| write(path, text) }
    system('git', '-C', @target, 'remote', 'add', 'origin', 'https://example.invalid/company.git')
    config = File.binread(File.join(@target, '.git/config'))
    out, success = run_bootstrap
    assert success, out
    files.each { |path, text| assert_equal text, File.binread(File.join(@target, path)), path }
    assert_equal config, File.binread(File.join(@target, '.git/config'))
    assert_includes out, 'PRESERVE AGENTS.md'
  end

  def test_install_does_not_hide_existing_artifacts_from_git
    paths = %w[design/roadmap.canvas dashboard.base docs/superpowers/plan.md]
    paths.each { |path| write(path, 'Existing customer artifact') }
    before, status = Open3.capture2('git', '-C', @target, 'ls-files', '--others', '--exclude-standard', '--', *paths)
    assert status.success?
    assert_equal paths.sort, before.lines.map(&:strip).sort
    out, success = run_bootstrap
    assert success, out
    after, status = Open3.capture2('git', '-C', @target, 'ls-files', '--others', '--exclude-standard', '--', *paths)
    assert status.success?
    assert_equal before, after
    ignored, status = Open3.capture2('git', '-C', @target, 'check-ignore', '.env', 'wiki/.obsidian/workspace.json')
    assert status.success?
    assert_equal %w[.env wiki/.obsidian/workspace.json], ignored.lines.map(&:strip)
  end

  def test_reserved_directory_conflicts_fail_without_partial_installation
    %w[wiki raw _meta].each do |name|
      write("#{name}/company.md", 'Existing customer artifact')
      before = snapshot
      out, success = run_bootstrap
      refute success, out
      assert_includes out, 'BLOCKED:'
      assert_includes out, name
      assert_equal before, snapshot
      FileUtils.remove_entry(File.join(@target, name))
    end
  end

  def test_runtime_file_conflict_is_preflighted
    write('hooks/validate.sh', 'Existing validator')
    before = snapshot
    out, success = run_bootstrap
    refute success, out
    assert_includes out, 'BLOCKED:'
    assert_includes out, 'hooks/validate.sh'
    assert_equal before, snapshot
  end

  def test_symlink_parent_is_rejected_without_writing_outside_repo
    outside = File.join(@tmp, 'outside')
    FileUtils.mkdir_p(outside)
    File.symlink(outside, File.join(@target, '.claude'))
    before = snapshot
    out, success = run_bootstrap
    refute success, out
    assert_includes out, 'BLOCKED:'
    assert_equal before, snapshot
    assert_empty Dir.children(outside)
  end

  def test_rerun_preserves_customization_and_content
    out, success = run_bootstrap
    assert success, out
    write('_meta/wiki.config.yaml', File.read(File.join(@target, '_meta/wiki.config.yaml')).sub('My Wiki', 'Company KB'))
    write('wiki/workspaces/my-notes/draft.md', 'Work in progress')
    before = snapshot
    out, success = run_bootstrap
    assert success, out
    assert_includes out, 'Already initialized'
    assert_equal before, snapshot
  end

  def test_rerun_reports_missing_runtime_without_reinstalling
    out, success = run_bootstrap
    assert success, out
    FileUtils.remove_entry(File.join(@target, 'hooks'))
    before = snapshot
    out, success = run_bootstrap
    refute success, out
    assert_includes out, 'BLOCKED:'
    assert_includes out, 'hooks/'
    assert_equal before, snapshot
  end

  def test_invalid_instance_marker_is_actionable_and_preserved
    write('_meta/echo-wiki-instance.yaml', 'onboarding_version: [')
    before = snapshot
    out, success = run_bootstrap
    refute success, out
    assert_includes out, 'BLOCKED:'
    assert_includes out, 'marker'
    assert_equal before, snapshot
  end

  def test_nested_directory_is_not_treated_as_git_root
    nested = File.join(@target, 'docs')
    FileUtils.mkdir_p(nested)
    before = snapshot
    out, success = run_bootstrap('--apply', nested)
    refute success, out
    assert_includes out, 'BLOCKED:'
    assert_includes out, 'repository root'
    assert_equal before, snapshot
  end

  def test_active_writer_blocks_installation
    write('.rebuild-lock/owner', 'writer:other')
    before = snapshot
    out, success = run_bootstrap
    refute success, out
    assert_includes out, 'BLOCKED:'
    assert_equal before, snapshot
  end

  def test_bootstrap_never_copies_source_knowledge_or_secrets
    source = File.join(@tmp, 'source')
    FileUtils.mkdir_p(source)
    %w[.claude _meta hooks wiki raw .gitignore .env.example LICENSE AGENTS.md CLAUDE.md GEMINI.md].each do |path|
      FileUtils.cp_r(File.join(ROOT, path), File.join(source, path))
    end
    File.write(File.join(source, 'raw/blogs/private.md'), 'Private source')
    File.write(File.join(source, 'wiki/concepts/private.md'), 'Private knowledge')
    File.write(File.join(source, 'wiki/workspaces/my-notes/private.md'), 'Private draft')
    File.write(File.join(source, '.env'), 'SECRET=example')
    out, success = run_bootstrap('--apply', @target, File.join(source, '.claude/skills/onboard/scripts/bootstrap.rb'))
    assert success, out
    %w[raw/blogs/private.md wiki/concepts/private.md wiki/workspaces/my-notes/private.md .env].each do |path|
      refute File.exist?(File.join(@target, path)), path
    end
  end
  def assert_codex_links(root = @target)
    SKILLS.each do |name|
      link = File.join(root, '.agents/skills', name)
      assert File.symlink?(link), "Missing Codex skill link: #{name}"
      assert_equal "../../.claude/skills/#{name}", File.readlink(link)
      assert_equal File.realpath(File.join(root, '.claude/skills', name)), File.realpath(link)
    end
  end

  def test_upstream_clone_includes_shared_codex_skills
    assert_codex_links(ROOT)
  end

  def test_existing_instance_repairs_links_without_changing_content
    out, success = run_bootstrap
    assert success, out
    FileUtils.remove_entry(File.join(@target, '.agents'))
    write('AGENTS.md', 'Customer rules')
    write('raw/blogs/customer.md', 'Existing evidence')
    write('.agents/skills/company/SKILL.md', 'Existing Codex skill')
    before = snapshot
    out, success = run_bootstrap('--check')
    assert success, out
    assert_includes out, 'LINK .agents/skills/query'
    assert_equal before, snapshot
    out, success = run_bootstrap
    assert success, out
    assert_codex_links
    assert_equal before, snapshot.reject { |path, _| SKILLS.any? { |name| path == "/.agents/skills/#{name}" } }
  end

  def test_codex_conflicts_are_preflighted_for_fresh_and_existing_instances
    [false, true].each do |installed|
      if installed
        out, success = run_bootstrap
        assert success, out
        File.unlink(File.join(@target, '.agents/skills/query'))
        File.unlink(File.join(@target, '.agents/skills/onboard'))
      end
      write('.agents/skills/query/SKILL.md', 'Customer query skill')
      before = snapshot
      out, success = run_bootstrap
      refute success, out
      assert_includes out, 'BLOCKED:'
      assert_includes out, '.agents/skills/query'
      assert_equal before, snapshot
      FileUtils.remove_entry(File.join(@target, '.agents/skills/query'))
    end
  end

  def test_codex_parent_symlink_is_rejected
    outside = File.join(@tmp, 'outside')
    FileUtils.mkdir_p(outside)
    File.symlink(outside, File.join(@target, '.agents'))
    before = snapshot
    out, success = run_bootstrap
    refute success, out
    assert_includes out, 'BLOCKED:'
    assert_equal before, snapshot
    assert_empty Dir.children(outside)
  end

  def test_standalone_linker_supports_older_instances_and_is_idempotent
    out, success = run_bootstrap
    assert success, out
    FileUtils.remove_entry(File.join(@target, '.agents'))
    File.unlink(File.join(@target, '.claude/skills/onboard/scripts/link-codex-skills.rb'))
    before = snapshot
    out, success = run_bootstrap('--check', @target, LINKER)
    assert success, out
    assert_equal before, snapshot
    out, success = run_bootstrap('--apply', @target, LINKER)
    assert success, out
    assert_codex_links
    linked = snapshot
    out, success = run_bootstrap('--apply', @target, LINKER)
    assert success, out
    assert_equal linked, snapshot
    File.unlink(File.join(@target, '.agents/skills/query'))
    File.symlink('../../wrong', File.join(@target, '.agents/skills/query'))
    before = snapshot
    out, success = run_bootstrap('--apply', @target, LINKER)
    refute success, out
    assert_includes out, '.agents/skills/query'
    assert_equal before, snapshot
  end

  def test_standalone_linker_rejects_missing_source_and_active_writer
    out, success = run_bootstrap
    assert success, out
    FileUtils.remove_entry(File.join(@target, '.agents'))
    write('.rebuild-lock/owner', 'writer:other')
    before = snapshot
    out, success = run_bootstrap('--apply', @target, LINKER)
    refute success, out
    assert_equal before, snapshot
    FileUtils.remove_entry(File.join(@target, '.rebuild-lock'))
    File.unlink(File.join(@target, '.claude/skills/query/SKILL.md'))
    before = snapshot
    out, success = run_bootstrap('--apply', @target, LINKER)
    refute success, out
    assert_includes out, '.claude/skills/query'
    assert_equal before, snapshot
  end

end
