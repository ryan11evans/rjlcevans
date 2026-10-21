'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const source = fs.readFileSync(path.join(__dirname, '..', 'shell-detect.js'), 'utf8');

function load(windowValue, userAgent) {
  const context = {
    window: windowValue,
    navigator: { userAgent: userAgent || 'Mozilla/5.0' },
  };
  context.window.navigator = context.navigator;
  vm.createContext(context);
  vm.runInContext(source, context);
  return context;
}

function detect(windowValue, userAgent) {
  const context = load(windowValue, userAgent);
  return context.isVisionSimulatorNativeApp();
}

const desktop = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
const iphone = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1';

assert.strictEqual(detect({}, desktop), false, 'desktop browser');
assert.strictEqual(detect({}, iphone), false, 'iphone safari');
assert.strictEqual(detect({ webkit: {} }, iphone), false, 'safari webkit without message handlers');
assert.strictEqual(detect({ webkit: { messageHandlers: {} } }, iphone), false, 'webview with unrelated handlers');

assert.strictEqual(detect({
  Capacitor: { getPlatform: () => 'ios', isNativePlatform: () => true },
}, desktop), true, 'capacitor ios');

assert.strictEqual(detect({
  Capacitor: { isNativePlatform: () => true },
}, desktop), true, 'older shell with only isNativePlatform');

assert.strictEqual(detect({ Capacitor: {} }, desktop), true, 'partial Capacitor object fails open');

assert.strictEqual(detect({
  Capacitor: {
    getPlatform: () => { throw new Error('not ready'); },
  },
}, desktop), true, 'getPlatform throwing fails open');

assert.strictEqual(detect({
  Capacitor: {
    isNativePlatform: () => { throw new Error('not ready'); },
  },
}, desktop), true, 'isNativePlatform throwing fails open');

assert.strictEqual(detect({
  Capacitor: { getPlatform: () => 'web', isNativePlatform: () => false },
}, desktop), false, 'capacitor web runtime is a browser');

assert.strictEqual(detect({ cordova: {} }, desktop), true, 'cordova');
assert.strictEqual(detect({ CdvPurchase: {} }, desktop), true, 'purchase plugin');
assert.strictEqual(detect({
  webkit: { messageHandlers: { bridge: {} } },
}, iphone), true, 'capacitor bridge handler');

assert.strictEqual(detect({
  get webkit() { throw new Error('denied'); },
}, iphone), true, 'unreadable webkit fails open');

assert.strictEqual(detect({}, 'Mozilla/5.0 Capacitor'), true, 'capacitor user agent');

const crawler = load({}, 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)');
assert.strictEqual(crawler.isVisionSimulatorLinkPreview(), true, 'googlebot');
assert.strictEqual(load({}, iphone).isVisionSimulatorLinkPreview(), false, 'iphone is not a crawler');

const broken = {};
Object.defineProperty(broken, 'Capacitor', { get() { throw new Error('nope'); } });
assert.strictEqual(detect(broken, desktop), true, 'throwing Capacitor access fails open');

console.log('shell-detect: ok');
