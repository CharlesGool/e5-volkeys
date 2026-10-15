// 音量键功能: the volume keys as brightness or screen power keys.  The keys
// are the screen's own (app.js volumeKey, before any app sees them), so this
// patches app.js with patch.js: volumeKey asks GET /mode on a press and falls
// back to the original (volumeKeyOrig).  An image update brings an unpatched
// app.js: the notification poll (manifest "notifications") patches it again;
// the screen restarts once after each patch, to load it.  Removing the app
// leaves the keys as volume keys (no /mode) until the next update.
//
//   GET  /mode            {mode, step}, for the patched volumeKey
//   GET  /status          the mode, the step, the patch
//   POST /mode            {"mode": "brightness"|"power"|"volume"}
//   POST /unpatch         app.js as it came, the screen restarted
//   GET  /notifications   (none: only the patch check, once a minute)

'use strict';

import { readfile, writefile, rename, stat } from 'fs';

const DIR = '/etc/e5-infoscreen/plugins/volkeys';
const APP = '/usr/share/e5-infoscreen/www/app.js';
const CFG = 'e5-plugin-volkeys';
const ANCHOR = 'async function volumeKey(step) {';
const RENAMED = 'async function volumeKeyOrig(step) {';
const BEGIN = '/* BEGIN e5-volkeys';
const END = '/* END e5-volkeys */\n';
const MODES = [ 'brightness', 'power', 'volume' ];

return function(ctx) {
	function settings() {
		let c = ctx.uci();
		let mode = c.get(CFG, 'settings', 'mode') ?? 'brightness';
		if (index(MODES, mode) < 0) mode = 'brightness';
		let step = int(c.get(CFG, 'settings', 'step') ?? '10');
		if (step < 5 || step > 25) step = 10;
		return { mode, step };
	}

	// app.js without our block, volumeKeyOrig back to volumeKey
	function strip(src) {
		let b = index(src, BEGIN), e = index(src, END);
		if (b < 0 || e < b) return null;
		src = substr(src, 0, b) + substr(src, e + length(END));
		return join(ANCHOR, split(src, RENAMED));
	}

	function restart_screen() {
		// (detached: this request runs in the screen's own API server)
		ctx.run("setsid sh -c 'sleep 2; /etc/init.d/e5-infoscreen restart' >/dev/null 2>&1 &");
	}

	function write_app(src) {
		let tmp = APP + '.volkeys-new';
		if (writefile(tmp, src) == null || !rename(tmp, APP)) {
			ctx.run(`rm -f '${tmp}'`);
			return false;
		}
		return true;
	}

	function patch_state() {
		let src = readfile(APP), want = readfile(`${DIR}/patch.js`);
		if (src == null || want == null) return { patched: false, error: 'missing app.js or patch.js' };
		if (index(src, want) >= 0) return { patched: true, current: true };
		if (index(src, BEGIN) >= 0) return { patched: true, current: false };
		let n = length(split(src, ANCHOR)) - 1;
		return { patched: false, patchable: n == 1, error: n == 1 ? null : 'this screen version has no single volumeKey()' };
	}

	// app.js with this version of patch.js; the screen restarted when it changed
	function ensure_patch() {
		let src = readfile(APP), want = readfile(`${DIR}/patch.js`);
		if (src == null || want == null) return patch_state();
		if (index(src, want) >= 0) return { patched: true, current: true };
		if (index(src, BEGIN) >= 0) {
			src = strip(src);               // an older patch.js: out first
			if (src == null) return { patched: false, error: 'cannot remove the older patch' };
		}
		let parts = split(src, ANCHOR);
		if (length(parts) != 2)
			return { patched: false, error: 'this screen version has no single volumeKey(): not patched' };
		if (!write_app(parts[0] + want + RENAMED + parts[1]))
			return { patched: false, error: 'cannot write app.js' };
		ctx.log('app.js patched, the screen restarts');
		restart_screen();
		return { patched: true, current: true, restarting: true };
	}

	function status() {
		return { ...settings(), patch: patch_state() };
	}

	return {
		'GET /mode': function(req) {
			return settings();
		},
		'GET /status': function(req) {
			ensure_patch();
			return status();
		},
		'POST /mode': function(req) {
			let mode = req.body?.mode;
			if (index(MODES, mode) < 0)
				return { status: 400, type: 'application/json', body: '{"error":"mode: brightness, power or volume"}' };
			if (!stat(`/etc/config/${CFG}`))
				writefile(`/etc/config/${CFG}`, '');
			let c = ctx.uci();
			if (c.get(CFG, 'settings') == null)
				c.set(CFG, 'settings', 'settings');
			c.set(CFG, 'settings', 'mode', mode);
			c.commit(CFG);
			return status();
		},
		'POST /unpatch': function(req) {
			let src = readfile(APP);
			if (src == null || index(src, BEGIN) < 0)
				return status();
			src = strip(src);
			if (src == null || !write_app(src))
				return { status: 500, type: 'application/json', body: '{"error":"cannot restore app.js"}' };
			ctx.log('app.js restored, the screen restarts');
			restart_screen();
			return status();
		},
		'GET /notifications': function(req) {
			if (!ctx.state_get('checked', 60)) {
				ctx.state_put('checked', { at: time() });
				ensure_patch();
			}
			return { notifications: [] };
		}
	};
};
