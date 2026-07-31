% wrapper02b_vectorExport.m: Wrapper script for exporting grids and movie
% files for the example run with vector-based bank-material tracking.

clear
clc
dbstop if error

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Edit export parameters %%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 1. Source files
modelParameterFile =  'run_test_02_modelParameters.mat'; % Full path to parameter file

% 2. Grid export
exportParameters.grid.export = true; % Set to 'true' to export grids; else 'false'
exportParameters.grid.cell_width=10; % Desired grid cell width for exported grids.
exportParameters.grid.export_interval_yr = 1000; % Time interval for grid export, in years

% 3. Movie export
exportParameters.movie.export = true;
exportParameters.movie.frame_interval_yr = 100; % Time interval between movie frames, in years
exportParameters.movie.contour_interval_depths = 1; % Elevation contour interval, in channel depths
exportParameters.movie.xc_xtick_interval_widths = 10; % Plot x-tick interval for topographic cross-sections, in channel widths
exportParameters.movie.xc_ytick_interval_depths = 1; % Plot y-tick interval for topograhic cross-sections, in channel depths
exportParameters.movie.image_width_cm = 18; % Image width for movie (cm)
exportParameters.movie.plot_f_bedrock = true; % Set to 'true' to plot bank-material bedrock fraction in movie frames; else 'false'
exportParameters.movie.plot_terraces = false; % Set to 'true' to plot terraces in movie frames; else 'false'
exportParameters.movie.format = 'MPEG-4'; % options: 'MPEG-4' | 'GIF'
exportParameters.movie.fps = 2;  % Frames per second

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
load(modelParameterFile,'inputs')
exportParameterFile = [inputs.outputDir,'run_',inputs.trial,'_exportParameters.mat'];
save(exportParameterFile,'exportParameters')

mode = 'exportGridsMovie'; % 'runModel' | 'runModel_and_exportGridsMovie'

% Execute file export function
meander_execute(modelParameterFile,exportParameterFile,mode);