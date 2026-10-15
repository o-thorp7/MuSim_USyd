#!/usr/bin/env python3
"""Read-only ERA5 monitoring; writes only a PNG and text report in monitoring/.

No CDS requests, Slurm mutations, NetCDF reads, or changes to simulation data.
File mtimes measure output arrivals, not scientific validity or network bandwidth.
Run: python check_era5_speed.py                      (1-hour bins)
     python check_era5_speed.py --interval-min 30    (30-min bins)
"""
import argparse
from collections import Counter
from datetime import datetime
import os
from pathlib import Path
import re
import time

PRODUCTS = ('era5_hires_land', 'era5_hires_plvl', 'era5_ensem_land', 'era5_ensem_plvl')
DEFAULT_RUN = '/users/PAS2635/zyin8122/MuSim_USyd/sep29_oct09_2026_results'


def scan_files(raw):
    found = {p: [] for p in PRODUCTS}
    zeros = 0
    for product in PRODUCTS:
        for path in (raw/product).glob(product + '_*.nc'):
            try:
                st = path.stat()
                if not path.is_file():
                    continue
                if st.st_size:
                    found[product].append(st.st_mtime)
                else:
                    zeros += 1
            except FileNotFoundError:
                pass
    return found, zeros


def count_window(values, start, end):
    return sum(start <= value < end for value in values)


def rate(values, start, end):
    return count_window(values, start, end) * 3600 / (end-start) if end > start else 0.0


def hour_bins(values, start, now, width=3600):
    # Epoch-aligned bins of `width` seconds. Widths that divide 3600 (10, 15,
    # 20, 30, 60 min) line up with the clock for whole-hour UTC offsets.
    first, last = int(start//width)*width, int(now//width)*width
    counts = Counter(int(v//width)*width for v in values if v <= now)
    return [(h, counts[h], h+width <= now) for h in range(first, last+1, width)]


def log_tail(path):
    if not path.exists():
        return ''
    with path.open('rb') as handle:
        handle.seek(0, 2)
        length = handle.tell()
        handle.seek(max(0, length-524288))
        return handle.read().decode('utf-8', errors='replace')


def fmt(t):
    return datetime.fromtimestamp(t).astimezone().strftime('%Y-%m-%d %H:%M:%S %Z') if t is not None else 'unknown'


def draw(found, start, now, width, label, output):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    from zoneinfo import ZoneInfo

    # Use the machine's named time zone for correct OSC date labels across DST.
    try:
        tz = ZoneInfo(os.environ.get('TZ', '').lstrip(':') or 'America/New_York')
    except (ValueError, KeyError):
        tz = datetime.now().astimezone().tzinfo
    all_times = sorted(t for timestamps in found.values() for t in timestamps)
    rows = hour_bins(all_times, start, now, width)
    complete = [(h,n) for h,n,done in rows if done]
    fig, axes = plt.subplots(2, 1, figsize=(12,8), sharex=True, constrained_layout=True)
    color = '#185da6'
    for axis in axes:
        axis.grid(axis='y', alpha=0.22)
        current = int(now//width)*width
        axis.axvspan(datetime.fromtimestamp(current,tz), datetime.fromtimestamp(current+width,tz), color='#f4d58d', alpha=0.25)
    xs = [datetime.fromtimestamp(h+width/2,tz) for h,n in complete]
    axes[0].plot(xs, [n for h,n in complete], '-o', color=color, markersize=4, label='All four products')
    partial = rows[-1][1]
    axes[0].text(.01,.97, f'Current {label} interval: {partial} files so far (not plotted as a full-interval count)',
                 transform=axes[0].transAxes, va='top', fontsize=10)
    axes[0].set_title(f'ERA5 download output speed — every completed {label} interval')
    axes[0].set_ylabel(f'Files / {label}')
    axes[0].legend(loc='upper right')
    for product in PRODUCTS:
        per_hour = {h:n for h,n,done in hour_bins(found[product],start,now,width)}
        axes[1].plot(xs,[per_hour[h] for h,n in complete],'-o',markersize=3,label=product.replace('era5_',''))
    # Set the lower bound only AFTER plotting; setting limits before plotting
    # disables autoscaling and would incorrectly clip values above one.
    for axis in axes:
        axis.relim()
        axis.autoscale_view()
        axis.set_ylim(bottom=0)
    axes[1].set_ylabel(f'Files / {label} by product')
    axes[1].legend(ncol=3, fontsize=9, loc='upper left')
    locator = mdates.AutoDateLocator(minticks=5,maxticks=12,tz=tz)
    axes[1].xaxis.set_major_locator(locator)
    axes[1].xaxis.set_major_formatter(mdates.DateFormatter('%m-%d\n%H:%M',tz=tz))
    axes[1].set_xlabel('OSC local time; points centred on each interval. Gold = incomplete current interval.')
    fig.suptitle('Counts from non-empty .nc file modification times; not a data-integrity check', fontsize=11)
    fig.savefig(output,dpi=160)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-dir',type=Path,default=Path(DEFAULT_RUN))
    parser.add_argument('--job',default='56164651', help='job ID used only to find the batch log')
    parser.add_argument('--interval-min',type=float,default=60,
                        help='bin size in minutes (e.g. 60, 30, 20, 10)')
    parser.add_argument('--self-test',action='store_true')
    args = parser.parse_args()
    if args.self_test:
        assert count_window([0,3599,3600,7200],0,3600)==2
        assert rate([1,3599],0,3600)==2
        assert hour_bins([1,3599,3600,7201],0,7300)==[(0,2,True),(3600,1,True),(7200,1,False)]
        assert hour_bins([1,1799,1800],0,2000,1800)==[(0,2,True),(1800,1,False)]
        print('PASS: interval boundaries, partial-interval handling, rate calculation.')
        return
    if args.interval_min <= 0:
        raise SystemExit('--interval-min must be positive')
    width = int(round(args.interval_min*60))
    label = f'{args.interval_min:g} min'
    now = time.time()
    if not (args.run_dir/'raw').is_dir():
        raise SystemExit(f'Raw directory not found: {args.run_dir / "raw"}')
    found, zeros = scan_files(args.run_dir/'raw')
    all_times = sorted(t for values in found.values() for t in values)
    chart_start = min(all_times+[now])
    log = log_tail(args.run_dir/'logs'/f'log.prep_batched_{args.job}.out')
    lines = []
    def say(message='', echo=True):
        lines.append(str(message))
        if echo:
            print(message, flush=True)
    say(f'Checked: {fmt(now)}')
    say(f'Raw directory: {args.run_dir / "raw"}')
    say(f'Non-empty .nc files: {len(all_times)}/1412; zero-size files: {zeros}')
    say(f'\nEVERY {label.upper()} INTERVAL:', echo=False)
    say('Interval beginning (OSC local)   Files   Coverage', echo=False)
    for h,n,complete in hour_bins(all_times,chart_start,now,width):
        coverage = f'full {label} interval' if complete else 'CURRENT: incomplete; not extrapolated'
        if complete and chart_start > h:
            coverage = 'first interval: observation starts partway through'
        say(f'{datetime.fromtimestamp(h).astimezone():%m-%d %H:%M %z}         {n:5d}   {coverage}', echo=False)
    # say('\nBATCH LOG EVIDENCE (last 512 KiB):')
    # if not log:
    #     say('Log not created yet, empty, or unavailable.')
    # events = [line for line in log.splitlines() if re.search(
    #     r'REQUEST |Saved |CDS size limit|FAILED |Traceback|Error:|status has been updated|Retrying|HTTP error|Downloads complete|Total planned CDS requests|density processing blocked|No space|Disk quota|oom.kill',line,re.I)]
    # saves = set(re.findall(r'^Saved (\S+)',log,re.M))
    # say(f'Unique Saved messages in this log tail: {len(saves)}')
    # for line in events[-16:]:
    #     say(re.sub(r'https?://\S+','[URL omitted]',line)[:400])
    say('\nNo job/data/config changes or CDS requests were made. Only monitoring reports are written.')
    say('Mtimes are file arrivals, not validation; restored/copied files can distort historical rates.')
    outdir = args.run_dir/'monitoring'
    outdir.mkdir(parents=True,exist_ok=True)
    tag = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    report = outdir/f'download_speed_{tag}.txt'
    png = outdir/f'download_speed_{tag}.png'
    try:
        draw(found,chart_start,now,width,label,png)
        say(f'Interval graph: {png}')
    except ImportError:
        say('Plot unavailable: matplotlib is missing from this Python environment. Text report still saved.')
    say(f'Text report: {report}')
    report.write_text('\n'.join(lines)+'\n')


if __name__ == '__main__':
    main()