function [fname] = modelParametersGUI()
% modelParametersGUI.m: Generates a graphical user interface (GUI) for 
% entering input parameters for the model, using the 3rd party software 
% inputsdlg.m by Takeshi Ikuma that is included in this archive.
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
title = 'Meandering model inputs'; % title for GUI dialog box
set(0,'DefaultUicontrolFontSize',8) % Set font size
options.Resize = 'on';
options.Interpreter = 'tex';
options.CancelButton = 'on';
options.ApplyButton = 'off';
options.ButtonNames = {'OK','Cancel'};

prompt = {}; % cell array to store preferences for prompts in the GUI
formats = struct; % structure array to store preferences for GUI appearance and data type
defAns = struct; % struture array to store default parameter values. 
%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% COLUMN 1 %%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
i=1;
row = 1;
col = 1;
prompt(i,:) = {'\bf{1. Model domain and execution}',[],[]};
formats(row,col).type = 'text';

%%% The following code sets specifications for other parameters

i=i+3;
row = 2;
col = 1;
% Run time
prompt(i,:) = {'Run time (yr)','t_max',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [0 1e7];
formats(row,col).size = [50 20];
defAns.t_max = 1000;

i=i+3;
row=3;
col=1;
% Time increment
prompt(i,:) = {'Time increment (yr)','t_increment',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'integer'; % Note: may revise to float  
formats(row,col).limits = [0 1000];
formats(row,col).size = [50 20];
defAns.t_increment = 2;

i=i+3;
row=4;
col=1;
% x-direction extent of model domain
prompt(i,:) = {'domain x-extent (channel widths)','xExtentChannelWidths',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
defAns.xExtentChannelWidths = 100;

i=i+3;
row=5;
col=1;
% Centerline node spacing
prompt(i,:) = {'Centerline node spacing (channel widths)','centerline_spacing_coeff',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float'; 
formats(row,col).limits = [0.1 2]; 
formats(row,col).size = [50 20];
defAns.centerline_spacing_coeff = 1;

i=i+3;
row=6;
col=1;
prompt(i,:) = {'Bank material tracking','BMT',[]}; % Description of variable, variable name, and limits for input values
formats(row,col).type = 'list'; % type of control ('check' | {'edit'} | 'list' | 'range' | 'text' | 'color' |'table' |'button' }'none')
formats(row,col).format = 'text'; % the data format for the variable ('text' | 'date' | 'float' | 'integer' | 'logical' | 'vector' | 'file' | 'dir']
formats(row,col).style = 'popupmenu'; % Type of user interface
formats(row,col).items = {'vector-based' 'grid-based'}; % In this case, items available to select using the radio button
defAns.BMT = 'vector-based'; % define default answer for variable BMT and store in structure array defAns

i=i+3;
row=7;
col=1;
prompt(i,:) = {'   \bullet Model grid spacing (m; Grid-based only)','cell_width',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [1 1e3];
formats(row,col).size = [50 20];
defAns.cell_width=10;

i=i+3;
row=8;
col=1;
prompt(i,:) = {'\bf{2. Channel geometry and kinematics}',[],[]};
formats(row,col).type = 'text';

i=i+3;
row=9;
col=1;
% channel width
prompt(i,:) = {'Channel width, \itw_c\rm (m)','w',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [0 1e6]; % 5-digits (positive #)
formats(row,col).size = [50 20];
defAns.w = 20;

i=i+3;
row=10;
col=1;
% channel depth
prompt(i,:) = {'Channel depth, \ith_c\rm (m)','D',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [0 1e6];
formats(row,col).size = [50 20];
defAns.D = 1;

i=i+3;
row=11;
col=1;
% Initial channel centerline geometry
prompt(i,:) = {'Initial centerline geometry','init_centerline_type',[]};
formats(row,col).type = 'list'; 
formats(row,col).format = 'text'; 
formats(row,col).style = 'popupmenu';
formats(row,col).items = {'straight','evolved','sinusoidal','custom'}; 
defAns.init_centerline_type = 'straight';

i=i+3;
row=12;
col=1;
% File storing initial coordinates of channel centerline (optional)
prompt(i,:) = {'Initial centerline file (optional)','init_centerline_file',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'file';
formats(row,col).items = {'*.mat'}; % This forces it to be a .mat file, won't allow selection of other file formats
formats(row,col).limits = [0 1]; % This syntax (i.e., [0 1]) invokes uigetfile.m, which prompts user to select an existing file
defAns.init_centerline_file = '';

i=i+3;
row=13;
col=1;
% Elevation of initial surface outside of channel
prompt(i,:) = {'Initial elevation outside channel (m)','init_plane_max_elev',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float'; 
formats(row,col).size = [50 20];
defAns.init_plane_max_elev = 0;

i=i+3;
row=14;
col=1;
% Initial slope of plane
prompt(i,:) = {'Initial slope of plane','init_plane_slope',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float'; 
formats(row,col).limits = [0 1];
formats(row,col).size = [50 20];
defAns.init_plane_slope = 0;

i=i+3;
row=15;
col=1;
% Lateral erosion rate in sediment (m/yr)
prompt(i,:) = {'Sediment lateral erosion rate, \it{E_L_s}\rm (m/yr)','k_erode_sediment',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [0 1e3];
formats(row,col).size = [50 20];
defAns.k_erode_sediment = 1;

i=i+3;
row=16;
col=1;
% Vertical incision style
prompt(i,:) = {'Vertical incison style','vertical_incision_style',[]}; % Description of variable, variable name, and limits for input values
formats(row,col).type = 'list';
formats(row,col).format = 'text'; 
formats(row,col).style = 'popupmenu';
formats(row,col).items = {'flat_steady' 'flat_unsteady','sloping_steady','shear_stress'};
defAns.vertical_incision_style = 'flat_steady'; % define default answer for variable BMT and store in structure array defAns

i=i+3;
row=17;
col=1;
% Rate of bed elevation change
prompt(i,:) = {'Rate of bed elevation change, \it{dz/dt}\rm (m/yr)','bed_elev_chg_rate',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [-1e2 1e2];
formats(row,col).size = [50 20];
defAns.bed_elev_chg_rate = 0;

i=i+3;
row=18;
col=1;
% Path to file with time series of vertical incision rate (optional)
prompt(i,:) = {'Vertical incison rate timeseries (optional)','vertical_file',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'file';
formats(row,col).items = {'*.mat'}; % This forces it to be a .mat file, won't allow selection of other file formats
formats(row,col).limits = [0 1]; % This syntax (i.e., [0 1]) invokes uigetfile.m, which prompts user to select an existing file
defAns.vertical_file = '';

i=i+3;
row=19;
col=1;
% Switch for starting model run with a pulse of vertical incision
prompt(i,:) = {'Limit channel displacement to \it{w_c}\rm','enforceChannelDisplacementLimit',[]};
formats(row,col).type = 'list';
formats(row,col).format = 'text';
formats(row,col).style = 'radiobutton';
formats(row,col).items = {'yes','no'};
defAns.enforceChannelDisplacementLimit = 'yes';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% COLUMN 2
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
i=2;
row=1;
col=2;
prompt(i,:) = {'\bf{3. Geomorphic processes}',[],[]};
formats(row,col).type = 'text';

i=i+3;
row = 2;
col = 2;
% Processes that can modify lateral erosion rates
prompt(i,:) = {'Modidy lateral erosion rates by...','modify_lateral_erosion_process',[]};
formats(row,col).type = 'list'; 
formats(row,col).format = 'text'; 
formats(row,col).style = 'popupmenu';
formats(row,col).items = {'Bedrock','Resistant oxbows','Bank height','None'}; 
defAns.modify_lateral_erosion_process = 'None';

i=i+3;
row=3;
col=2;
prompt(i,:) = {''};
formats(row,col).type = 'text';

i=i+3;
row=4; 
col=2;
prompt(i,:) = {'\it{Bedrock river valleys}:',[],[]};
formats(row,col).type = 'text';

i=i+3;
row=5;
col=2;
% Lateral erosion rate in bedrock (m/yr)
prompt(i,:) = {'   \bullet Bedrock lateral erosion rate, \it{E_L_b}\rm (m/yr)','k_erode_bedrock',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [0 1e3];
formats(row,col).size = [50 20];
defAns.k_erode_bedrock = 0.01;

i=i+3;
row=6;
col=2;
% The width of the alluvial belt under unconfined conditions (m)
prompt(i,:) = {'   \bullet Width of unconfined alluvial belt (m)','unconfined_alluvial_belt_width',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
formats(row,col).limits = [0 Inf];
defAns.unconfined_alluvial_belt_width = 1000;


i=i+3;
row=7;
col=2;
% Initial alluvial belt width, as a fraction of the unconfined width
prompt(i,:) = {'   \bullet Initial alluvial belt width coefficient','init_alluv_width_coeff',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [0 1];
formats(row,col).size = [50 20];
defAns.init_alluv_width_coeff=0;

i=i+3;
row=8;
col=2;
% Switch for starting model run with a pulse of vertical incision
prompt(i,:) = {'   \bullet Initial vertical incision pulse','init_Ev_pulse',[]};
formats(row,col).type = 'list';
formats(row,col).format = 'text';
formats(row,col).style = 'radiobutton';
formats(row,col).items = {'yes','no'};
defAns.init_Ev_pulse = 'no';

i=i+3;
row=9;
col=2;
% Depth of initial channel incision, in channel depths (optional)
prompt(i,:) = {'      \rightarrow Depth of incision (channel depths) (optional)','pulse_coeff',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [0 Inf];
formats(row,col).size = [50 20];
defAns.pulse_coeff=0;

i=i+3;
row=10;
col=2;
prompt(i,:) = {''};
formats(row,col).type = 'text';

i=i+3;
row=11;
col=2;
prompt(i,:) = {'\it{Floodplains}:',[],[]};
formats(row,col).type = 'text';

i=i+3;
row=12;
col=2;
% Relative erodibility of oxbow-filling sediments relative to k_erode_sediment
prompt(i,:) = {'   \bullet Relative erodibility of oxbow-filling sediments',...
    'overbank_deposition_oxbow_erode_coeff',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float'; 
formats(row,col).limits = [0 1];
formats(row,col).size = [50 20];

i=i+3;
row=13;
col=2;
% Switch for overbank deposition
prompt(i,:) = {'   \bullet Enable overbank deposition','overbank_deposition_enable',[]};
formats(row,col).type = 'list';
formats(row,col).format = 'text';
formats(row,col).style = 'radiobutton';
formats(row,col).items = {'yes','no'};
defAns.overbank_deposition_enable = 'no';

i=i+3;
row=14;
col=2;
prompt(i,:) = {'         Overbank deposition parameters:',[],[]};
formats(row,col).type = 'text';

i=i+3;
row=15;
col=2;
% Rate of spatially uniform overbank deposition (m/yr)
prompt(i,:) = {'         \rightarrow Spatially uniform deposition rate (m/yr)',...
    'overbank_deposition_nu',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float'; 
formats(row,col).limits = [0 100];
formats(row,col).size = [50 20];

i=i+3;
row=16;
col=2;
% Maximum space-dependent deposition rate (m/yr)
prompt(i,:) = {'         \rightarrow Maximum space-dependent deposition rate (m/yr)',...
    'overbank_deposition_mu_d',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float'; 
formats(row,col).limits = [0 100];
formats(row,col).size = [50 20];

i=i+3;
row=17;
col=2;
% e-folding length for decay in space-dependent overbank
% deposition rate (m)
prompt(i,:) = {'         \rightarrow Deposition decay lengthscale (m)',...
    'overbank_deposition_lambda',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float'; 
formats(row,col).limits = [0 1e6];
formats(row,col).size = [50 20];

i=i+3;
row=18;
col=2;
prompt(i,:) = {''};
formats(row,col).type = 'text';

i=i+3;
row=19;
col=2;
prompt(i,:) = {''};
formats(row,col).type = 'text';

% i=i+3;
% row=20;
% col=2;
% prompt(i,:) = {''};
% formats(row,col).type = 'text';
% 
% i=i+3;
% row=21;
% col=2;
% prompt(i,:) = {''};
% formats(row,col).type = 'text';
% 
% i=i+3;
% row=22;
% col=2;
% prompt(i,:) = {''};
% formats(row,col).type = 'text';
% 
% i=i+3;
% row=23;
% col=2;
% prompt(i,:) = {''};
% formats(row,col).type = 'text';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% COLUMN 3 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
i=3;
row=1;
col=3;
prompt(i,:) = {'\bf{4. Meandering model constants}',[],[]};
formats(row,col).type = 'text';

i=i+3;
row=2;
col=3;
% Friction coefficient
prompt(i,:) = {'Friction coefficient, \it{C_f}','Cf',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).limits = [0 1];
formats(row,col).size = [50 20];
defAns.Cf=0.01;

i=i+3;
row=3;
col=3;
% k (dimensionless coefficient for meandering model) 
prompt(i,:) = {'\it{k}','k',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
formats(row,col).size = [50 20];
defAns.k=1;
 
i=i+3;
row=4;
col=3;
% Omega (dimensionless coefficient for meandering model) 
prompt(i,:) = {'\Omega','om',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
defAns.om=-1;

i=i+3;
row=5;
col=3;
% Gamma (dimensionless coefficient for meandering model) 
prompt(i,:) = {'\Gamma','gam',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
defAns.gam=2.5;

i=i+3;
row=6;
col=3;
% epsilon (dimensionless coefficient for meandering model) 
prompt(i,:) = {'\epsilon','epsilon',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
defAns.epsilon=-2/3;

i=i+3;
row=7;
col=3;
prompt(i,:) = {''};
formats(row,col).type = 'text';

i=i+3;
row=8;
col=3;
prompt(i,:) = {'\bf{5. Physical constants}',[],[]};
formats(row,col).type = 'text';

i=i+3;
row=9;
col=3;
% Gravitational acceleration
prompt(i,:) = {'Gravitational acceleration, \it{g}\rm (m/s^2)','g',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
defAns.g=9.81;

i=i+3;
row=10;
col=3;
% Density of water, rho (kg/m^3)
prompt(i,:) = {'Water density, \rho (kg/m^3)','rho',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float';
formats(row,col).size = [50 20];
defAns.rho = 1000;

i=i+3;
row=11;
col=3;
prompt(i,:) = {''};
formats(row,col).type = 'text';

i=i+3;
row=12;
col=3;
prompt(i,:) = {'\bf{6. Input files}',[],[]};
formats(row,col).type = 'text';

i=i+3;
row=13;
col=3;
% Existing input parameter file
prompt(i,:) = {'Existing input parameter file (optional)','inputFile',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'file';
formats(row,col).items = {'*.mat'}; % This forces it to be a .mat file, won't allow selection of other file formats
formats(row,col).limits = [0 1]; % This syntax (i.e., [0 1]) invokes uigetfile.m, which prompts user to select an existing file
defAns.inputFile = '';

i=i+3;
row=14;
col=3;
% Path of file to restart simulation from (optional)
prompt(i,:) = {'Simulation restart file (optional)','startfile',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'file';
formats(row,col).items = {'*.mat'}; % This forces it to be a .mat file, won't allow selection of other file formats
formats(row,col).limits = [0 1]; % This syntax (i.e., [0 1]) invokes uigetfile.m, which prompts user to select an existing file
defAns.startfile = '';

i=i+3;
row=15;
col=3;
prompt(i,:) = {''};
formats(row,col).type = 'text';

i=i+3;
row=16;
col=3;
prompt(i,:) = {'\bf{7. Output files}',[],[]};
formats(row,col).type = 'text';

i=i+3;
row=17;
col=3;
% Base name for file output
prompt(i,:) = {'Base name for file output','trial',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'text';
defAns.trial = 'test';

i=i+3;
row=18;
col=3;
% Directory for file output
prompt(i,:) = {'Output directory','outputDir',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'dir';
formats(row,col).limits = [1 0]; % This syntax (i.e., [1 0]) invokes uiputfile.m, which prompts user to enter file to save to
defAns.outputDir = '';

i=i+3;
row=19;
col=3;
% File output interval
prompt(i,:) = {'File output interval (yr)','save_interval',[]};
formats(row,col).type = 'edit';
formats(row,col).format = 'float'; 
formats(row,col).limits = [0 Inf];
formats(row,col).size = [50 20];
defAns.save_interval = 500;

% i=i+3;
% row=20;
% col=3;
% % File output interval
% prompt(i,:) = {''};
% formats(row,col).type = 'text';
% 
% i=i+3;
% row=21;
% col=3;
% prompt(i,:) = {''};
% formats(row,col).type = 'text';
% 
% i=i+3;
% row=22;
% col=3;
% prompt(i,:) = {''};
% formats(row,col).type = 'text';
% 
% i=i+3;
% row=23;
% col=3;
% prompt(i,:) = {''};
% formats(row,col).type = 'text';

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

% Add trailing slash to output directory 
if ispc
    inputs.outputDir = [inputs.outputDir,'\'];
else
    inputs.outputDir = [inputs.outputDir,'/'];
end

% reassign inputs.xExtentChannelWidths to
% inputs.domain.xExtentChannelwidths
inputs.domain.xExtentChannelWidths = inputs.xExtentChannelWidths;
inputs = rmfield(inputs,'xExtentChannelWidths');

% assign default values for vector-based bank-material tracking. That is
% done here to reduce clutter in the GUI.
if strcmp(inputs.BMT,'vector-based')
    inputs.bed_elev_chg_poly_addn_thresh = 0.01;
    inputs.chkpt_spacing_coeff = 1;
    fprintf('Default parameters assigned for vector-based bank material tracking\n');
else
    inputs.bed_elev_chg_poly_addn_thresh = NaN;
    inputs.chkpt_spacing_coeff = NaN;
end

switch inputs.modify_lateral_erosion_process
    case 'Bedrock'
        inputs.bedrock_erosion.modify_lateral_erosion_bedrock = true;
        inputs.overbank_deposition.modify_lateral_erosion_resistant_oxbows = false;
        inputs.overbank_deposition.modify_lateral_erosion_bank_height = false;
    case 'Resistant oxbows'
        inputs.bedrock_erosion.modify_lateral_erosion_bedrock = false;
        inputs.overbank_deposition.modify_lateral_erosion_resistant_oxbows = true;
        inputs.overbank_deposition.modify_lateral_erosion_bank_height = false;
    case 'Bank height'
        inputs.bedrock_erosion.modify_lateral_erosion_bedrock = false;
        inputs.overbank_deposition.modify_lateral_erosion_resistant_oxbows = false;
        inputs.overbank_deposition.modify_lateral_erosion_bank_height = true;
    case 'None'
        inputs.bedrock_erosion.modify_lateral_erosion_bedrock = false;
        inputs.overbank_deposition.modify_lateral_erosion_resistant_oxbows = false;
        inputs.overbank_deposition.modify_lateral_erosion_bank_height = false;
end
% Remove field defined from GUI to avoid duplication
inputs = rmfield(inputs,'modify_lateral_erosion_process');

% Convert yes/no to logical
switch inputs.overbank_deposition_enable 
    case 'yes'
        inputs.overbank_deposition.enable = true;
    case 'no'
        inputs.overbank_deposition.enable = false;
end
inputs.overbank_deposition.parameters.nu = inputs.overbank_deposition_nu;
inputs.overbank_deposition.parameters.mu_d = inputs.overbank_deposition_mu_d;
inputs.overbank_deposition.parameters.lambda = inputs.overbank_deposition_lambda;
inputs.overbank_deposition.parameters.oxbow_erode_coeff = inputs.overbank_deposition_oxbow_erode_coeff;
% Remove fields defined from GUI to avoid duplication
inputs = rmfield(inputs,{'overbank_deposition_enable','overbank_deposition_nu',...
    'overbank_deposition_mu_d','overbank_deposition_lambda','overbank_deposition_oxbow_erode_coeff'});

% Check that if overbank deposition is enabled, and if not, assign default
% value
if inputs.overbank_deposition.enable
    if isempty(inputs.overbank_deposition.parmeters.nu)
        inputs.overbank_deposition.parmeters.nu = 0;
        fprintf('Default parameter(s) assigned for overbank deposition\n');
    end
    if isempty(inputs.overbank_deposition.parameters.mu_d)
        inputs.overbank_deposition.parameters.mu_d = 0.01;
        fprintf('Default parameter(s) assigned for overbank deposition\n');
    end
    if isempty(inputs.overbank_deposition.parameters.lambda)
        inputs.overbank_deposition.parameters.mu_d = inputs.channel_width;
        fprintf('Default parameter(s) assigned for overbank deposition\n');
    end
end

% Disable 3D stratigraphy and set assocaited parameters to NaN
inputs.stratigraphy_3D.enable = false;
inputs.stratigraphy_3D.delta_z= NaN;
inputs.stratigraphy_3D.zMin = NaN;
inputs.stratigraphy_3D.zMax = NaN;

% Initial channel centerline geometry
switch inputs.init_centerline_type
    case {'straight','evolved','sinusoidal'}
        % do nothing
    case 'custom'
        % check that the centerline file is defined and that it exists
        temp = ls(inputs.init_centerline_file);
        if isempty(temp)
            error('Path to initial centerline file undefined')
        end
end

% Convert yes/no to logical
switch inputs.init_Ev_pulse
    case 'yes'
        inputs.init_Ev_pulse = true;
    case 'no'
        inputs.init_Ev_pulse = false;
end

% save inputs to file
fname = [inputs.outputDir,'run_',inputs.trial,'_inputs.mat'];

save(fname,'inputs')
fprintf('Wrote %s to %s\n',fname,inputs.outputDir);
end