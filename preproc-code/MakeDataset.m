% Create complete dataset as a MAT file.
% MAT file contains 
% * DataBySeq, 1D array of structs.
%    Each entry n is a struct for a single sequence, with fields
%    - X : 2D array, T x D
%        Each row t is observed data vector (size D) at time interval t
%    - Xprev : 2D array, T x D
%        Each row t is previous observation (size D) for time interval t
%        This field is used by auto-regressive models, ignored by others.
%    - TrueZ : 2D array, T x 1
%        Each entry t is the int label of human-annotated action at time t.
%    - filename : string
%        Indicates which record on mocap.cs.cmu.edu this came from.
%        Format: <subjectID trialID>, like 14_06 or 13_30.
% * ActionNames : 1D cell array of strings
%    each entry k is the name of the action referred to when TrueZ(t)==k
% * ChannelNames : 1D cell array of strings
%    each entry d is the name of the sensor for dimension d of X/Xprev

% Data file names, in format <subject id>_<trial id>
% Subject/trial ids are taken directly from mocap.cs.cmu.edu
FileNames = {'13_29',  '13_30',  '13_31',  '14_06',  '14_14',  '14_20'};
targetframerate = 10;
inputframerate = 120; % default of data stored at mocap.cs.cmu.edu;

% Names of 12 sensor channels, in format <body part>.<r/t><axis>
% where r means rotation, t means translation
% <axis> is one of 'x', 'y', 'z'
% These are a subset of all available measurements in raw data,
% chosen to simplify problem while still representing all relevant motions.
ChannelNames = {
    'root.ty', 'lowerback.rx', 'lowerback.ry', 'upperneck.ry', ...
    'rhumerus.rz', 'rradius.rx','lhumerus.rz', 'lradius.rx', ...
    'rtibia.rx', 'rfoot.rx', 'ltibia.rx', 'lfoot.rx' ...    
};

ActionNames = {
    'JumpJack', 'Jog', 'Squat', 'KneeRaise', 'ArmCircle', ...
    'Twist', 'SideReach', 'Box', 'UpDown', 'ToeTouchOneHand', ...
    'SideBend', 'ToeTouchTwoHands' ...
};

DataTemplate = struct('X', [], 'Xprev', [], 'TrueZ', []);
DataBySeq = repmat(DataTemplate, length(FileNames), 1);

for n = 1:length(FileNames)
   amcfpath = ['../amc/' FileNames{n} '.amc'];
   [X_n, ColNames] = readDataMatrixFromAMC(...
        amcfpath, ...
        ChannelNames, ...
        targetframerate, ...
        inputframerate);
   
   zpath =['../truelabels/' FileNames{n} '.txt'];
   Z_n = squeeze(importdata(zpath));
   Z_n = Z_n(:);
   
   % Convert sequence-specific data into standard format,
   % setting aside the first timestep since autoregressive models 
   % can't deal with it.
   DataBySeq(n).X = X_n(2:end, :);
   DataBySeq(n).Xprev = X_n(1:end-1, :);
   DataBySeq(n).TrueZ = Z_n(2:end);
   DataBySeq(n).filename = FileNames(n);
   DataBySeq(n).framerate = targetframerate;
end

save('../mocap6.mat', 'DataBySeq', 'ChannelNames', 'ActionNames');