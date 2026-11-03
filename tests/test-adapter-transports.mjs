import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve, delimiter } from 'node:path';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';

const resolver = resolve('scripts/resolve-model-routing.ps1');
const flags = '--model --effort --permission-mode --tools --strict-mcp-config --mcp-config --no-session-persistence --print --available-tools --deny-tool --disable-builtin-mcps --no-auto-update --no-ask-user --prompt --variant --agent';

async function withFixture(run) {
  const dir = await mkdtemp(join(tmpdir(), 'routing-transport-'));
  try {
    for (const cli of ['claude', 'copilot', 'opencode']) {
      const windows = process.platform === 'win32';
      await writeFile(join(dir, cli + (windows ? '.cmd' : '')), windows
        ? `@echo off\r\necho fixture 1.0 ${flags}\r\n`
        : `#!/bin/sh\nprintf '%s\\n' 'fixture 1.0 ${flags}'\n`, { mode: 0o755 });
    }
    const execute = args => new Promise((resolveResult, reject) => {
      const child = spawn('pwsh', ['-NoProfile', '-File', resolver, ...args, '-OutputFormat', 'Json', '-ConfigPath', join(dir, 'profiles.json')], {
        env: { ...process.env, PATH: dir + delimiter + process.env.PATH },
      });
      let out = ''; let err = '';
      child.stdout.on('data', x => { out += x; }); child.stderr.on('data', x => { err += x; });
      child.on('error', reject);
      child.on('close', code => resolveResult({ code, out, err, result: JSON.parse(out) }));
    });
    await run({ dir, execute });
  } finally { await rm(dir, { recursive: true, force: true }); }
}

test('actual Node/PowerShell bridge transports Claude and Copilot metadata without inference', async () => {
  await withFixture(async ({ dir, execute }) => {
    const modulePath = join(dir, 'sdk.mjs');
    await writeFile(modulePath, `
      export function query({prompt, options}) {
        if (typeof prompt !== 'object' || options.persistSession !== false) throw Error('unsafe');
        return { supportedModels: async () => [
          {value:'sonnet', supportsEffort:true, supportedEffortLevels:['high','medium']}
        ], close() {} };
      }
      export const RuntimeConnection = {forStdio: x => x};
      export class CopilotClient {
        async start() {}
        async listModels() { return [
          {id:'gpt-99',policy:{state:'enabled'},capabilities:{supports:{reasoningEffort:true}},supportedReasoningEfforts:['high']},
          {id:'gpt-99-mini',policy:{state:'enabled'},capabilities:{supports:{reasoningEffort:false}}}
        ]; }
        async stop() {}
      }
    `);
    for (const family of ['Claude', 'Copilot']) {
      const reply = await execute(['-Action', 'Refresh', '-Harness', family, '-SdkModulePath', modulePath]);
      assert.equal(reply.code, 0, reply.out + reply.err);
      assert.equal(reply.result.roles.length, 4);
      assert.equal(reply.result.roles[0].model, family === 'Claude' ? 'sonnet' : 'gpt-99');
    }
    const before = await readFile(join(dir, 'profiles.json'), 'utf8');
    await writeFile(modulePath, 'throw Error("fixture-private-token-must-not-leak");');
    const blocked = await execute(['-Action', 'Refresh', '-Harness', 'Claude', '-SdkModulePath', modulePath]);
    assert.equal(blocked.code, 3);
    assert.equal(blocked.result.status, 'Blocked');
    assert.doesNotMatch(blocked.out + blocked.err, /fixture-private-token/);
    assert.equal(await readFile(join(dir, 'profiles.json'), 'utf8'), before);
    await writeFile(modulePath, `
      console.log('fixture-private-token-must-not-leak');
      export function query() { return { supportedModels: async () => [], close() {} }; }
    `);
    const malformed = await execute(['-Action', 'Refresh', '-Harness', 'Claude', '-SdkModulePath', modulePath]);
    assert.equal(malformed.code, 3);
    assert.doesNotMatch(malformed.out + malformed.err, /fixture-private-token/);
    assert.equal(await readFile(join(dir, 'profiles.json'), 'utf8'), before);
  });
});

test('OpenCode reads only loopback provider endpoint and filters the explicit connected provider', async () => {
  const requests = [];
  let connected = ['anthropic'];
  let redirect = false;
  const server = createServer((req, res) => {
    requests.push(req.url);
    if (redirect) { res.writeHead(302, { Location: 'http://example.invalid/provider' }); res.end(); return; }
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ connected, all: [{ id: 'anthropic', models: {
      pro: {id:'gemini-99-pro',capabilities:{reasoning:true},variants:{high:{}}},
      flash: {id:'gemini-99-flash',capabilities:{reasoning:false}},
    } }, {id:'other',models:{opus:{id:'claude-opus-99',capabilities:{reasoning:true},variants:{high:{}}}}}] }));
  });
  await new Promise(resolveListen => server.listen(0, '127.0.0.1', resolveListen));
  try {
    await withFixture(async ({ execute, dir }) => {
      const origin = `http://127.0.0.1:${server.address().port}`;
      const args = ['-Action','Refresh','-Harness','OpenCode','-OpenCodeServerUrl',origin,'-OpenCodeProvider','anthropic'];
      const reply = await execute(args);
      assert.equal(reply.code, 0, reply.out + reply.err);
      assert.equal(reply.result.roles[0].model, 'anthropic/gemini-99-pro');
      const before = await readFile(join(dir, 'profiles.json'), 'utf8');
      connected = [];
      assert.equal((await execute(args)).code, 3);
      connected = ['anthropic']; redirect = true;
      assert.equal((await execute(args)).code, 3);
      assert.equal(await readFile(join(dir, 'profiles.json'), 'utf8'), before);
      for (const url of ['http://example.invalid', origin + '/path', origin + '?token=secret', 'http://user:secret@127.0.0.1']) {
        const denied = await execute(['-Action','Status','-Harness','OpenCode','-OpenCodeServerUrl',url,'-OpenCodeProvider','anthropic']);
        assert.equal(denied.code, 3);
        assert.doesNotMatch(denied.out + denied.err, /token=secret|user:secret/);
      }
      assert.deepEqual(requests, ['/provider', '/provider', '/provider']);
    });
  } finally { await new Promise(close => server.close(close)); }
});
