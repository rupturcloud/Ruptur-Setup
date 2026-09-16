const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const cp = require('node:child_process');
const YAML = require('yaml');
const root = path.resolve(__dirname, '..');
const bash = process.env.BASH_BIN || (process.platform === 'win32' ? 'C:/Program Files/Git/usr/bin/bash.exe' : 'bash');
const shellPath = p => p.replaceAll('\\', '/').replace(/^([A-Za-z]):/, (_, d) => '/' + d.toLowerCase());
const keys = fs.readFileSync(path.join(root, '.env.example'), 'utf8').split('\n').filter(l => /^[A-Z].*=/.test(l)).map(l => l.split('=')[0]);
function env(extra = {}) {
  const result = { ...process.env };
  for (const key of [...keys, 'RUPTUR_CONFIG_FILE', 'CHAT_SECRET_KEY', 'CHAT_POSTGRES_PASSWORD']) delete result[key];
  return { ...result, RUPTUR_CONFIG_FILE: '/nonexistent/ruptur-test.env', ...extra };
}
function run(args, extra = {}, input) {
  return cp.spawnSync(bash, args, { cwd: root, env: env(extra), input, encoding: 'utf8', timeout: 20000 });
}
function temp(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ruptur-test-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  return dir;
}
function render(t, variant, extra = {}, args = []) {
  const output = path.join(temp(t), 'stack.yaml');
  const result = run(['RupturSetup', '--render-chatwoot', shellPath(output), '--variant', variant, ...args], {
    SMTP_HOST: 'smtp.example.com', SMTP_PASSWORD: 'test-only-password', CHAT_POSTGRES_PASSWORD: 'test-only-postgres', CHAT_SECRET_KEY: 'a'.repeat(128), ...extra
  });
  assert.equal(result.status, 0, result.stderr);
  const text = fs.readFileSync(output, 'utf8');
  return { stack: YAML.parse(text), text, result };
}
test('all maintained Bash entry points and modules have valid syntax', () => {
  const files = ['Setup', 'RupturSetup', ...['lib', 'modules'].flatMap(d => fs.readdirSync(path.join(root, d)).filter(f => f.endsWith('.sh')).map(f => d + '/' + f))];
  for (const file of files) {
    const result = run(['-n', file]);
    assert.equal(result.status, 0, file + ': ' + result.stderr);
  }
});
test('help and config checks never run an installation', () => {
  for (const entry of ['Setup', 'RupturSetup']) {
    for (const option of ['--help', '--check-config']) {
      const r = run([entry, option]);
      assert.equal(r.status, 0, r.stderr);
      assert.doesNotMatch(r.stdout + r.stderr, /apt |docker |sudo /);
    }
  }
});
for (const variant of ['standard', 'mega']) {
  test(variant + ': defaults render valid YAML with consistent web and worker settings', t => {
    const { stack, text } = render(t, variant);
    const prefix = variant === 'mega' ? 'chatwoot_nestor' : 'chatwoot';
    const web = stack.services[prefix + '_app'];
    const worker = stack.services[prefix + '_sidekiq'];
    assert.equal(web.environment.INSTALLATION_NAME, 'Ruptur-Chat');
    assert.equal(web.environment.SMTP_USERNAME, 'ruptur.cloud@gmail.com');
    assert.equal(web.environment.CW_ENABLE_ENTERPRISE, 'true');
    assert.equal(web.environment.ENTERPRISE_TOKEN, 'true');
    for (const key of ['INSTALLATION_NAME', 'BRAND_NAME', 'SMTP_ADDRESS', 'SMTP_USERNAME', 'SMTP_PASSWORD', 'CW_ENABLE_ENTERPRISE', 'ENTERPRISE_TOKEN', 'POSTGRES_PASSWORD']) {
      assert.equal(web.environment[key], worker.environment[key], key);
    }
    assert.deepEqual(web.networks, ['ruptur-net']);
    assert.equal(stack.networks['ruptur-net'].external, true);
    assert.equal(web.environment.SMTP_SSL, 'false');
    assert.equal(web.environment.SMTP_ENABLE_STARTTLS_AUTO, 'true');
    assert.doesNotMatch(text, /@@|\$\{1:/);
  });
  test(variant + ': partner identity, instance and special characters survive rendering', t => {
    const secret = 'quote\' " # : ${HOME} $(touch SHOULD_NOT_EXIST) `id` \\ ! & @@BASE_URL@@';
    const { stack, result } = render(t, variant, {
      SMTP_FROM_EMAIL: 'mail@partner.example', SMTP_PASSWORD: secret, CHAT_POSTGRES_PASSWORD: secret,
      SMTP_PORT: '465', SUPPORT_EMAIL: 'help@partner.example', CW_ENABLE_ENTERPRISE: 'false', ENTERPRISE_TOKEN: 'custom-token'
    }, ['--domain', 'partner.example', '--brand', 'Partner', '--chat-brand', "Partner's Chat: Support", '--network', 'partner-net', '--instance', 'client_2']);
    const prefix = (variant === 'mega' ? 'chatwoot_nestor' : 'chatwoot') + '_client_2';
    const web = stack.services[prefix + '_app'];
    assert.equal(web.environment.INSTALLATION_NAME, "Partner's Chat: Support");
    assert.equal(web.environment.FRONTEND_URL, 'https://chat.partner.example');
    assert.equal(web.environment.SMTP_USERNAME, 'mail@partner.example');
    assert.equal(web.environment.SMTP_PASSWORD.replaceAll('$$', '$'), secret);
    assert.equal(web.environment.POSTGRES_PASSWORD.replaceAll('$$', '$'), secret);
    assert.equal(web.environment.CW_ENABLE_ENTERPRISE, 'false');
    assert.equal(web.environment.ENTERPRISE_TOKEN, 'custom-token');
    assert.equal(web.environment.SMTP_ENABLE_STARTTLS_AUTO, 'false');
    assert.equal(stack.networks['partner-net'].name, 'partner-net');
    assert.ok(stack.volumes[prefix + '_storage']);
    assert.doesNotMatch(result.stdout + result.stderr, /test-only|custom-token|touch SHOULD_NOT_EXIST/);
    assert.equal(fs.existsSync(path.join(root, 'SHOULD_NOT_EXIST')), false);
  });
}
test('config precedence is CLI > environment > file > fallback, without executing .env', t => {
  const dir = temp(t), config = path.join(dir, 'partner.env');
  fs.writeFileSync(config, 'BRAND_NAME=File Brand\r\nCHAT_BRAND_NAME=File Chat\r\nSMTP_PASSWORD=literal$(touch SHOULD_NOT_EXIST)\r\nSMTP_FROM_EMAIL=file@partner.example\r\n');
  const { stack } = render(t, 'mega', { CHAT_BRAND_NAME: 'Environment Chat', SMTP_PASSWORD: undefined }, ['--config', shellPath(config), '--chat-brand', 'CLI Chat']);
  const e = stack.services.chatwoot_nestor_app.environment;
  assert.equal(e.INSTALLATION_NAME, 'CLI Chat');
  assert.equal(e.SMTP_USERNAME, 'file@partner.example');
  assert.equal(e.SMTP_PASSWORD.replaceAll('$$', '$'), 'literal$(touch SHOULD_NOT_EXIST)');
  assert.equal(fs.existsSync(path.join(root, 'SHOULD_NOT_EXIST')), false);
});
test('invalid config and unsafe identifiers fail before rendering', t => {
  const dir = temp(t), config = path.join(dir, 'bad.env');
  fs.writeFileSync(config, 'UNKNOWN_KEY=value\n');
  const cases = [['--network', 'invalid: network'], ['--domain', 'https://example.com/path'], ['--set', 'TELEMETRY_ENABLED=true'], ['--instance', '../bad'], ['--set', 'SMTP_PORT=99999'], ['--config', shellPath(config)], ['--set', 'PATH=untrusted'], ['--config']];
  for (const args of cases) {
    const r = run(['RupturSetup', '--check-config', ...args]);
    assert.notEqual(r.status, 0, args.join(' '));
  }
});
test('interactive SMTP override derives login from partner email and hides password', t => {
  const driver = path.join(temp(t), 'prompt.sh');
  fs.writeFileSync(driver, 'RUPTUR_ROOT=$PWD\nsource lib/config.sh\nsource lib/chatwoot.sh\nruptur_config_init\nruptur_chatwoot_inputs || exit 1\nprintf "USER=%s\\nBRAND=%s\\n" "$user_smtp_chatwoot" "$nome_empresa_chatwoot"\n');
  const r = run([shellPath(driver)], {}, 'support.partner.example\nPartner Chat\nmail@partner.example\n\nsupersecret\nsmtp.partner.example\n587\n');
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /USER=mail@partner.example/);
  assert.doesNotMatch(r.stdout + r.stderr, /supersecret/);
});

test('failed download preserves destination and reports failure', t => {
  const dir = temp(t), output = path.join(dir, 'asset'), driver = path.join(dir, 'download.sh');
  fs.writeFileSync(output, 'original');
  fs.writeFileSync(driver, 'source lib/config.sh\nsource lib/downloads.sh\ncurl() { return 22; }\nruptur_download https://example.com/asset "$TEST_OUTPUT"\n');
  const r = run([shellPath(driver)], { TEST_OUTPUT: shellPath(output) });
  assert.notEqual(r.status, 0);
  assert.equal(fs.readFileSync(output, 'utf8'), 'original');
  assert.deepEqual(fs.readdirSync(dir).sort(), ['asset', 'download.sh']);
});

test('Grafana resources render on a fresh directory with partner branding', t => {
  const dir = temp(t), output = path.join(dir, 'monitor'), driver = path.join(dir, 'grafana.sh');
  const tools = shellPath(path.join(__dirname, 'node_modules', '.bin'));
  const check = run(['-c', 'PATH="$TEST_TOOLS:$PATH"; command -v jq'], { TEST_TOOLS: tools });
  if (check.status !== 0) { t.skip('Instale jq para verificar a renderização Grafana'); return; }
  fs.writeFileSync(driver, 'RUPTUR_ROOT=$PWD\nPATH="$TEST_TOOLS:$PATH"\nsource lib/config.sh\nsource lib/templates.sh\nsource lib/grafana.sh\nruptur_config_init\nurl_nodeexporter=node.partner.example\nruptur_grafana_resources "$TEST_OUTPUT"\n');
  const r = run([shellPath(driver)], { TEST_TOOLS: tools, TEST_OUTPUT: shellPath(output), BRAND_NAME: "Partner's Team", BASE_URL: 'https://partner.example', VIDEO_URL: 'https://videos.partner.example' });
  assert.equal(r.status, 0, r.stderr);
  const dashboard = JSON.parse(fs.readFileSync(path.join(output, 'grafana/dashboards/dashboard.json'), 'utf8'));
  const provision = YAML.parse(fs.readFileSync(path.join(output, 'grafana/provisioning/dashboards/dashboard.yml'), 'utf8'));
  assert.equal(provision.providers[0].name, "Monitor Partner's Team");
  const serialized = JSON.stringify(dashboard);
  assert.ok(serialized.includes('https://partner.example'));
  assert.ok(serialized.includes('node.partner.example'));
  assert.ok(serialized.includes("Partner's Team"));
  assert.doesNotMatch(serialized, /@@/);
});

test('shared SMTP prompts retain the entered sender as default login', t => {
  const driver = path.join(temp(t), 'smtp.sh');
  fs.writeFileSync(driver, 'RUPTUR_ROOT=$PWD\nsource lib/config.sh\nruptur_config_init\nruptur_smtp_prompt from mail "Remetente"\nruptur_smtp_prompt user login "Login"\nprintf "%s\\n" "$login"\n');
  const r = run([shellPath(driver)], {}, 'sender@partner.example\n\n');
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /sender@partner.example/);
});
