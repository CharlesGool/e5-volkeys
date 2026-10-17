// SPDX-License-Identifier: GPL-2.0
/*
 * e5_keywake: keys masked at their interrupt controller, so that they neither
 * reach userspace nor wake the system from suspend.
 *
 * The E5's keys are gpio-keys without linux,can-disable, so its disabled_keys
 * refuses them; and that would not do anyway: it disables with disable_irq(),
 * which is lazy -- the line stays unmasked until an interrupt comes in.  The
 * power and volume + keys are on the PMIC's EIC, whose interrupts are nested
 * (handle_nested_irq), and a nested interrupt is never masked on the way in:
 * the key goes on raising the PMIC's interrupt, which wakes the system (the
 * sprd GPIO and EIC chips are IRQCHIP_SKIP_SET_WAKE: an interrupt left
 * unmasked wakes it).  So this disables them itself, with IRQ_DISABLE_UNLAZY,
 * which masks the line at once.
 *
 *   insmod e5_keywake.ko
 *   echo 51,63,64 > /sys/module/e5_keywake/parameters/masked   (exactly these)
 *   echo > /sys/module/e5_keywake/parameters/masked            (none)
 *
 * Unloading unmasks them.  A key masked while held is not seen released: the
 * caller waits for the release.
 */

#include <linux/interrupt.h>
#include <linux/irq.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/mutex.h>
#include <linux/slab.h>
#include <linux/string.h>

#define E5_KEYWAKE_MAX	16

static unsigned int masked[E5_KEYWAKE_MAX];
static int nr_masked;
static DEFINE_MUTEX(masked_lock);

static bool in(const unsigned int *list, int n, unsigned int irq)
{
	int i;

	for (i = 0; i < n; i++)
		if (list[i] == irq)
			return true;
	return false;
}

static void mask_one(unsigned int irq)
{
	irq_set_status_flags(irq, IRQ_DISABLE_UNLAZY);
	disable_irq(irq);
	irq_clear_status_flags(irq, IRQ_DISABLE_UNLAZY);
}

static int masked_set(const char *val, const struct kernel_param *kp)
{
	unsigned int want[E5_KEYWAKE_MAX], irq;
	char *buf, *p, *tok;
	int nr_want = 0, i, ret = 0;

	buf = kstrdup(val, GFP_KERNEL);
	if (!buf)
		return -ENOMEM;
	p = buf;
	while ((tok = strsep(&p, ", \n")) != NULL) {
		if (!*tok)
			continue;
		if (kstrtouint(tok, 10, &irq) || !irq_get_irq_data(irq)) {
			ret = -EINVAL;
			break;
		}
		if (in(want, nr_want, irq))
			continue;
		if (nr_want == E5_KEYWAKE_MAX) {
			ret = -ENOSPC;
			break;
		}
		want[nr_want++] = irq;
	}
	kfree(buf);
	if (ret)
		return ret;

	mutex_lock(&masked_lock);
	for (i = 0; i < nr_masked; i++)
		if (!in(want, nr_want, masked[i])) {
			enable_irq(masked[i]);
			pr_info("e5_keywake: irq %u unmasked\n", masked[i]);
		}
	for (i = 0; i < nr_want; i++)
		if (!in(masked, nr_masked, want[i])) {
			mask_one(want[i]);
			pr_info("e5_keywake: irq %u masked\n", want[i]);
		}
	memcpy(masked, want, sizeof(want[0]) * nr_want);
	nr_masked = nr_want;
	mutex_unlock(&masked_lock);
	return 0;
}

static int masked_get(char *buf, const struct kernel_param *kp)
{
	int i, n = 0;

	mutex_lock(&masked_lock);
	for (i = 0; i < nr_masked; i++)
		n += sysfs_emit_at(buf, n, "%s%u", i ? "," : "", masked[i]);
	mutex_unlock(&masked_lock);
	n += sysfs_emit_at(buf, n, "\n");
	return n;
}

static const struct kernel_param_ops masked_ops = {
	.set = masked_set,
	.get = masked_get,
};
module_param_cb(masked, &masked_ops, NULL, 0644);
MODULE_PARM_DESC(masked, "interrupts kept masked (comma-separated; empty: none)");

static int __init e5_keywake_init(void)
{
	return 0;
}

static void __exit e5_keywake_exit(void)
{
	int i;

	mutex_lock(&masked_lock);
	for (i = 0; i < nr_masked; i++)
		enable_irq(masked[i]);
	nr_masked = 0;
	mutex_unlock(&masked_lock);
}

module_init(e5_keywake_init);
module_exit(e5_keywake_exit);

MODULE_DESCRIPTION("E5: keys masked at the interrupt controller, so they do not wake the system");
MODULE_LICENSE("GPL");
