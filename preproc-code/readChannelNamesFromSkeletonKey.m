function [CNames] = readChannelNamesFromSkeletonKey( fname )
% Read in all sensor channel names from SkeletonJoints.key file.
% PARAMETERS
% ------
% fname : string
%     file system path to SkeletonJoints.key plain-text file
%     Each row summarizes a body part and available measurements
%         root tx ty tz rx ry rz
%         lowerback rx ry rz
%         upperback rx ry rz
%         thorax rx ry rz
%         lowerneck rx ry rz
%    
% RETURNS
% ------
% CNames : 1D cell array of strings
%     each value is the name of a joint measurement in the AMC file
%     'lclavicle.rx' means rotation around x-axis of the left clavicle. 


% Open file
fid=fopen(fname, 'rt');
if (fid == -1)
  error('ERROR: Cannot open file %s.\n', fname);
end;

% Read lines until we've skipped past the header 
%   assuming it ends with the line ":DEGREES"
line=fgetl(fid);
if strcmp(line(1),'#')
  while strcmp(line(1),'#')
      line=fgetl(fid);
  end
end

CNames = {};
doReadFreshLine = 0;
while ~feof(fid)

  if doReadFreshLine
      line = fgetl( fid );
  end
  doReadFreshLine = 1;
  
  fields = regexp(line,' ','split');  
  
  PartName = fields{1};
  
  for aa = 2:length( fields )
      CNames{end+1} = [PartName '.' fields{aa}];
  end
  
end

