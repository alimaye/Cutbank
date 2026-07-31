% wrapper01b_channelOnly_exportMovie.m: Wrapper script demonstrating movie 
% file export for the model run of a channel only (i.e., no bank-material tracking).

clear
clc
dbstop if error

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Edit export parameters %%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 1. Source files
modelParameterFile =  'run_test_01_modelParameters.mat'; % Full path to parameter file

% 2. Movie export
exportParameters.movie.export = true;
exportParameters.movie.frame_interval_yr = 100; % Time interval between movie frames, in years
exportParameters.movie.image_width_cm = 18;
exportParameters.movie.format = 'MPEG-4'; % 'MPEG-4' | 'GIF'; See videoWriter.m help for additional output format options
exportParameters.movie.fps = 3;  % Frames per second

% Disable grid export and movie options that rely on grids
exportParameters.grid.export = false;
exportParameters.grid.cell_width = NaN;
exportParameters.grid.export_interval_yr = NaN;
exportParameters.movie.contour_interval_depths = NaN;
exportParameters.movie.xc_ytick_interval_depths = NaN;
exportParameters.movie.xc_xtick_interval_widths = NaN;
exportParameters.movie.plot_f_bedrock=false;
exportParameters.movie.plot_terraces=false;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% End of variables to edit %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% Set file paths
% Get path to highest-level directory (one above current)
currentDir = pwd;
if ispc
    slash = '\';
else 
    slash = '/';
end
ind = strfind(currentDir,slash);
directoryAbove = currentDir(1:ind(end));
addpath(genpath(directoryAbove)) % Adds paths to all model directories

% Automatically set model data file, output directory, and movie name
exportParameters.modelParameterFile = modelParameterFile;
load(exportParameters.modelParameterFile,'inputs')
exportParameters.modelDataFile = inputs.modelDataFile;
exportParameters.outputDir = inputs.outputDir;
exportParameters.movie.name = [inputs.trial,'_movie']; % Movie name
switch exportParameters.movie.format
    case 'MPEG-4'
          exportParameters.movie.name = [exportParameters.movie.name,'.mp4'];
    case 'GIF'
        exportParameters.movie.name = [exportParameters.movie.name,'.gif'];
end


% Save export parameters to file
exportParameterFile = [inputs.outputDir,'run_',inputs.trial,'_exportParameters.mat'];
save(exportParameterFile,'exportParameters')

mode = 'exportGridsMovie'; % 'runModel' | 'runModel_and_exportGridsMovie'

% Execute file export function
meander_execute(modelParameterFile,exportParameterFile,mode);