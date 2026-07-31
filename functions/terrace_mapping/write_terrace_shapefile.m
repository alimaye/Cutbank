function write_terrace_shapefile(metrics_file,dem,terrace_shapefile_name)
% write_terrace_shapefile.m: exports mapped terraces to a shapefile.
% Input arguments:
%   metrics_file: path to .mat file with terrace morphometrics
%   dem: structure array of elevation data
%   terrace_shapefilename: name for output shapefile
% Output arguments:
%   None

load(metrics_file,'metrics')

% write metrics to shapefile
for i=1:numel(metrics)
    shp(i).X=[];
    shp(i).Y=[];
    for j=1:size(metrics(i).boundary_coords_row_column,1)
        shp(i).X = [shp(i).X;dem.x(metrics(i).boundary_coords_row_column(j,1),metrics(i).boundary_coords_row_column(j,2))];
        shp(i).Y = [shp(i).Y;dem.y(metrics(i).boundary_coords_row_column(j,1),metrics(i).boundary_coords_row_column(j,2))];        
    end
    shp(i).BoundingBox=[min(shp(i).X) min(shp(i).Y); max(shp(i).X) max(shp(i).Y)];
    
    % make sure everything is a double for proper shapefile write
    shp(i).X = double(shp(i).X);
    shp(i).Y = double(shp(i).Y);
    shp(i).BoundingBox = double(shp(i).BoundingBox);
    
    shp(i).Geometry = 'Polygon';
    shp(i).terrace_ID=i; % just need another attribute to write .dbf file
    % had problems with writing other vectors to shp. but scalars
    % (e.g., slope values) work.
end
shapewrite(shp,terrace_shapefile_name)
end