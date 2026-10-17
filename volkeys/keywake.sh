#!/bin/sh
# The keys other than volume +, masked at their interrupt controller while
# volkeys has the screen cut off (volume − at the lowest level): no event
# reaches the screen, and they no longer wake the system from deep sleep
# (热点省电's).  keywake/<kernel release>.ko is e5_keywake (its source:
# keywake/ in the app's repository); with no module for the running kernel
# the keys stay as they are.
#
#   keywake.sh on    mask them, once none of them is held (up to 3 s)
#   keywake.sh off   unmask them

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
	irqs=$(keys | cut -d' ' -f1 | tr '\n' ',')
	[ -n "$irqs" ] || exit 4
	i=0
	while held && [ $i -lt 3 ]; do sleep 1; i=$((i + 1)); done
	# (not if "off" came meanwhile: it removes the mark first)
	( flock 9; [ -f "$MARK" ] && echo "${irqs%,}" > "$P" ) 9>"$LOCK"
	;;
off)
	rm -f "$MARK"
	[ -e "$P" ] || exit 0
	( flock 9; echo > "$P" ) 9>"$LOCK"
	;;
*)
	echo "usage: $0 on|off" >&2
	exit 1
	;;
esac
