const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const html = fs.readFileSync(path.join(__dirname, '../lib/tree_doc/web/index.html'), 'utf8');
const source = html.split('<script>')[1].split('// --- views')[0];

function client(fetch) {
  const elements = new Map();
  function element(id) {
    if (!elements.has(id)) {
      const e = new EventTarget();
      Object.assign(e, {value: '', disabled: true, hidden: false, selectionStart: 0, selectionEnd: 0,
        setSelectionRange(s, end) {this.selectionStart = s; this.selectionEnd = end;}});
      const classes = new Set();
      e.classList = {add: x => classes.add(x), remove: x => classes.delete(x), contains: x => classes.has(x)};
      elements.set(id, e);
    }
    return elements.get(id);
  }
  const context = vm.createContext({document: {getElementById: element}, window: new EventTarget(),
    fetch, AbortSignal, setTimeout: () => 1, clearTimeout() {}});
  vm.runInContext(source, context);
  return {run: code => vm.runInContext(code, context), ta: element('ta'), element};
}
const snapshot = (text, seq = 0) => ({seq, chars: Array.from(text, (ch, i) => ({ch, id: [[1, i + 1, 'a']]}))});
const reply = (st, ok = true) => ({ok, json: async () => st});

test('initial snapshot loads before editing is enabled', async () => {
  const c = client(async () => reply(snapshot('saved', 5)));
  await c.run('sync()');
  assert.equal(c.ta.value, 'saved');
  assert.equal(c.ta.disabled, false);
});

test('Unicode diff addresses complete atoms', () => {
  const c = client(() => {});
  const result = c.run("editFor([{id:[1],ch:'👩‍💻'}, {id:[2],ch:'é'}], '👩‍💻X')");
  assert.equal(JSON.stringify(result), JSON.stringify({del: [[2]], after: [1], ins: 'X'}));
});

test('typing during a POST is retained on top of remote additions', async () => {
  let resolve;
  const c = client(() => new Promise(r => {resolve = r;}));
  c.ta.value = 'a';
  const pending = c.run('sync()');
  c.ta.value = 'ab';
  resolve(reply(snapshot('Xa', 1)));
  await pending;
  assert.equal(c.ta.value, 'Xab');
  assert.equal(c.run('base'), 'Xa');
});

test('a rejected edit keeps the draft and pauses instead of adopting server text', async () => {
  const c = client(async () => reply({...snapshot('old'), error: 'storage failed'}, false));
  c.ta.value = 'draft';
  await c.run('sync()');
  assert.equal(c.ta.value, 'draft');
  assert.equal(c.run('paused'), true);
  assert.equal(c.element('reload').hidden, false);
});

test('network failure retains the same author sequence for a safe retry', async () => {
  let body;
  const c = client(async (_, opts) => {body = JSON.parse(opts.body); throw Error('offline');});
  c.ta.value = 'draft';
  await c.run('sync()');
  assert.equal(c.ta.value, 'draft');
  assert.equal(c.run('seq'), 0);
  assert.equal(body.seq, 0);
  assert.equal(c.run('fails'), 1);
});

test('a reply waits for IME composition to end before replacing the textarea', async () => {
  let resolve;
  const c = client(() => new Promise(r => {resolve = r;}));
  c.ta.value = 'a';
  const pending = c.run('sync()');
  c.ta.dispatchEvent(new Event('compositionstart'));
  c.ta.value = 'ab';
  resolve(reply(snapshot('Xa', 1)));
  await new Promise(r => setImmediate(r));
  assert.equal(c.ta.value, 'ab');
  c.ta.dispatchEvent(new Event('compositionend'));
  await pending;
  assert.equal(c.ta.value, 'Xab');
});
