function [D, ColNames] = readDataMatrixFromAMC(...
    amcfpath, ...
    QueryColNames, ...
    outputframerate, ...
    inputframerate)
% Read data from AMC motion capture file into 2D matrix
%
% EXAMPLE
% -------
% Extract all sensor channels from subject 13, trial 29.
% >> [D, Names] = readDataMatrixFromAMC('amc/13_29.amc');
% Extract only foot-related sensor channels from subject 13, trial 29.
% >> FootNames = {'rtibia.rx', 'rfoot.rx', 'ltibia.rx', 'lfoot.rx'};
% >> [D, Names] = readDataMatrixFromAMC('amc/13_29.amc', FootNames);
%
% PARAMETERS
% -------
% amcfpath : string
%    File system path to an Acclaim AMC motion capture data file
%    This file must live in a directory called "amc/", and have form:
%        /path/to/dataset/amc/<subjectID>_<trialID>.amc
%    There should be a plain-text skeleton joints key file 
%        /path/to/dataset/amc/SkeletonJoints.key
%    that summarizes all the tracked sensor channels for this data.
% QueryColNames : 1D cell array of strings
%    List of the sensor channels to extract from provided AMC file.
%    For example, 'rtibia.rx' or 'lowerback.ty'
%    Each one corresponds to one column of output matrix D.
% outputframerate : int, default=10
%    Desired number of frames per second 
%    If less than input frame rate, we do simple block-averaging to
%    downsample.
%    All work of Hughes/Fox/Sudderth used default of 10 fps,
%    so each output row summarizes data from 0.1 second intervals.
% inputframerate : int, default=120
%    Number of frames per second of the data in provided AMC file.
%    Default is 120 for all data from mocap.cs.cmu.edu
%
% RETURNS
% -------
% D : 2D array, size T x nChannels
%     D[t,c] is the scalar observed value of sensor channel c at time t
% ColNames : 1D cell array of strings
%     ColNames{c} is the string name of column D(:, c)
%
% CREDITS
% -------
%  2012-2015 Michael Hughes, Brown
%     cleaned up formatting and preprocessing into one file.
%     made SkeletonJoints.key file for very easy processing of AMC.
%  2008-2009 E. Sudderth & E. Fox, MIT
%     added post-processing routines to downsample framerate.
%  2003 Jernej Barbic, CMU
%     created original file amc_to_matrix.m
%  Smoothing Angle suggestion due to N. Lawrence (smoothAngleChannels.m)

if ~exist('outputframerate', 'var')
    outputframerate = 10; % default in all Hughes/Fox/Sudderth papers.
end
if ~exist('inputframerate', 'var')
    inputframerate = 120; % default for mocap.cs.cmu.edu
end

% Preallocate the matrix
%  since we usually have HUGE volumes of sensor data
D = nan( 7200, 50 );

% Open file
fid=fopen(amcfpath, 'rt');
if (fid == -1)
    error('ERROR: Cannot open file %s.\n', amcfpath);
end;

% Read lines until we've skipped past the header
%   assuming it ends with the line ":DEGREES"
line=fgetl(fid);
while ~strcmp(line,':DEGREES')
    line=fgetl(fid);
end

% Loop through each frame, one-at-a-time
fID = 0;
fNames = {};
fCtr = 1;
while ~feof(fid)
    
    line = fgets( fid );
    SpaceLocs = strfind( line, ' ');
    
    if isempty( SpaceLocs ) && ~isempty(line)
        % Advance to next time frame (fID) and reset dimension counter (dID)
        fID = fID + 1;
        dID = 1;
    else
        nNumFields = length(SpaceLocs);
        
        if fID == 1
            fNames{fCtr} = line( 1:SpaceLocs(1)-1 );
            fCtr = fCtr + 1;
            fDim(fCtr) = nNumFields;
        end
        
        if fID > size(D,1)
            D( end+1:end+7200, :) = zeros( 7200, size(D,2) );
        end
        
        D( fID, dID:dID+nNumFields-1 ) = sscanf( line(SpaceLocs(1)+1:end), '%f' );
        dID = dID+nNumFields;
    end
end

% Make sure to close file
fclose(fid);

% Cleanup resulting data to get rid of extra rows/cols
%   which we preallocated just in case
D = D( 1:fID, :);
keepCols = ~isnan( sum( D, 1 ) );
D = D( :, keepCols );

[basedir,~,~] = fileparts( amcfpath );
[ColNames] = readChannelNamesFromSkeletonKey( fullfile( basedir, 'SkeletonJoints.key')  );

% ==== FILTER COLUMNS DOWN TO THOSE SPECIFIED IN QUERY
% Keep only channels desired by the user,
%  as specified by the QueryColNames arg

if exist( 'QueryColNames', 'var' )
    keepCols = [];
    for qq = 1:length( QueryColNames )
        needle = QueryColNames{qq};
        mID = find( strncmp( needle, ColNames, length(needle) ) );
        if ~isempty( mID )
            keepCols(end+1) = mID;
        else
            fprintf( 'WARNING: Did not find desired channel named %s. Skipping...\n', needle );
        end
    end
    D = D(:, keepCols );
    ColNames = ColNames( keepCols );
end

% ==== SMOOTHING OF ANGLE MEASUREMENTS
% Look through all channels, and correct for sharp discontinuities
% due to angle measurements jumping past boundaries
% e.g. smooth transition from +178 deg to +182 deg could be recorded as
%                             +178 deg to -178 deg, which is awkward
didSmooth = 0;
SmoothedChannels = {};
for chID = 1:size(D,2)
    didSmoothHere = 0;
    for tt = 2:size(D, 1)
        ttDelta= D( tt, chID) - D(tt-1, chID);
        if abs(ttDelta+360)<abs(ttDelta)
            % if y_tt +360 is closer to y_tt-1 than just y_tt
            %    shift y_tt and all subsequent measurements by +360
            D(tt:end, chID) = D(tt:end, chID)+360;
            didSmoothHere= 1;
        elseif abs(ttDelta-360)<abs(ttDelta)
            % if y_tt -360 is closer to y_tt-1 than just y_tt
            %    shift y_tt and all subsequent measurements by -360
            D(tt:end, chID) = D(tt:end, chID)-360;
            didSmoothHere= 1;
        end
    end
    if didSmoothHere
        SmoothedChannels{end+1} = ColNames{chID};
    end
    didSmooth = didSmooth | didSmoothHere;
end
if didSmooth
    L = length( SmoothedChannels );
    MyChannels(1:2:(2*L) ) = SmoothedChannels;
    for aa = 2:2:(2*L)
        MyChannels{aa} = ', ';
    end
    SmoothSummary = strcat( MyChannels{:} );
    fprintf( 'Warning: did some smoothing on channels %s\n', SmoothSummary );
end

% ==== SUBTRACT MEAN
D = bsxfun( @minus, D, mean(D,1));

% ==== DOWNSAMPLE
windowSize = ceil(inputframerate / outputframerate);
windowSize = max(windowSize, 1);
if windowSize > 1
    msg = 'Downsampling by factor of %d to get target frame rate %.2f\n';
    fprintf(msg, windowSize, inputframerate / windowSize);

    nFrames = size(D, 1);
    numWindows = floor(nFrames / windowSize);
    endWindow = rem(nFrames, numWindows);
    
    Dpost = zeros(numWindows+1, size(D,2));
    for t = 1:numWindows
        Dpost(t,:) = mean(D((t-1)*windowSize+1:t*windowSize,:), 1);
    end
    if endWindow > 1
        Dpost(numWindows+1,:) = mean(D(numWindows*windowSize+1:end, :), 1);
    else
        Dpost(numWindows+1,:) = D(end,:);
    end
    D = Dpost;
end

end