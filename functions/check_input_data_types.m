function [inputs] = check_input_data_types(inputsFile)
% check_input_data_types.m: Loads file with model input parameters and 
% converts to desired format (string/numeric/logical) as appropriate.
% Input arguments: 
%   inputsFile: .mat file from which to load export parameters
% Output arguments:
%   inputs: structure array with model input parameters

load(inputsFile,'inputs')
v2struct(inputs); % Extract the fields of the structure array 'inputs' as separate variables.

% variables in all model runs
if ~ischar(BMT),BMT=num2str(BMT);end

% check arguments for BMT. Only allow 'channel-only', 'grid-based', or
% 'vector-based'
if ~strcmp(BMT,'channel-only') && ~strcmp(BMT,'vector-based') && ~strcmp(BMT,'grid-based')
    error('check_input_datatypes.m: Improper input for variable BMT. Must be either channel-only, vector-based, or grid-based');
end

if ischar(k_erode_sediment),k_erode_sediment=str2num(k_erode_sediment);end
if ischar(bed_elev_chg_rate), bed_elev_chg_rate=str2num(bed_elev_chg_rate); end
if ischar(w), w=str2num(w); end
if ischar(D), D=str2num(D); end
if ~ischar(vertical_incision_style), vertical_incision_style=num2str(vertical_incision_style); end
if ischar(t_max), t_max=str2num(t_max); end
if ischar(t_increment), t_increment=str2num(t_increment); end
if ischar(save_interval), save_interval=str2num(save_interval); end
if ischar(init_plane_slope), init_plane_slope=str2num(init_plane_slope); end
if ischar(centerline_spacing_coeff), centerline_spacing_coeff=str2num(centerline_spacing_coeff); end
if ischar(domain.xExtentChannelWidths), domain.xExtentChannelWidths=str2num(domain.xExtentChannelWidths); end
if ~ischar(startfile), startfile=num2str(startfile); end
if ischar(Cf), Cf = str2num(Cf); end
if ischar(epsilon), epsilon = str2num(epsilon); end
if ischar(g), g = str2num(g); end
if ischar(gam), gam = str2num(gam); end
if ischar(k), k=str2num(k);end
if ischar(om), om = str2num(om); end
if ischar(rho), rho = str2num(rho); end
if ~ischar(init_centerline_file), init_centerline_file = num2str(init_centerline_file); end
if ischar(enforceChannelDisplacementLimit), enforceChannelDisplacementLimit = logical(enforceChannelDisplacementLimit); end

% variables in model runs with bank-material tracking (vector-based or
% grid-based)
if ischar(k_erode_bedrock),k_erode_bedrock=str2num(k_erode_bedrock); end
if ischar(init_plane_max_elev), init_plane_max_elev=str2num(init_plane_max_elev); end
if ischar(unconfined_alluvial_belt_width),unconfined_alluvial_belt_width=str2num(unconfined_alluvial_belt_width); end
if ischar(init_alluv_width_coeff),init_alluv_width_coeff=str2num(init_alluv_width_coeff); end
if ischar(pulse_coeff),pulse_coeff=str2num(pulse_coeff);end
if ischar(overbank_deposition.enable), overbank_deposition.enable = str2num(overbank_deposition.enable);  overbank_deposition.enable = logical( overbank_deposition.enable); end
if ischar(overbank_deposition.modify_lateral_erosion_resistant_oxbows), overbank_deposition.modify_lateral_erosion_resistant_oxbows = str2num(overbank_deposition.modify_lateral_erosion_resistant_oxbows);  overbank_deposition.modify_lateral_erosion_resistant_oxbows = logical( overbank_deposition.modify_lateral_erosion_resistant_oxbows); end
if ischar(overbank_deposition.modify_lateral_erosion_bank_height), overbank_deposition.modify_lateral_erosion_bank_height = str2num(overbank_deposition.modify_lateral_erosion_bank_height);  overbank_deposition.modify_lateral_erosion_bank_height = logical( overbank_deposition.modify_lateral_erosion_bank_height); end
if ischar(overbank_deposition.parameters.nu), overbank_deposition.parameters.nu = str2num(overbank_deposition.parameters.nu); end
if ischar(overbank_deposition.parameters.mu_d), overbank_deposition.parameters.mu_d = str2num(overbank_deposition.parameters.mu_d); end
if ischar(overbank_deposition.parameters.lambda), overbank_deposition.parameters.lambda = str2num(overbank_deposition.parameters.lambda); end
if ischar(overbank_deposition.parameters.oxbow_erode_coeff), overbank_deposition.parameters.oxbow_erode_coeff = str2num(overbank_deposition.parameters.oxbow_erode_coeff); end
if ischar(bedrock_erosion.modify_lateral_erosion_bedrock), bedrock_erosion.modify_lateral_erosion_bedrock = str2num(bedrock_erosion.modify_lateral_erosion_bedrock); bedrock_erosion.modify_lateral_erosion_bedrock = logical(bedrock_erosion.modify_lateral_erosion_bedrock); end  

% Variables only enabled for vector-based bank-material tracking
if ischar(chkpt_spacing_coeff), chkpt_spacing_coeff=str2num(chkpt_spacing_coeff); end
if ischar(bed_elev_chg_poly_addn_thresh), bed_elev_chg_poly_addn_thresh=str2num(bed_elev_chg_poly_addn_thresh); end

% Variables only enabled for grid-based bank-material tracking
switch BMT
    case 'grid-based'
        % These parameters are specific to meander_gridded.m
        if ischar(cell_width), cell_width=str2num(cell_width); end
        if ischar(stratigraphy_3D.enable), stratigraphy_3D.enable = str2num(stratigraphy_3D.enable); stratigraphy_3D.enable = logical(stratigraphy_3D.enable); end  
        if ischar(stratigraphy_3D.delta_z),stratigraphy_3D.delta_z = str2num(stratigraphy_3D.delta_z); end
        if ischar(stratigraphy_3D.zMin),stratigraphy_3D.z_min = str2num(stratigraphy_3D.z_min); end
        if ischar(stratigraphy_3D.zMax),stratigraphy_3D.z_max = str2num(stratigraphy_3D.z_max); end
end

% Re-pack the variables in the structure array.
inputs_cell = who;
inputs_cell{end+1}='fieldNames'; % Needed for v2struct.m to use the variable names as structure fields.
inputs = v2struct(inputs_cell);
inputs = rmfield(inputs,'inputs'); % Exclude 'inputs', which was the input variable, as a field in the output structure 'inputs'
end