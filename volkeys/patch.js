/* BEGIN e5-volkeys (the volkeys app, /etc/e5-infoscreen/plugins/volkeys) */
// What the volume keys do, as the volkeys app sets it (its GET /mode):
// "brightness" steps the backlight, "power" turns the screen on and off as the
// power key does, "volume" is the screen's own volumeKey (volumeKeyOrig).
// During a call, or with the app removed (no /mode), they stay volume keys.
let volkeysMode = null, volkeysAt = -Infinity, volkeysLast = -Infinity, volkeysRepeat = false, volkeysCut = false;
// whether this press is a held key's repeat: volumeKey(step) is not told, so
// it is taken from the event first.  Capturing, as the screen's own keydown
// listener is: these are added before it, so they run before it (a bubbling
// one ran after, and volumeKey saw the previous key's flag).  The same for
// the keys a plugin frame passes on.
document.addEventListener('keydown', (e) => { volkeysRepeat = !!e.repeat; }, true);
window.addEventListener('message', (e) => {
	if (e.data && typeof e.data == 'object' && e.data.e5 === 'key') volkeysRepeat = !!e.data.repeat;
}, true);
// the other keys masked (POST /cut) while the screen is cut off: they neither
// reach the screen nor wake the system from deep sleep; unmasked at every start
// too, as a screen that restarted has no cut-off screen
function volkeysKeys(on) {
	fetch('/api/plugins/volkeys/cut', { method: 'POST', headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ on }) }).catch(() => {});
}
volkeysKeys(false);
// the screen back from the cut-off, at the lowest level
function volkeysUncut() {
	volkeysCut = false;
	volkeysKeys(false);
	locked = false;
	setBlank(false);
	applyTouch();
	toApp({ e5: 'blank', on: blank });
	toIme({ e5: 'blank', on: blank });
}
async function volkeysGet() {
	if (volkeysMode && performance.now() - volkeysAt < 3000) return volkeysMode;
	try {
		const r = await fetch('/api/plugins/volkeys/mode', { cache: 'no-store' });
		volkeysMode = r.ok ? await r.json() : { mode: 'volume' };
	} catch (e) {
		volkeysMode = { mode: 'volume' };
	}
	volkeysAt = performance.now();
	return volkeysMode;
}
async function volumeKey(step) {
	if (T551MCalls.active()) return volumeKeyOrig(step);
	const repeat = volkeysRepeat, now = performance.now();   // (before any await)
	// cut off by us: volume + gives the screen back, whatever the mode is now
	// and whether or not /mode answers (just woken from deep sleep)
	if (volkeysCut) {
		if (step > 0 && !repeat) volkeysUncut();
		return;
	}
	const m = await volkeysGet();
	if (m.mode === 'power') {
		if (repeat) return;                         // held down: one press
		setBlank(!blank);
		return;
	}
	if (m.mode === 'brightness') {
		if (repeat && now - volkeysLast < 150) return;   // held down: a step per 150 ms
		volkeysLast = now;
		if (blank) {
			if (repeat) return;
			if (locked) return;     // the lock the user set with power-then-*: theirs
			// dark: the first press only wakes it -- volume + only, when volume −
			// at the lowest level is what cuts it off
			if (step > 0 || m.off_at_min === false) setBlank(false);
			return;
		}
		// Down once more at the lowest level (stepBrightness stops at 10): the
		// screen cut off -- the screen's key lock (setLocked: dark, no key,
		// touch or new message lights it, the motor says so), the other keys
		// masked -- until volume +.  A separate press, not a held one.
		if (step < 0 && !repeat && m.off_at_min !== false && brightness <= 10) {
			volkeysCut = true;
			setLocked(true);
			volkeysKeys(true);
			return;
		}
		resetIdle();
		// (the level is set and saved before its page re-renders; the bar
		// below shows whatever that rendering does)
		try { stepBrightness(step * Math.round(255 * (m.step || 10) / 100)); } catch (e) { console.log('volkeys: ' + e); }
		const pct = Math.round(brightness / 255 * 100);
		const osd = $('vol-osd');
		setText('vol-label', lang == 'zh' ? '亮度' : 'Brightness');
		setText('vol-n', pct + '%');
		$('vol-bar').style.width = pct + '%';
		osd.classList.add('show');
		clearTimeout(volTimer);
		volTimer = setTimeout(() => osd.classList.remove('show'), 1500);
		return;
	}
	return volumeKeyOrig(step);
}
/* END e5-volkeys */
