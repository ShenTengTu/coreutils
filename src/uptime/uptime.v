import os
import math
import common

#include <time.h>

struct C.tm {
	tm_sec   int
	tm_min   int
	tm_hour  int
	tm_mday  int
	tm_mon   int
	tm_year  int
	tm_wday  int
	tm_yday  int
	tm_isdst int
}

fn C.localtime(t &i64) &C.tm
fn C.time(t &i64) i64

// <stdlib.h>
fn C.strtod(str &char, endptr &&char) f64
fn C.getloadavg(loadavg [3]f64, nelem int) int

fn print_uptime(utmp_buf []C.utmpx) ? {
	// Get uptime
	mut uptime := u64(0)
	fp := C.fopen(&char('/proc/uptime'.str), &char('r'.str))
	if !isnil(fp) {
		buf := []byte{len: 4096}
		unsafe {
			b := C.fgets(&buf[0], 4096, fp)
			if !isnil(b) {
				endptr := &char(0)
				upsecs := C.strtod(&buf[0], &endptr)
				if buf.bytestr() != endptr.vstring() {
					if 0 <= upsecs && upsecs < math.max_f64 {
						uptime = u64(upsecs)
					} else {
						uptime = -1
					}
				}
			}
		}
		C.fclose(fp)
	}
	// Get boot_time
	mut boot_time := u64(0)
	mut entries := u64(0)
	for u in utmp_buf {
		entries += u64(common.is_user_process(u))
		if u.ut_type == C.BOOT_TIME {
			boot_time = u64(u.ut_tv.tv_sec)
		}
	}
	// Printing
	time_now := C.time(0)
	if uptime == 0 {
		if boot_time == 0 {
			return error("couldn't get boot time")
		}
		uptime = u64(time_now) - boot_time
	}
	updays := uptime / 86400
	uphours := (uptime - (updays * 86400)) / 3600
	upmins := (uptime - (updays * 86400) - (uphours * 3600)) / 60
	tmn := C.localtime(&time_now)
	if !isnil(tmn) {
		print(' ${tmn.tm_hour:02}:${tmn.tm_min:02}:${tmn.tm_sec:02} ')
	} else {
		print(' ??:????  ')
	}

	plural := fn (v u64) string {
		if v > 1 {
			return 's'
		}
		return ''
	}

	if uptime == math.max_i64 {
		print('up ???? days ??:??,  ')
	} else {
		if 0 < updays {
			print('up $updays day${plural(updays)}, ${uphours:2}:${upmins:02},  ')
		} else {
			print('up ${uphours:2}:${upmins:02},  ')
		}
	}
	print('$entries user${plural(entries)}')

	avg := [3]f64{}
	loads := C.getloadavg(avg, 3)
	if loads == -1 {
		print('\n')
	} else {
		avg_str := avg[0..3].map('${it:.2f}').join(', ')
		print(',  load average: $avg_str')
		print('\n')
	}
}

fn uptime(filename &char, options common.ReadUtmpOptions) ? {
	mut utmp_buf := []C.utmpx{}
	common.read_utmp(filename, mut utmp_buf, options)
	print_uptime(utmp_buf) ?
}

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application('uptime')
	fp.description('Tell how long the system has been running.')
	fp.limit_free_args_to_exactly(0)
	opt_pretty := fp.bool('pretty', `p`, false, 'show uptime in pretty format')
	opt_since := fp.bool('since', `s`, false, 'system up since, in yyyy-mm-dd HH:MM:SS format')
	fp.remaining_parameters()

	// Main functionality
	if opt_since {
		// uptime (argv[optind], 0)
		exit(0)
	}

	if opt_pretty {
		// uptime (argv[optind], 0)
		exit(0)
	}

	uptime(&char(C._PATH_UTMP), .check_pids) or {
		common.exit_with_error_message(fp.application_name, err.msg)
	}
}
