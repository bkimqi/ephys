# helper functions
import numpy as np
import datetime
import math
import numpy as np
import math

def pretty_plot(ax):
    """Generic function to make plot pretty, bare bones for now, will need updating"""
    # TODO: move this into a plot_function helper module or something similar
    # set ylims to min/max, rounded to nearest 10
    ylims_round = np.round(ax.get_ylim(), decimals=-1)
    ax.set_yticks(ylims_round)
    ax.set_yticklabels([f'{lim:g}' for lim in iter(ylims_round)])

    # turn off top and right axis lines
    ax.spines['right'].set_visible(False)
    ax.spines['top'].set_visible(False)

    return ax


def set_ytick_units(ax, unit):
    """Set tick units on y-axis, e.g. unit=100 will label 0, 100, 200, etc."""
    order_mag = math.floor(math.log10(unit))
    # ylims_round = [int(np.round(lim, decimals=-order_mag)) for lim in ax.get_ylim()]
    ylims_round = [int(np.floor(ax.get_ylim()[0]/unit)*unit), int(np.ceil(ax.get_ylim()[1]/unit)*unit)]
    ax.set_yticks(np.arange(ylims_round[0], ylims_round[1], unit))
    ax.set_yticklabels(np.arange(ylims_round[0], ylims_round[1], unit).astype('str'))

    return ax


def mat_time_to_sec(t0, t):

    print('test worked')
    # Get start time
    year0 = int(t0[0])
    month0 = int(t0[1])
    day0 = int(t0[2])
    hour0 = int(t0[3])
    min0 = int(t0[4])
    sec0 = int(np.floor(t0[5]))
    msec0 = int((t0[5]-sec0)*1000000)
    t0py = datetime.datetime(year0, month0, day0, hour0, min0, sec0, msec0)

    # Get times to compare
    year = t.reshape(-1, 6)[:, 0]
    month = t.reshape(-1, 6)[:, 1]
    day = t.reshape(-1, 6)[:, 2]
    hour = t.reshape(-1, 6)[:, 3]
    min = t.reshape(-1, 6)[:, 4]
    sec = np.floor(t.reshape(-1, 6)[:, 5])
    msec = (t.reshape(-1, 6)[:, 5] - sec)*1000000

    tdiff = []
    for yr, mo, dy, hr, mi, s, ms in zip(year, month, day, hour, min, sec, msec):
        diff_temp = datetime.datetime(int(yr), int(mo), int(dy), int(hr), int(mi), int(s), int(ms)) - t0py
        tdiff.append(diff_temp.total_seconds())

    tdiff_array = np.asarray(tdiff)
    return tdiff_array


def find_nearest(array, value):  # stolen from stackoverflow
    idx = np.searchsorted(array, value, side="left")
    if idx > 0 and (idx == len(array) or math.fabs(value - array[idx-1]) < math.fabs(value - array[idx])):
        return array[idx-1]
    else:
        return array[idx]


def contiguous_regions(condition):
    """Finds contiguous True regions of the boolean array "condition". Returns
    a 2D array where the first column is the start index of the region and the
    second column is the end index. Taken directly from stackoverflow:
    https://stackoverflow.com/questions/4494404/find-large-number-of-
    consecutive-values-fulfilling-condition-in-a-numpy-array"""

    # Find the indices of changes in "condition"
    d = np.diff(condition)
    idx, = d.nonzero()

    # We need to start things after the change in "condition". Therefore,
    # we'll shift the index by 1 to the right.
    idx += 1

    if condition[0]:
        # If the start of condition is True prepend a 0
        idx = np.r_[0, idx]

    if condition[-1]:
        # If the end of condition is True, append the length of the array
        idx = np.r_[idx, condition.size] # Edit

    # Reshape the result into two columns
    idx.shape = (-1, 2)
    return idx


if __name__ == '__main__':


    pass