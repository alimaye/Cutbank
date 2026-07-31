% wrapper02a_bedrockValley_gridded_runModel.m: Wrapper script for demonstrating
% model execution for a channel with vector-based bank-material tracking.

clear
clc
dbstop if error

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Edit model parameters %%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 1. Model domain and execution
t_max = 10000; % Run time (yr)
t_increment = 2; % Time increment (yr)
domain.xExtentChannelWidths = 100; % Extent of model domain, in channel widths.
centerline_spacing_coeff = 1; % Coefficient that sets node spacing coefficient along channel centerline, in channel widths.
BMT = 'vector-based';  % 'channel-only' | 'vector-based' | 'grid-based'. Method for bank-material tracking (BMT)
chkpt_spacing_coeff = 0.5; % Vector-based BMT only: controls the spacing of checkpoints along a bank-material inspection vector.
bed_elev_chg_poly_addn_thresh = 0.01; % Vector-based BMT only: cumulative vertical erosion before a new polygon for tracking bank materials is created (m)

% 2. Channel geometry and kinematics
w = 20; % Channel width, m.
D = 1; % Channel depth, m
init_centerline_type = 'straight'; % 'straight' | 'evolved' | 'sinusoidal' | 'custom'
init_centerline_file = 'none'; % Name of file that stores initial coordinates of channel centerline (optional).
init_plane_max_elev = 0; % Elevation of initial surface outside of channel.
init_plane_slope = 0; % Initial slope of plane into which channel is cut.
k_erode_sediment = 1; % Sediment erosion rate coeffient. Yields this erosion rate in m/yr.
vertical_incision_style = 'flat_steady';  % Style of vertical incision. 'flat_steady' imposes a constant (in space and time) vertical incision rate and zero slope. 'flat_unsteady' for a channel with no slope and unstead vertical incision rate; 'sloping_steady' for a channel with a slope and constant vertical incision rate; or 'shear_stress' for a channel with nonuniform vertical erosion rates set by the local slope at each channel centerline node.
bed_elev_chg_rate = -0.001; % Bed elevation change rate, m/yr (negative for erosion, positive for aggradation).
vertical_file = 'none'; % File for importing a predefined vertical incision rate time-series  (optional).
enforceChannelDisplacementLimit = true; % Logical switch that sets whether or not to throw an error if channel dispacement in one time step exceeds one channel width. 'true' | 'false'.

% 3. Geomorphic processes
% % Bedrock river valleys
bedrock_erosion.modify_lateral_erosion_bedrock = true; % Switch for modifying lateral erosion rates due to bedrock.
k_erode_bedrock = 0.1; % Bedrock erosion rate coeffient. Yields this erosion rate in m/yr.
unconfined_alluvial_belt_width = 50*w; % The width of the alluvial belt under unconfined conditions.
init_alluv_width_coeff = 0.25; % The imposed alluvial belt width, as a fraction of the previous variable.
init_Ev_pulse = false; % Flag for whether to start the simulation with a pulse of vertical incision (optional).
pulse_coeff = NaN; % Depth of initial channel incision, in channel depths (optional).

% % Floodplains
overbank_deposition.modify_lateral_erosion_bank_height = false; % Flag for varying lateral erosion rate inversely with bank height (true or false).
overbank_deposition.modify_lateral_erosion_resistant_oxbows = false; % Flag for changing the lateral erosion rate for oxbows (true or false).
overbank_deposition.parameters.oxbow_erode_coeff = NaN; % Fractional erodibilitity of oxbow-filling sediments relative to k_erode_sediment.

% Variables for overbank deposition.
overbank_deposition.enable = false;
% Parameters for Howard (1992) overbank deposition model.
overbank_deposition.parameters.nu = 0; % Rate of spatially uniform overbank deposition (m/yr)
overbank_deposition.parameters.mu_d = 0.001; % Maximum rate of space-dependent overbank deposition (m/yr)
overbank_deposition.parameters.lambda = w; % e-folding length for exponential decay in space-dependent overbank deposition rate (m).

% 4. Meandering model constants
Cf = 0.01; % Friction coefficient (dimensionless).
k = 1; % Coefficient for meandering model (dimensionless).
om = -1; % Coefficient for meandering model (dimensionless).
gam = 2.5; % Coefficient for meandering model (dimensionless).
epsilon = -2/3; % Coefficient for meandering model (dimensionless).

% 5. Physical constants
g = 9.81; % Gravitational acceleration (m/s2).
rho = 1000; % Density of water (kg/m3).

% 6. Input files
startfile = ''; % Path of file to restart simulation (optional).

% 7. Output files
trial = 'test_02'; % Base name for file output
save_interval = 1000; % File output interval (yr)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% End of parameters to edit
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% Set file paths and output directory
% Get path to highest-level directory (one above current)
currentDir = pwd;
if ispc
    slash = '\';
else 
    slash = '/';
end
ind = strfind(currentDir,slash);
directoryAbove = currentDir(1:ind(end));
% Create output directory
outputDir = [directoryAbove,'output',slash,'run_',trial,slash];
if ~exist(outputDir)
    mkdir(outputDir)
end
addpath(genpath(directoryAbove)) % Adds paths to all model directories
modelDataFile = [outputDir,'run_',trial,'_modelDataFinal.mat'];
clear currentDir slash ind directoryAbove

% Only one of the factors that modifies lateral erosion rates (i.e., bedrock,
% resistant oxbows, or bank height set up by overbank deposition) should
% modify lateral erosion rates. Here, check that only one of these
% processes is enabled and if not, throw an error.
if sum([bedrock_erosion.modify_lateral_erosion_bedrock ...
        overbank_deposition.modify_lateral_erosion_resistant_oxbows ...
            overbank_deposition.modify_lateral_erosion_bank_height]) > 1
    error('Only one process that modifies lateral erosion rates can be enabled. Check that only one of bedrock_erosion.modify_lateral_erosion_bedrock, overbank_deposition.modify_lateral_erosion_resistant_oxbows, or overbank_deposition.modify_lateral_erosion_bank_height is set to true')
end

%%% Pack all the variables together into a structure array to simplify I/O.
inputs_cell = who;
inputs_cell{end+1}='fieldNames'; % Needed for v2struct.m to use the variable names as structure fields.
inputs = v2struct(inputs_cell);

% save model parameters to file
modelParameterFile = [outputDir,'run_',trial,'_modelParameters.mat'];
save(modelParameterFile,'inputs')

% Skip file export
exportParameterFile='';

mode = 'runModel';

% Execute main function.
meander_execute(modelParameterFile,exportParameterFile,mode);