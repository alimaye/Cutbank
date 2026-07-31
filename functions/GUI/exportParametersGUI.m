function [fname] = exportParametersGUI(varargin)
% exportParametersGUI.m: Generates a graphical user interface (GUI) for
% setting file export parameters for model runs with bank-material tracking.
% using the 3rd party software inputsdlg.m by Takeshi Ikuma that is included 
% in this archive.
% Input arguments:
%   variable number of input arguments
% Output arguments:
%   fname: name of file to which export parameters are saved

if ispc
    addpath('..\3rdParty\inputsdlg') % add path to function inputsdlg.m
else
    addpath('../3rdParty/inputsdlg') % add path to function inputsdlg.m
end

%%%% Initialize dialog box options
title = 'File export parameters'; % title for GUI dialog box
set(0,'DefaultUicontrolFontSize',10) % Set font size
options.Resize = 'on';
options.Interpreter = 'tex';
options.CancelButton = 'on';
options.ApplyButton = 'off';
options.ButtonNames = {'OK','Cancel'};

prompt = {}; % cell array to store preferences for prompts in the GUI
formats = struct; % structure array to store preferences for GUI appearance and data type
defAns = struct; % struture array to store default parameter values. 
%%%%

% Added this parameter for proper indexing in 'prompt'
nColumns = 1;

%%% Organization:
% 1. Source files
% 2. Grid export parameters
% 3. Movie export parameters

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% COLUMN 1 %%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
i=1;
row = 1;
col = 1;
prompt(i,:) = {'\bf{1. Source files}',[],[]};
formats(row,col).type = 'text';

%%% The following code sets specifications for other parameters
i=i+nColumns;
row = 2;
col = 1;
% Model parameter file
prompt(i,:) = {'Model parameter file','modelParameterFile',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'file';
formats(row,col).items = {'*.mat'}; % This forces it to be a .mat file, won't allow selection of other file formats
formats(row,col).limits = [0 1]; % This syntax (i.e., [0 1]) invokes uigetfile.m, which prompts user to select an existing file
if ~isempty(varargin)
    defAns.modelParameterFile = varargin{1};
else
    defAns.modelParameterFile = '';
end

i=i+nColumns;
row = 3;
col = 1;
% Model data file
prompt(i,:) = {'Model data file','modelDataFile',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'file';
formats(row,col).items = {'*.mat'}; % This forces it to be a .mat file, won't allow selection of other file formats
formats(row,col).limits = [0 1]; % This syntax (i.e., [0 1]) invokes uigetfile.m, which prompts user to select an existing file
load(defAns.modelParameterFile,'inputs')
modelDataFile = [inputs.outputDir,'run_',inputs.trial,'_modelDataFinal.mat'];
if ~exist(modelDataFile)
    % create a temporary file
    tempVar = [];
    save(modelDataFile,'tempVar')
end
defAns.modelDataFile = modelDataFile; % file must exist already or inputsdlg.m throws an error. 

i=i+nColumns;
row=4;
col=1;
% Blank
prompt(i,:) = {'',[],[]};
formats(row,col).type = 'text';

i=i+nColumns;
row = 5;
col = 1;
% 2. Grid export
prompt(i,:) = {'\bf{2. Grid export}',[],[]};
formats(row,col).type = 'text';

i=i+nColumns;
row = 6;
col = 1;
% Grid export switch
prompt(i,:) = {'Export grids','grid_export',[]};
formats(row,col).type = 'list';
formats(row,col).format = 'text';
formats(row,col).style = 'radiobutton';
formats(row,col).items = {'yes','no'};
defAns.grid_export = 'yes';

i=i+nColumns;
row = 7;
col = 1;
% grid cell width
prompt(i,:) = {'Cell width (m)','cell_width',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [1 1000];
formats(row,col).size = [50 20];
defAns.cell_width = 10;

i=i+nColumns;
row = 8;
col = 1;
% grid export interval
prompt(i,:) = {'Grid export interval (yr)','grid_export_interval_yr',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [1 1e7];
formats(row,col).size = [50 20];
defAns.grid_export_interval_yr = 1e3;

i=i+nColumns;
row=9;
col=1;
% Blank
prompt(i,:) = {'',[],[]};
formats(row,col).type = 'text';

i=i+nColumns;
row = 10;
col = 1;
% 3. Movie export
prompt(i,:) = {'\bf{3. Movie export}',[],[]};
formats(row,col).type = 'text';

i=i+nColumns;
row = 11;
col = 1;
% Movie export switch
prompt(i,:) = {'Export movie','movie_export',[]};
formats(row,col).type = 'list';
formats(row,col).format = 'text';
formats(row,col).style = 'radiobutton';
formats(row,col).size = [50 20];
formats(row,col).items = {'yes','no'};
defAns.movie_export = 'yes';

i=i+nColumns;
row = 12;
col = 1;
% Movie frame interval
prompt(i,:) = {'Movie frame interval (yr)','movie_frame_interval_yr',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [1 1e7];
formats(row,col).size = [50 20];
defAns.movie_frame_interval_yr = 1e2;


i=i+nColumns;
row = 13;
col = 1;
% Topographic contour interval, in channel depths
prompt(i,:) = {'Topographic contour interval (channel depths)','movie_contour_interval_depths',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [0.1 100];
formats(row,col).size = [50 20];
defAns.movie_contour_interval_depths = 1;

i=i+nColumns;
row = 14;
col = 1;
% Topographic cross section x-tick interval, in channel widths
prompt(i,:) = {'Topographic cross section x-tick interval (channel widths)','movie_xc_xtick_interval_widths',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [1 1e4];
formats(row,col).size = [50 20];
defAns.movie_xc_xtick_interval_widths = 10;

i=i+nColumns;
row = 15;
col = 1;
% Topographic cross section x-tick interval, in channel widths
prompt(i,:) = {'Topographic cross section y-tick interval (channel depths)','movie_xc_ytick_interval_depths',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [1e-1 1e4];
formats(row,col).size = [50 20];
defAns.movie_xc_ytick_interval_depths = 5;

i=i+nColumns;
row = 16;
col = 1;
% Image width (in cm) of movie frames
prompt(i,:) = {'Frame image width (cm)','movie_image_width_cm',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [20 30];
formats(row,col).size = [50 20];
defAns.movie_image_width_cm = 20;

i=i+nColumns;
row = 17;
col = 1;
% Switch to plot bank-material bedrock fraction in movie frames
prompt(i,:) = {'Plot bank-material bedrock fraction','movie_plot_f_bedrock',[]};
formats(row,col).type = 'list';
formats(row,col).format = 'text';
formats(row,col).style = 'radiobutton';
formats(row,col).items = {'yes','no'};
formats(row,col).size = [50 20];
defAns.movie_plot_f_bedrock = 'yes';

i=i+nColumns;
row=18;
col=1;
% Switch to plot terraces in movie frames
prompt(i,:) = {'Plot terraces','movie_plot_terraces',[]};
formats(row,col).type = 'list';
formats(row,col).format = 'text';
formats(row,col).style = 'radiobutton';
formats(row,col).items = {'yes','no'};
formats(row,col).size = [50 20];
defAns.movie_plot_terraces = 'yes';

i=i+nColumns;
row = 19;
col = 1;
% Movie name
prompt(i,:) = {'Movie name','movie_name',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'text';
formats(row,col).size = [500 50];
defAns.movie_name = 'movie';

i=i+nColumns;
row = 20;
col = 1;
% Movie format
prompt(i,:) = {'Movie format','movie_format',[]};
formats(row,col).type = 'list';
formats(row,col).format = 'text';
formats(row,col).style = 'radiobutton';
formats(row,col).items = {'MPEG-4'};
formats(row,col).size = [50 20];
defAns.movie_format = 'MPEG-4';

i=i+nColumns;
row = 21;
col = 1;
% Movie frames per second
prompt(i,:) = {'Frames per second','movie_fps',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
defAns.movie_fps = 3;

% % Format to add empty rows:
% row = 22;
% col = 1;
% prompt(i,:) = {'',[],[]};
% formats(row,col).type = 'text';

%%% Execute the dialog function. Parmaeters are stored in a structure
%%% array 'inputs'
[exportParameters,~] = inputsdlg(prompt,title,formats,defAns,options);

% convert any cell arrays in the structure to non-cell arrays
fields = fieldnames(exportParameters);
for k=1:numel(fields)
    if iscell(exportParameters.(fields{k}))
        exportParameters.(fields{k}) = cell2mat(exportParameters.(fields{k}));
    end
end
        
% order fields alphabetically
exportParameters = orderfields(exportParameters);

% check that output directory is defined; if not, throw an error
if isempty(inputs.outputDir)
    error('modelParameters_channelOnlyGUI.m: Must define output directory for model files');
end

% Add trailing slash to output directory 
if ispc
    exportParameters.outputDir = [inputs.outputDir,'\'];
else
    exportParameters.outputDir = [inputs.outputDir,'/'];
end

switch exportParameters.grid_export
    case 'yes'
        exportParameters.grid.export = true;
    case 'no'
         exportParameters.grid.export = false;
end
exportParameters.grid.cell_width = exportParameters.cell_width;
exportParameters.grid.export_interval_yr = exportParameters.grid_export_interval_yr;
exportParameters = rmfield(exportParameters,{'grid_export','cell_width','grid_export_interval_yr'});

switch exportParameters.movie_export
    case 'yes'
        exportParameters.movie.export = true;
    case 'no'
         exportParameters.movie.export = false;
end
exportParameters = rmfield(exportParameters,'movie_export');

exportParameters.movie.frame_interval_yr = exportParameters.movie_frame_interval_yr;
exportParameters.movie.contour_interval_depths = exportParameters.movie_contour_interval_depths;
exportParameters.movie.xc_xtick_interval_widths = exportParameters.movie_xc_xtick_interval_widths;
exportParameters.movie.xc_ytick_interval_depths = exportParameters.movie_xc_ytick_interval_depths;
exportParameters.movie.image_width_cm = exportParameters.movie_image_width_cm;
exportParameters.movie.plot_f_bedrock = exportParameters.movie_plot_f_bedrock;
exportParameters.movie.plot_terraces = exportParameters.movie_plot_terraces;

% Convert switches to logical
switch exportParameters.movie.plot_f_bedrock
    case 'yes'
        exportParameters.movie.plot_f_bedrock = true;
    case 'no'
        exportParameters.movie.plot_f_bedrock = false;
end

switch exportParameters.movie.plot_terraces
    case 'yes'
        exportParameters.movie.plot_terraces = true;
    case 'no'
        exportParameters.movie.plot_terraces = false;
end

exportParameters.movie.name = exportParameters.movie_name;
exportParameters.movie.format = exportParameters.movie_format;
exportParameters.movie.fps = exportParameters.movie_fps;

% Remove fields defined from GUI to avoid duplication
exportParameters = rmfield(exportParameters,{'movie_frame_interval_yr',...
    'movie_contour_interval_depths','movie_xc_xtick_interval_widths',...
    'movie_xc_ytick_interval_depths','movie_image_width_cm',...
    'movie_plot_f_bedrock','movie_plot_terraces','movie_name',...
    'movie_format','movie_fps'});
    
% save export parameters to file
exportParameters.trial = inputs.trial;
fname = [exportParameters.outputDir,'run_',exportParameters.trial,'_exportParameters.mat'];
save(fname,'exportParameters')
fprintf('Wrote %s to %s\n',fname,exportParameters.outputDir);
end
