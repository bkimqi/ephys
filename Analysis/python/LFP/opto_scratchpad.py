## Scratchpad for opto related analyses

import numpy as np
import Python3.Binary as ob
import Analysis.python.LFP.preprocess_data as ppd
import numpy as np
import matplotlib.pyplot as plt
import os
import pandas as pd
import Analysis.python.LFP.helpers as lfhelp
import seaborn as sns
import matplotlib.patches as patches

## Plot settings
font = {"family": "normal", "weight": "normal", "size": 22}
plt.rc("font", **font)

## Relevant folder/files
chan_map_file = "/data/GitHub/dibalab_ephys/Channel Maps/MINT/2x32MINT_chan_map_good"  # nat laptop location r'C:\Users\Nat\Documents\UM\Working\Opto\Rat613\2x32MINT_chan_map_good.txt'
data_folder = "/data/Working/Opto Project/Rat 613/Rat613Day1/Rat613simtest_2020-08-01_08-47-11/"  # nat laptop location r'C:\Users\Nat\Documents\UM\Working\Opto\Rat613\Rat613Day1\Rat613track_2020-08-01_09-21-55'
## Load Data!
chan_map_dict = ob.LoadChannelMapFromText(chan_map_file)
chans_use = np.hstack(
    (np.arange(0, 8), np.arange(16, 24))
)  # Use only shank 1 and shank 3
# channels_use = [chan for chan in np.asarray(chan_map_dict['0']['mapping'])[chans_use]]  # not used
Data, Rate = ob.Load(
    data_folder, ChannelMap=chans_use, Experiment=1, Recording=1, mode="r"
)
event_data = ppd.load_binary_events()
channels_use = [chan for chan in np.asarray(chan_map_dict["0"]["mapping"])[chans_use]]
Data, Rate = ob.Load(
    data_folder, ChannelMap=channels_use, Experiment=2, Recording=1, mode="r"
)

## Look at silencing for Jackie place stim day 2
adc_channel = 35  # channel with adc input
on_thresh = 1300000  # on voltage threshold
if "APPDATA" in os.environ.keys() and os.environ["APPDATA"][0] == "C":
    base_dir = r"C:\Users\Nat\Documents\UM\Working\Opto\Jackie671\placestim_day2\PRE"
    full_raw_path = r"C:\Users\Nat\Documents\UM\Working\Opto\Jackie671\placestim_day2\PRE\Jackie_PRE_2020-10-07_10-48-13\experiment1\recording1\continuous\Intan_Rec._Controller-100.0"
    save_loc = np.nan

elif "HOSTNAME" in os.environ.keys() and os.environ["HOSTNAME"].lower() == "lnx00004":
    base_dir = r"/data/Working/Opto/Jackie671/Jackie_placestim_day2/Jackie_PRE_2020-10-07_10-48-13"
    full_raw_path = r"/data/Working/Opto/Jackie671/Jackie_placestim_day2/Jackie_PRE_2020-10-07_10-48-13/experiment1/recording1/continuous/Intan_Rec._Controller-100.0"
    full_spike_path = r"/data/Working/Opto/Jackie671/Jackie_placestim_day2/Jackie_PRE_2020-10-07_10-48-13/experiment1/recording1/continuous/Intan_Rec._Controller-100.0/spyking_circus/Jackie_pre_2020-10-07_nobadchannels/Jackie_pre_2020-10-07.GUI/"
    save_loc = r"/data/UM/Meeting_Plots"
spike_folder = "Jackie_pre_2020-10-07.GUI"
raw_folder = "Jackie_PRE_2020-10-07_10-48-13"
data_ds = np.load(os.path.join(full_raw_path, "continuous_lfp.npy"))

timestamps = np.load(os.path.join(full_raw_path, "timestamps.npy"))
time_ds = timestamps[0:-1:24]

on_idx = np.where(data_ds[adc_channel] > on_thresh)[0]
off_idx = np.where(data_ds < on_thresh)[0]
on_times = on_idx[lfhelp.contiguous_regions(np.diff(on_idx) == 1)[:, 0]] / 1250
off_times = on_idx[lfhelp.contiguous_regions(np.diff(on_idx) == 1)[:, 1]] / 1250

# on_times = np.where(data_ds[adc_channel] > on_thresh)[0]
# off_times = np.where(data_ds[adc_channel] <= on_thresh)[0]

spike_times = np.load(os.path.join(full_spike_path, "spike_times.npy")) / 30000
clusters = np.load(os.path.join(full_spike_path, "spike_clusters.npy"))
cluster_info = pd.read_csv(os.path.join(full_spike_path, "cluster_info.tsv"), sep="\t")
good_units = cluster_info["id"][cluster_info["group"] == "good"].array

## Plot FR boxplot
sns.set_palette("Set2")
clusters_use = [5, 34, 59]
silenced_shank = [11, 7, 4, 8, 10, 6, 5, 9]
adjacent_shank = [15, 3, 0, 12, 14, 2, 1, 13]
buffer = 1  # seconds before/after to consider for spiking

fig, ax = plt.subplots(1, 3)
fig.set_size_inches([22, 6])
stat_dict = []
for idc, cluster_use in enumerate(clusters_use):
    cl_spike_times = spike_times[clusters == cluster_use]
    channel = cluster_info["ch"][cluster_info["id"] == cluster_use]

    _, stat_dict_temp = lfhelp.opto_boxplot(
        cl_spike_times, on_times, off_times, buffer=buffer, ax=ax[idc]
    )
    stat_dict.append(stat_dict_temp)

    if channel.isin(silenced_shank).values[0]:
        ax[idc].set_title("Cell on Silenced Shank")
    elif channel.isin(adjacent_shank).values[0]:
        ax[idc].set_title("Cell on Adjacent Shank")
    else:
        ax[idc].set_title("Cell on Non-Adjacent Shank")

## Plot rasters

figr, axr = plt.subplots(1, 3)
figr.set_size_inches([22.33, 6.5])
for idc, cluster_use in enumerate(clusters_use):
    cl_spike_times = spike_times[clusters == cluster_use]
    channel = cluster_info["ch"][cluster_info["id"] == cluster_use]

    buffer = 1  # seconds before/after to consider for spiking

    # Now sort by duration of stimulation
    durations = off_times - on_times
    idds = np.argsort(durations)
    on_times_sorted, off_times_sorted = on_times[idds], off_times[idds]
    lfhelp.plot_pe_raster(
        cl_spike_times,
        on_times_sorted,
        event_ends=off_times_sorted,
        box_color=[0, 0, 1, 0.3],
        spike_color="k",
        ax=axr[idc],
    )

    # Label plots
    if channel.isin(silenced_shank).values[0]:
        axr[idc].set_title("Cell on Silenced Shank")
    elif channel.isin(adjacent_shank).values[0]:
        axr[idc].set_title("Cell on Adjacent Shank")
    else:
        axr[idc].set_title("Cell on Non-Adjacent Shank")

# Label axes
[a.set_xlabel("Time from Stimulation Start (s)") for a in axr]
[a.set_ylabel("Sorted Trial #") for a in axr]
[lfhelp.pretty_plot(a) for a in axr]  # box off

figr.savefig(os.path.join(save_loc, "Detection Triggered Rasters.pdf"))
