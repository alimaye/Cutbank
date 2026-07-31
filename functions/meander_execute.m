function meander_execute(modelParameterFile,exportParameterFile,mode)
% meander_execute.m: Function to execute meandering model and to generate
% output grids and/or movies.
% Input arguments:
%   modelParameterFile: name of file with model parameters
%   exportParameterFile: name of file with parameters for exporting grids
%   and/or movies.
%   mode: species method for bank-material tracking as vector-based,
%   grid-based, or none
% Output arguments:
%   None

if ne(nargin,3)
    err='Error (meander_execute.m): Improper number of inputs (3 required)'; 
    filename=[outputDir,'run_',trial,'_error_data.mat'];
    save(filename)
    error(err);
end

switch mode
    case {'runModel','runModel_and_exportGridsMovie'}
        % Check that input parameters are proper data types.
        modelParameters = check_input_data_types(modelParameterFile);

        switch modelParameters.BMT
            case 'channel-only'
                [~] = meander_vector(modelParameters);
            case 'vector-based'
                [~] = meander_vector(modelParameters);
            case 'grid-based'
                [~] = meander_gridded(modelParameters);
        end
end

switch mode
    case {'exportGridsMovie','runModel_and_exportGridsMovie'}
    exportParameters = check_export_data_types(exportParameterFile);
    
    temp = load(modelParameterFile);
    modelParameters.BMT = temp.inputs.BMT;  
    if exportParameters.grid.export || exportParameters.movie.export
        % Export grids and/or movie files
        switch modelParameters.BMT
            case {'vector-based','grid-based'}
                export_grids_movie(modelParameterFile,exportParameterFile);
            case 'channel-only'
                export_movie_channelOnly(modelParameterFile,exportParameterFile);
        end
    end
end