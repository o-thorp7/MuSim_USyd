#!/usr/bin/env python

#!/usr/bin/env python

from MCEq.geometry.density_profiles import *
import numpy as np

from MCEq.core import MCEqRun
import crflux.models as pm

from scipy import interpolate
import sys

from scipy import stats
import geopy.distance
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

print("these are my args", sys.argv)
#this_h = float(sys.argv[1])
#this_theta = 90-np.degrees(np.arctan2(this_h, 10.5))
this_fpath = str(sys.argv[1])
this_theta = float(sys.argv[2])
#simnum = int(sys.argv[1])
outpath = str(sys.argv[3])
#this_fpath = outpath+'/splines/avg_spline_%s.npy'%(str(simnum).zfill(5))
#this_fpath = '/users/PAS0654/wluszczak/ensda/splines/avg_spline_%s.npy'%(str(simnum).zfill(5))
print("this_fpath", this_fpath)
t1 = time.time()

regc_atmosphere = CorsikaAtmosphere("USStd", None)
t_atmosphere = TestAtmosphere("USStd", None, fpath=this_fpath)

print("Defining run")
mceq_run = MCEqRun(
        interaction_model='SIBYLL23E',
        # added by oli:
        # interaction_model='SIBYLL2.3c',
        primary_model=(pm.HillasGaisser2012, "H3a"),
        theta_deg=0.
        )
print("Setting density model")
mceq_run.set_density_model(t_atmosphere)
#mceq_run.set_density_model(regc_atmosphere)
e_grid = mceq_run.e_grid

# added by oli
np.save("egrid.npy", e_grid)
#

eints = []
thetas = [this_theta]
#thetas = np.linspace(85,88,9)
#thetas = np.linspace(40,50,18)
#thetas = np.arccos(np.linspace(1,0,11))*180./np.pi

for theta in thetas:
    print(theta)
    mceq_run.set_theta_deg(theta)
    mceq_run.solve()

    mag = 0

    muflux = mceq_run.get_solution('total_mu+', mag) + \
                           mceq_run.get_solution('total_mu-', mag)
    #emask = np.where((e_grid>0.1) & (e_grid<1e1))
    #eint = np.sum(muflux[emask])
    eints.append(muflux)

muflux = eints[0]

#np.save(outpath+'/output/%s/muflux_%s_%s.npy'%(str(simnum).zfill(5), str(simnum).zfill(5), str(this_theta).zfill(4)), muflux)
np.save(outpath, muflux)
t2 = time.time()
print("run time:", t2-t1)
