function [] = showSkeletonImgForAMCSegment(amc_fpath, fracStart, fracStop, maxNumSnapshots, asf_fpath)
%% SUMMARY
% Plot 3D time-lapse skeleton for a contiguous segment of mocap recording.
%% EXAMPLES
% To show a 7-image time-lapse of the first 10th of recording 13_31.amc:
% >> showSkeletonImgForAMCSegment('mocap6/amc/13_31.amc', 0, 0.1, 7);
% To show a 10-image time-lapse of the second half of recording 14_20.amc
% >> showSkeletonImgForAMCSegment('mocap6/amc/14_20.amc', 0.5, 1, 10);
%% REQUIREMENTS
% Uses Neal Lawrence's toolbox for skeleton visualization.
% Available on the Brown CS filesystem, via the command:
% >> addpath('/data/liv/visiondatasets/mocap/VizToolbox/neal-lawrence-toolbox/');
%% INPUT PARAMETERS
% amc_fpath : string absolute file path to .amc mocap recording file.
% fracStart : start position of segment to plot, as a fraction in [0,1]
%             0 implies beginning of recording, 1 implies the end.
% fracStop : stop position of segment to plot, as fraction in [0,1]
% maxNumSnapshots : [default=5] integer number of snapshots to blend together for the time-lapse
%                   will be evenly spaced between the start and stop of the segment
% asf_fpath : [default=use file in asf/ folder] string absolute file path.
%   Optional way to specify where the skeleton is defined as an .asf file.
%   Not needed for mocap6 or mocap120 data.
%% NOTES
% Specifying the segment via fractional positions allows easy conversion 
% from a preprocessed, subsampled sequence given to an inference algorithm,
% and the original high-fidelity mocap recording.

if ~exist('skelMultiVis')
    error('Neal Lawrence mocap toolbox not found. Please add to the path.');
end

%% Parse AMC file and parameters from input 
if ~exist('maxNumSnapshots', 'var')
    maxNumSnapshots = 5;
end
if ~exist(amc_fpath, 'file')
   error(['AMC file not found:' amc_fpath]); 
end

%% Parse ASF file from input 
% Default: determine asf file from the amc file path string
% /path/to/amc/13_30.amc --> /path/to/asf/13.asf
if ~exist('asf_fpath', 'var')
    [datapath,basenameWithSeqID,ext] = fileparts( amc_fpath );
    basename = basenameWithSeqID(1:end-3);
    [parentpath, ~, ~] = fileparts(datapath);
    asf_fpath = fullfile(parentpath, 'asf', [basename '.asf']);
end
if ~exist(asf_fpath, 'file')
   error(['ASF file not found:' asf_fpath]); 
end

%% Load skeleton traces from AMC and ASF files
% These lines take a while!
skel = acclaimReadSkel(asf_fpath);
[Xch, skel] = acclaimLoadChannels(amc_fpath, skel);
% Xch : N x nChannels matrix of reals
% each row is one timestep snapshot of all sensor channels

%% Determine which snapshots of the skeleton to visualize
% curRows : vector of ints that selects which rows of Xch we display
N = size(Xch,1);
start = max(1,floor(fracStart * N));
stop = min(N, ceil(fracStop *N));
curRows = unique(round(linspace(start, stop, maxNumSnapshots)));

%% Make the visualization, and make it pretty
skelMultiVis(skel, Xch(curRows, :), 1:length(curRows), []);
set( gca, 'XTick',[],'YTick',[], 'ZTick', []);
xlabel(''); ylabel(''); zlabel('');
