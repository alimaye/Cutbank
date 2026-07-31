function [fname] = exportParameters_channelOnlyGUI(varargin)
% exportParametersGUI_channelOnly.m: Generates a graphical user interface (GUI) for
% file export parameters for runs with no bank-material tracking, using the 
% 3rd party software inputsdlg.m by Takeshi Ikuma that is included 
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
title = 'File export parameters: Channel only'; % title for GUI dialog box
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
% 2. Movie export parameters

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
% 2. Movie export
prompt(i,:) = {'\bf{2. Movie export}',[],[]};
formats(row,col).type = 'text';

i=i+nColumns;
row = 6;
col = 1;
% Movie export switch
prompt(i,:) = {'Export movie','movie_export',[]};
formats(row,col).type = 'list';
formats(row,col).format = 'text';
formats(row,col).style = 'radiobutton';
formats(row,col).size = [20 50];
formats(row,col).items = {'yes','no'};
defAns.movie_export = 'yes';

i=i+nColumns;
row = 7;
col = 1;
% Movie frame interval
prompt(i,:) = {'Movie frame interval (yr)','movie_frame_interval_yr',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [1 1e7];
formats(row,col).size = [50 20];
defAns.movie_frame_interval_yr = 1e2;

i=i+nColumns;
row = 8;
col = 1;
% Image width (in cm) of movie frames
prompt(i,:) = {'Frame image width (cm)','movie_image_width_cm',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [20 30];
formats(row,col).size = [50 20];
defAns.movie_image_width_cm = 20;

i=i+nColumns;
row = 9;
col = 1;
% Movie name
prompt(i,:) = {'Movie name','movie_name',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'text';
formats(row,col).size = [250 20];
defAns.movie_name = 'movie';

i=i+nColumns;
row = 10;
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
row = 11;
col = 1;
% Movie frames per second
prompt(i,:) = {'Frames per second','movie_fps',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
defAns.movie_fps = 3;

% % Format to add empty rows:
% row = 12;
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
exportParameters.outputDir = inputs.outputDir;

% disable grid export (not relevant for channel-only simulations)
exportParameters.grid.export = false;
exportParameters.grid.cell_width = NaN;
exportParameters.grid.export_interval_yr = NaN;

switch exportParameters.movie_export
    case 'yes'
        exportParameters.movie.export = true;
    case 'no'
         exportParameters.movie.export = false;
end
exportParameters = rmfield(exportParameters,'movie_export');
exportParameters.movie.frame_interval_yr = exportParameters.movie_frame_interval_yr;
exportParameters.movie.image_width_cm = exportParameters.movie_image_width_cm;
exportParameters.movie.name = exportParameters.movie_name;
exportParameters.movie.format = exportParameters.movie_format;
exportParameters.movie.fps = exportParameters.movie_fps;

% disable options for movie export that are not used in channel-only mode
exportParameters.movie.plot_f_bedrock = false;
exportParameters.movie.plot_terraces = false;
exportParameters.movie.contour_interval_depths = NaN;
exportParameters.movie.xc_xtick_interval_widths = NaN;
exportParameters.movie.xc_ytick_interval_depths = NaN;

% Remove fields defined from GUI to avoid duplication
exportParameters = rmfield(exportParameters,{'movie_frame_interval_yr',...
    'movie_image_width_cm','movie_name','movie_format','movie_fps'});

% save export parameters to file
exportParameters.trial = inputs.trial;
fname = [exportParameters.outputDir,'run_',exportParameters.trial,'_exportParameters.mat'];
save(fname,'exportParameters')
fprintf('Wrote %s to %s\n',fname,exportParameters.outputDir);
end