/* BEGIN e5-volkeys (the volkeys app, /etc/e5-infoscreen/plugins/volkeys) */
// What the volume keys do, as the volkeys app sets it (its GET /mode):
// "brightness" steps the backlight, "power" turns the screen on and off as the
// power key does, "volume" is the screen's own volumeKey (volumeKeyOrig).
// During a call, or with the app removed (no /mode), they stay volume keys.
let volkeysMode = null, volkeysAt = -Infinity, volkeysLast = -Infinity, volkeysRepeat = false;
// whether this press is a held key's repeat: volumeKey(step) is not told, so
// it is taken from the event first (these listeners are added before the
// screen's own, for its keys and for those a plugin frame passes on)
document.addEventListener('keydown', (e) => { volkeysRepeat = !!e.repeat; });
window.addEventListener('message', (e) => {
	if (e.data && typeof e.data == 'object' && e.data.e5 === 'key') volkeysRepeat = !!e.data.repeat;
});
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
	const m = await volkeysGet();
	if (m.mode === 'power') {
		if (repeat) return;                         // held down: one press
		setBlank(!blank);
		return;
	}
	if (m.mode === 'brightness') {
		if (repeat && now - volkeysLast < 150) return;   // held down: a step per 150 ms
		volkeysLast = now;
		if (blank) { if (!repeat) setBlank(false); return; }   // dark: the first press only wakes it
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
