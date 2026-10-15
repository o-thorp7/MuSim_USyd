#!/usr/bin/env python

from MCEq.geometry.density_profiles import *
import numpy as np

from MCEq.core import MCEqRun
import crflux.models as pm

from scipy import interpolate
import sys
import os
from pathlib import Path

from scipy import stats
# import geopy.distance
import time

class TestAtmosphere(CorsikaAtmosphere):
    def __init__(self, location, season=None, phis=np.arange(0,10,1), fpath=None):
        cka_atmospheres = [
            ("USStd", None),
            ("BK_USStd", None),
            ("Karlsruhe", None),
            ("ANTARES/KM3NeT-ORCA", "Summer"),
            ("ANTARES/KM3NeT-ORCA", "Winter"),
            ("KM3NeT-ARCA", "Summer"),
            ("KM3NeT-ARCA", "Winter"),
            ("KM3NeT", None),
            ("SouthPole", "December"),
            ("PL_SouthPole", "January"),
            ("PL_SouthPole", "August"),
        ]
        assert (
            location,
            season,
        ) in cka_atmospheres, "{0}/{1} not available for CorsikaAtmsophere".format(
            location, season
        )
        self.init_parameters(location, season)
        # added by oli
        import MCEq.geometry.corsikaatm as corsika_acc
        # import MCEq.geometry.corsikaatm.corsikaatm as corsika_acc

        self.corsika_acc = corsika_acc
        self.phis = phis
        EarthsAtmosphere.__init__(self)
        self.fpath = fpath
        self.slicespline = self.make_avg_spline(self.fpath)

    def get_density(self, h_cm):
        """Returns the density of air in g/cm**3.

        Uses the optimized module function :func:`corsika_get_density_jit`.

        Args:
          h_cm (float): height in cm

        Returns:
          float: density :math:`\\rho(h_{cm})` in g/cm**3
        """
        xpos = h_cm*np.tan(self.thrad)*1e-5
        centerx = 0.
        xdist = np.abs(xpos-centerx)
        rdist = np.sqrt(xdist**2)
        h = h_cm*1e-5

        density = self.slicespline(xpos, h)*0.001
        if np.isnan(density):
            density = self.corsika_acc.corsika_get_density(h_cm, *self._atm_param)
        else:
            pass

        return density 

    def make_avg_spline(self, fpath):
        spline_data = np.load(fpath)
        plt_x = spline_data[0]
        plt_z = spline_data[1]
        slice_avg = spline_data[2]

        avg_spline = interpolate.LinearNDInterpolator(list(zip(plt_x, plt_z)), slice_avg, rescale=True)
        return avg_spline

# print("these are my args", sys.argv)
print("these are my args", sys.argv)

if len(sys.argv) != 4:
    raise SystemExit(
        "Usage: muflux_calc.py <spline_file> <output_directory> <timestamp>"
    )

spline_file = str(sys.argv[1])
output_dir = Path(sys.argv[2])
timestamp = str(sys.argv[3])

output_dir.mkdir(parents=True, exist_ok=True)

theta_min = float(os.environ.get("THETA_MIN", 5))
theta_max = float(os.environ.get("THETA_MAX", 81))
theta_step = float(os.environ.get("THETA_STEP", 5))

# Preserve all 16 simulations: 5, 10, ..., 80 degrees.
thetas = np.arange(theta_min, theta_max, theta_step)

t1 = time.time()

t_atmosphere = TestAtmosphere(
    "USStd",
    None,
    fpath=spline_file,
)

print("Defining MCEq run")

mceq_run = MCEqRun(
    interaction_model="SIBYLL23E",
    primary_model=(pm.HillasGaisser2012, "H3a"),
    theta_deg=float(thetas[0]),
)

print("Setting density model")
mceq_run.set_density_model(t_atmosphere)

e_grid = mceq_run.e_grid
egrid_outfile = output_dir / "egrid.npy"

# Multiple jobs may reach this section simultaneously.
# Write through a job-specific temporary file.
if not egrid_outfile.exists():
    temporary_egrid = output_dir / f".egrid_{os.getpid()}.npy"
    np.save(temporary_egrid, e_grid)
    os.replace(temporary_egrid, egrid_outfile)
    print(f"Saved energy grid to {egrid_outfile}")

for theta in thetas:
    outfile = output_dir / f"muflux_{timestamp}_{theta:g}.npy"

    if outfile.exists() and outfile.stat().st_size > 0:
        print(f"Already exists, skipping: {outfile}")
        continue

    print(f"Solving theta={theta:g}")

    mceq_run.set_theta_deg(float(theta))
    mceq_run.solve()

    muflux = (
        mceq_run.get_solution("total_mu+", 0)
        + mceq_run.get_solution("total_mu-", 0)
    )

    np.save(outfile, muflux)
    print(f"Saved {outfile}")

print("Total run time:", time.time() - t1)
