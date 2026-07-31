function [exportParameters] = check_export_data_types(exportParameterFile)
% check_export_data_types.m: Loads file with export parameters and converts 
% to desired format (string/numeric/logical) as appropriate.
% Input arguments:
%   exportParmaterFile: .mat file from which to load export parameters
% Output arguments:
%   exportParameters: structure array with parameters for file export

load(exportParameterFile,'exportParameters')
v2struct(exportParameters); % Extract the fields of the structure array as separate variables.
if ~ischar(exportParameters.outputDir),exportParameters.outputDir = num2str(exportParameters.outputDir);end
if ~ischar(exportParameters.modelParameterFile), exportParameters.modelParameterFile = num2str(exportParameters.modelParameterFile); end
if ~ischar(exportParameters.modelDataFile), exportParameters.modelDataFile=num2str(exportParameters.modelDataFile); end
if ischar(exportParameters.grid.export), exportParameters.grid.export = str2num(exportParameters.grid.export); exportParameters.grid.export = logical(exportParameters.grid.export); end
if ischar(exportParameters.grid.cell_width), exportParameters.grid.cell_width = str2num(exportParameters.grid.cell_width); end
if ischar(exportParameters.grid.export_interval_yr), exportParameters.grid.export_interval_yr = str2num(exportParameters.grid.export_interval_yr); end
if ischar(exportParameters.movie.export), exportParameters.movie.export = str2num(exportParameters.movie.export); exportParameters.movie.export = logical(exportParameters.movie.export); end
if ischar(exportParameters.movie.frame_interval_yr), exportParameters.movie.frame_interval_yr = str2num(exportParameters.movie.frame_interval_yr); end
if ischar(exportParameters.movie.contour_interval_depths), exportParameters.movie.contour_interval_depths = str2num(exportParameters.movie.contour_interval_depths); end
if ischar(exportParameters.movie.xc_ytick_interval_depths), exportParameters.movie.xc_ytick_interval_depths = str2num(exportParameters.movie.xc_ytick_interval_depths); end
if ischar(exportParameters.movie.xc_xtick_interval_widths), exportParameters.movie.xc_xtick_interval_widths = str2num(exportParameters.movie.xc_xtick_interval_widths); end
if ischar(exportParameters.movie.image_width_cm), exportParameters.movie.image_width_cm = str2num(exportParameters.movie.image_width_cm); end
if ischar(exportParameters.movie.plot_f_bedrock), exportParameters.movie.plot_f_bedrock = str2num(exportParameters.movie.plot_f_bedrock); exportParameters.movie.plot_f_bedrock = logical(exportParameters.movie.plot_f_bedrock); end
if ischar(exportParameters.movie.plot_terraces), exportParameters.movie.plot_terraces  = str2num(exportParameters.movie.plot_terraces ); exportParameters.movie.plot_terraces  = logical(exportParameters.movie.plot_terraces ); end

% Re-pack the variables in the structure array.
exportParameters_cell = who;
exportParameters_cell{end+1}='fieldNames'; % Needed for v2struct.m to use the variable names as structure fields.
exportParameters = v2struct(exportParameters_cell);

end