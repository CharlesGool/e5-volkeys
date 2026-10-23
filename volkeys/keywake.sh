#!/bin/sh
# The keys other than volume +, masked at their interrupt controller while the
# system is in deep sleep (热点省电's) with the screen cut off by volkeys (volume −
# at the lowest level): only volume + wakes it then.  Awake -- the hotspot on,
# say -- nothing is masked (v1.6): the keys do what their settings say (the side
# key switches the hotspot, ...).  keywake/<kernel release>.ko is e5_keywake (its source:
# keywake/ in the app's repository); with no module for the running kernel
# the keys stay as they are.
#
#   keywake.sh on        the screen cut off: the mark, the module loaded
#   keywake.sh off       the cut ended: the mark gone, nothing masked
#   keywake.sh suspend   just before a deep sleep (sleep.sh): with the screen cut
#                        off and none of the keys held, mask them
#   keywake.sh resume    right after it: nothing masked

DIR=/etc/e5-infoscreen/plugins/volkeys
KO=$DIR/keywake/$(uname -r).ko
P=/sys/module/e5_keywake/parameters/masked
KEYS=/sys/devices/platform/gpio-keys/of_node
MARK=/var/run/volkeys.cut
LOCK=/var/lock/volkeys-keywake.lock

# the gpio-keys other than KEY_VOLUMEUP (115): "irq label" lines
keys() {
	local n code label irq
	for n in "$KEYS"/*/; do
		[ -f "$n/linux,code" ] && [ -f "$n/label" ] || continue
		code=$((0x$(od -An -tx1 "$n/linux,code" | tr -d ' \n')))
		[ "$code" = 115 ] && continue
		label=$(tr -d '\0' < "$n/label")
		irq=$(awk -v l=" $label" 'substr($0, length($0) - length(l) + 1) == l { sub(":", "", $1); print $1; exit }' /proc/interrupts)
		[ -n "$irq" ] && echo "$irq $label"
	done
}

# whether one of them is down (/sys/kernel/debug/gpio: its level, active low or not)
held() {
	local irq label line
	grep -q debugfs /proc/mounts || mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null
	while read -r irq label; do
		line=$(grep -F "|$label " /sys/kernel/debug/gpio 2>/dev/null) || continue
		case "$line" in
			*" hi "*"ACTIVE LOW"*) ;;
			*"ACTIVE LOW"*|*" hi "*) return 0 ;;
		esac
	done <<EOF
$(keys)
EOF
	return 1
}

case "$1" in
on)
	touch "$MARK"
	[ -f "$KO" ] || exit 2
	[ -d /sys/module/e5_keywake ] || insmod "$KO" || exit 3
	# (masked for a deep sleep only: see suspend; an older version's mask goes)
	[ -e "$P" ] && ( flock 9; echo > "$P" ) 9>"$LOCK"
	;;
off)
	rm -f "$MARK"
	[ -e "$P" ] || exit 0
	( flock 9; echo > "$P" ) 9>"$LOCK"
	;;
suspend)
	[ -f "$MARK" ] && [ -f "$KO" ] || exit 0
	[ -d /sys/module/e5_keywake ] || insmod "$KO" || exit 3
	irqs=$(keys | cut -d' ' -f1 | tr '\n' ',')
	[ -n "$irqs" ] || exit 4
	# (a key masked while held is never seen released: not this time then)
	held && exit 5
	( flock 9; [ -f "$MARK" ] && echo "${irqs%,}" > "$P" ) 9>"$LOCK"
	;;
resume)
	[ -e "$P" ] || exit 0
	( flock 9; echo > "$P" ) 9>"$LOCK"
	;;
*)
	echo "usage: $0 on|off|suspend|resume" >&2
	exit 1
	;;
esac
