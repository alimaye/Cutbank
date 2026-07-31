function [fname] = modelParameters_channelOnlyGUI()
% modelParameters_channelOnlyGUI.m: Generates a graphical user interface (GUI) for 
% entering input parameters for the model for runs with no bank-material tracking, 
% 3rd party software inputsdlg.m by Takeshi Ikuma that is included in this archive.
% Input arguments:
%   None
% Output arguments:
%   fname: name of the file to which input parmaeters are saved

if ispc
    addpath('..\3rdParty\inputsdlg') % add path to function inputsdlg.m
else
    addpath('../3rdParty/inputsdlg') % add path to function inputsdlg.m
end

%%% Initialize dialog box options
title = 'Meandering model inputs (Channel-only)'; % title for GUI dialog box
set(0,'DefaultUicontrolFontSize',9) % Set font size
options.Resize = 'on';
options.Interpreter = 'tex';
options.CancelButton = 'on';
options.ApplyButton = 'off';
options.ButtonNames = {'OK','Cancel'};

prompt = {}; % cell array to store preferences for prompts in the GUI
formats = struct; % structure array to store preferences for GUI appearance and data type
defAns = struct; % struture array to store default parameter values. 
%%%
nColumns = 2;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% COLUMN 1 %%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
i=1;
row = 1;
col = 1;
prompt(i,:) = {'\bf{1. Model domain and execution}',[],[]};
formats(row,col).type = 'text';

%%% The following code sets specifications for other parameters

i=i+nColumns;
row = 2;
col = 1;
% Run time
prompt(i,:) = {'Run time (yr)','t_max',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [0 1e7];
formats(row,col).size = [50 20];
defAns.t_max = 1000;

i=i+nColumns;
row=3;
col=1;
% Time increment
prompt(i,:) = {'Time increment (yr)','t_increment',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'integer'; % Note: may revise to float  
formats(row,col).limits = [0 1000];
formats(row,col).size = [50 20];
defAns.t_increment = 2;

i=i+nColumns;
row=4;
col=1;
% x-direction extent of model domain
prompt(i,:) = {'x-direction domain extent (channel widths)','xExtentChannelWidths',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
defAns.xExtentChannelWidths = 100;

i=i+nColumns;
row=5;
col=1;
% Centerline node spacing
prompt(i,:) = {'Centerline node spacing (channel widths)','centerline_spacing_coeff',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float'; 
formats(row,col).limits = [0.1 2]; 
formats(row,col).size = [50 20];
defAns.centerline_spacing_coeff = 1;

i=i+nColumns;
row=6;
col=1;
prompt(i,:) = {'Bank material tracking','BMT',[]}; % Description of variable, variable name, and limits for input values
formats(row,col).type = 'list'; % type of control ('check' | {'edit'} | 'list' | 'range' | 'text' | 'color' |'table' |'button' }'none')
formats(row,col).format = 'text'; % the data format for the variable ('text' | 'date' | 'float' | 'integer' | 'logical' | 'vector' | 'file' | 'dir']
formats(row,col).style = 'popupmenu'; % Type of user interface
formats(row,col).items = {'channel-only'}; % In this case, items available to select using the radio button
defAns.BMT = 'channel-only'; % define default answer for variable BMT and store in structure array defAns

i=i+nColumns;
row=7;
col=1;
prompt(i,:) = {''};
formats(row,col).type = 'text';

i=i+nColumns;
row=8;
col=1;
prompt(i,:) = {'\bf{2. Channel geometry and kinematics}',[],[]};
formats(row,col).type = 'text';

i=i+nColumns;
row=9;
col=1;
% channel width
prompt(i,:) = {'Channel width, \itw_c\rm (m)','w',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [0 1e6]; % 5-digits (positive #)
formats(row,col).size = [50 20];
defAns.w = 20;

i=i+nColumns;
row=10;
col=1;
% channel depth
prompt(i,:) = {'Channel depth, \ith_c\rm (m)','D',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [0 1e6];
formats(row,col).size = [50 20];
defAns.D = 1;

i=i+nColumns;
row=11;
col=1;
% Initial channel centerline geometry
prompt(i,:) = {'Initial channel centerline geometry','init_centerline_type',[]};
formats(row,col).type = 'list'; 
formats(row,col).format = 'text'; 
formats(row,col).style = 'popupmenu';
formats(row,col).items = {'straight','evolved','sinusoidal','custom'}; 
defAns.init_centerline_type = 'straight';

i=i+nColumns;
row=12;
col=1;
% File storing initial coordinates of channel centerline (optional)
prompt(i,:) = {'Initial centerline file (optional)','init_centerline_file',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'file';
formats(row,col).items = {'*.mat'}; % This forces it to be a .mat file, won't allow selection of other file formats
formats(row,col).limits = [0 1]; % This syntax (i.e., [0 1]) invokes uigetfile.m, which prompts user to select an existing file
defAns.init_centerline_file = '';

i=i+nColumns;
row=13;
col=1;
% Elevation of initial surface outside of channel
prompt(i,:) = {'Initial surface elevation outside channel (m)','init_plane_max_elev',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float'; 
formats(row,col).size = [50 20];
defAns.init_plane_max_elev = 0;

i=i+nColumns;
row=14;
col=1;
% Initial slope of plane
prompt(i,:) = {'Initial slope','init_plane_slope',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float'; 
formats(row,col).limits = [0 1];
formats(row,col).size = [50 20];
defAns.init_plane_slope = 0;

i=i+nColumns;
row=15;
col=1;
% Lateral erosion rate in sediment (m/yr)
prompt(i,:) = {'Sediment lateral erosion rate, \it{E_L_s}\rm (m/yr)','k_erode_sediment',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [0 1e3];
formats(row,col).size = [50 20];
defAns.k_erode_sediment = 1;

i=i+nColumns;
row=16;
col=1;
% Vertical incision style
prompt(i,:) = {'Vertical incison style','vertical_incision_style',[]}; % Description of variable, variable name, and limits for input values
formats(row,col).type = 'list';
formats(row,col).format = 'text'; 
formats(row,col).style = 'popupmenu';
formats(row,col).items = {'flat_steady' 'flat_unsteady','sloping_steady','shear_stress'};
defAns.vertical_incision_style = 'flat_steady'; % define default answer for variable BMT and store in structure array defAns

i=i+nColumns;
row=17;
col=1;
% Rate of bed elevation change
prompt(i,:) = {'Rate of bed elevation change, \it{dz/dt}\rm (m/yr)','bed_elev_chg_rate',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [-1e2 1e2];
formats(row,col).size = [50 20];
defAns.bed_elev_chg_rate = 0;

i=i+nColumns;
row=18;
col=1;
% Path to file with time series of vertical incision rate (optional)
prompt(i,:) = {'Time series of vertical incison rate (optional)','vertical_file',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'file';
formats(row,col).items = {'*.mat'}; % This forces it to be a .mat file, won't allow selection of other file formats
formats(row,col).limits = [0 1]; % This syntax (i.e., [0 1]) invokes uigetfile.m, which prompts user to select an existing file
defAns.vertical_file = '';

i=i+nColumns;
row=19;
col=1;
% Switch for starting model run with a pulse of vertical incision
prompt(i,:) = {'Limit channel displacement in one time step to \it{w_c}\rm','enforceChannelDisplacementLimit',[]};
formats(row,col).type = 'list';
formats(row,col).format = 'text';
formats(row,col).style = 'radiobutton';
formats(row,col).items = {'yes','no'};
defAns.enforceChannelDisplacementLimit = 'yes';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% COLUMN 2 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
i=2;
row=1;
col=2;
prompt(i,:) = {'\bf{3. Meandering model constants}',[],[]};
formats(row,col).type = 'text';

i=i+nColumns;
row=2;
col=2;
% Friction coefficient
prompt(i,:) = {'Friction coefficient, \it{C_f}','Cf',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [0 1];
formats(row,col).size = [50 20];
defAns.Cf=0.01;

i=i+nColumns;
row=3;
col=2;
% k (dimensionless coefficient for meandering model) 
prompt(i,:) = {'\it{k}','k',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
formats(row,col).size = [50 20];
defAns.k=1;
 
i=i+nColumns;
row=4;
col=2;
% Omega (dimensionless coefficient for meandering model) 
prompt(i,:) = {'\Omega','om',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
defAns.om=-1;

i=i+nColumns;
row=5;
col=2;
% Gamma (dimensionless coefficient for meandering model) 
prompt(i,:) = {'\Gamma','gam',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
defAns.gam=2.5;

i=i+nColumns;
row=6;
col=2;
% epsilon (dimensionless coefficient for meandering model) 
prompt(i,:) = {'\epsilon','epsilon',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
defAns.epsilon=-2/3;

i=i+nColumns;
row=7;
col=2;
prompt(i,:) = {''};
formats(row,col).type = 'text';

i=i+nColumns;
row=8;
col=2;
prompt(i,:) = {'\bf{4. Physical constants}',[],[]};
formats(row,col).type = 'text';

i=i+nColumns;
row=9;
col=2;
% Gravitational acceleration
prompt(i,:) = {'Gravitational acceleration, \it{g}\rm (m/s^2)','g',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
defAns.g=9.81;

i=i+nColumns;
row=10;
col=2;
% Density of water, rho (kg/m^3)
prompt(i,:) = {'Water density, \rho (kg/m^3)','rho',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
defAns.rho = 1000;

i=i+nColumns;
row=11;
col=2;
prompt(i,:) = {''};
formats(row,col).type = 'text';

i=i+nColumns;
row=12;
col=2;
prompt(i,:) = {'\bf{5. Input files}',[],[]};
formats(row,col).type = 'text';

i=i+nColumns;
row=13;
col=2;
% Existing input parameter file
prompt(i,:) = {'Existing input parameter file (optional)','inputFile',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'file';
formats(row,col).items = {'*.mat'}; % This forces it to be a .mat file, won't allow selection of other file formats
formats(row,col).limits = [0 1]; % This syntax (i.e., [0 1]) invokes uigetfile.m, which prompts user to select an existing file
defAns.inputFile = '';

i=i+nColumns;
row=14;
col=2;
% Path of file to restart simulation from (optional)
prompt(i,:) = {'Path of file to restart simulation from (optional)','startfile',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'file';
formats(row,col).items = {'*.mat'}; % This forces it to be a .mat file, won't allow selection of other file formats
formats(row,col).limits = [0 1]; % This syntax (i.e., [0 1]) invokes uigetfile.m, which prompts user to select an existing file
defAns.startfile = '';

i=i+nColumns;
row=15;
col=2;
prompt(i,:) = {''};
formats(row,col).type = 'text';

i=i+nColumns;
row=16;
col=2;
prompt(i,:) = {'\bf{6. Output files}',[],[]};
formats(row,col).type = 'text';

i=i+nColumns;
row=17;
col=2;
% Base name for file output
prompt(i,:) = {'Base name for file output','trial',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'text';
defAns.trial = 'test';

i=i+nColumns;
row=18;
col=2;
% Directory for file output
prompt(i,:) = {'Output directory','outputDir',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'dir';
formats(row,col).limits = [1 0]; % This syntax (i.e., [1 0]) invokes uiputfile.m, which prompts user to enter file to save to
defAns.outputDir = '';

i=i+nColumns;
row=19;
col=2;
% File output interval
prompt(i,:) = {'File output interval (yr)','save_interval',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float'; 
formats(row,col).limits = [0 Inf];
formats(row,col).size = [50 20];
defAns.save_interval = 500;

%%% Execute the dialog function. Parmaeters are stored in a structure
%%% array 'inputs'
[inputs,~] = inputsdlg(prompt,title,formats,defAns,options);

% convert any cell arrays in the structure to non-cell arrays
fields = fieldnames(inputs);
for k=1:numel(fields)
    if iscell(inputs.(fields{k}))
        inputs.(fields{k}) = cell2mat(inputs.(fields{k}));
    end
end
        
% order fields alphabetically
inputs = orderfields(inputs);

% check that output directory is defined; if not, throw an error
if isempty(inputs.outputDir)
    error('modelParameters_channelOnlyGUI.m: Must define output directory for model files');
end

% Add trailing slash to output directory 
if ispc
    inputs.outputDir = [inputs.outputDir,'\'];
else
    inputs.outputDir = [inputs.outputDir,'/'];
end



% Initial channel centerline geometry
switch inputs.init_centerline_type
    case {'straight','sinuous','sinusoidal'}
        % do nothing
    case 'custom'
        % check that the centerline file is defined and that it exists
        temp = ls(inputs.init_centerline_file);
        if isempty(temp)
            error('Path to initial centerline file undefined')
        end
end

% reassign inputs.xExtentChannelWidths to
% inputs.domain.xExtentChannelwidths
inputs.domain.xExtentChannelWidths = inputs.xExtentChannelWidths;
inputs = rmfield(inputs,'xExtentChannelWidths');


% Set other model parameters (for bank-material tracking) to false (for logical switches)
% or NaN (for numeric data)
inputs.bedrock_erosion.modify_lateral_erosion_bedrock=false;
inputs.k_erode_bedrock=NaN;
inputs.unconfined_alluvial_belt_width=NaN;
inputs.init_alluv_width_coeff=NaN;
inputs.init_Ev_pulse = false;
inputs.pulse_coeff=NaN;
inputs.overbank_deposition.enable=false;
inputs.overbank_deposition.modify_lateral_erosion_resistant_oxbows=false;
inputs.overbank_deposition.modify_lateral_erosion_bank_height=false;
inputs.overbank_deposition.parameters.nu=NaN;
inputs.overbank_deposition.parameters.mu_d=NaN;
inputs.overbank_deposition.parameters.lambda=NaN;
inputs.overbank_deposition.parameters.oxbow_erode_coeff=NaN;

% Parameters for vector-based bank-material tracking only
inputs.chkpt_spacing_coeff=NaN;
inputs.bed_elev_chg_poly_addn_thresh=NaN;

% save inputs to file
fname = [inputs.outputDir,'run_',inputs.trial,'_inputs.mat'];

save(fname,'inputs')
fprintf('Wrote %s to %s\n',fname,inputs.outputDir);
end