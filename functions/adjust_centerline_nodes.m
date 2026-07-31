function [centerline,cutoff_interp_stats] = adjust_centerline_nodes(centerline,w,init_spacing,x_increment,y_increment,z_increment,domain,vertical_incision_style,it,trial,data_directory,cutoff_interp_stats)
% adjust_centerline_nodes.m: Moves the nodes in the channel centerline and
% maintains proper centerline geometry throughout the model run.
% Input arguments:
%   centerline: Structure array with channel centerline coordinates.
%     w: chahnnel width
%     init_spacing: initial spacing of nodes in channel centerline
%     x_increment: increment to apply to cneterline x-coordinates
%     y_increment: increment to apply to cneterline y-coordinates
%     z_increment: increment to apply to cneterline z-coordinates
%     domain: structure array that describes geometry of the model domain
%     vertical_incision_style: for simulations with vertical incision, specifies the submodel for this process
%     it: model iteration
%     trial: name of model run
%     data_directory: directory for saving model files
%     cutoff_interp_stats: structure arry that stores data for cutoffs and interpolation of the channel centerline
% 
% Output arguments:
%     centerline: structur array with updated coordinates for channel centerline
%     cutoff_interp_stats: array with updated data for cutoffs and interpolation of channel centerline

% Add (x,y,z) increments to the channel centerline.
centerline.X = centerline.X + x_increment; 
centerline.Y = centerline.Y + y_increment; 
centerline.Z = centerline.Z + z_increment;

% Round centerline coordinates so that they are not affected by numerical precision issues
% (Numerical preicision in MATLAB is order 1e-16).
centerline.X=round(1e12*centerline.X)/1e12;
centerline.Y=round(1e12*centerline.Y)/1e12;
centerline.Z=round(1e12*centerline.Z)/1e12;               

% Ensure that the centerline stays roughly within the bounds of "domain.xExtent". As part of the periodic boundary condition,
% the centerline is repeated periodically upstream and downstream - but the fundamental centerline needs to stay in the vicinity of the domain extent.
% Do this by checking the fraction of centerline nodes that have drifted out of the domain in the x-direction. If greater than a critical fraction have
% drifted out of the model domain, shift the centerline back by "domain.xRange". From trial and error, a critical fraction between >0.5 and 1 works best.

domain.xRange = diff(domain.xExtent);
if numel(find(centerline.X<domain.xExtent(1)))>0.75*numel(centerline.X)             
centerline.X=centerline.X+domain.xRange;
end

if numel(find(centerline.X>domain.xExtent(2)))>0.75*numel(centerline.X)
centerline.X=centerline.X-domain.xRange;
end 

% For the case with stream power vertical incision, suppress formation of adverse slopes. Setting adverse slopes to zero was not enough because node
% upstream of the pit would feel a steep slope and cut down too
% far, thus making its own adverse slope, and the cuts got deeper and deeper, which make a propagating pit of increasing depth.
% Instead, put a limit on how far a node can cut down. 
% Starting from the end of the centerline and working up, compare the elevation of each node to its upstream neighbor. If an adverse slope exists
% between the two nodes (i.e., the upsteam neighbor has a lower elevation), then replace the current node elevation with the upstream neighbor's elevation.
switch vertical_incision_style
    case 'shear_stress'
    % For the stream power case, prevent the furthest downstream node from developing an adverse slope. This condition maintains
    % a monotonic vertical incision rate at the downstream boundary.
    last_adverse_node = find([diff(centerline.Z)>0;false],1,'last');
    while ~isempty(last_adverse_node)
        centerline.Z(last_adverse_node)=centerline.Z(last_adverse_node+1);
        last_adverse_node = find([diff(centerline.Z)>0;false],1,'last');
    end
end

% Check for neck cutoffs and locally interpolate the channel centerline as needed. 
[centerline,cutoff_interp_stats]=cutoff_interpolation(centerline,w,init_spacing,domain,cutoff_interp_stats,it,trial,data_directory); 

% Check that first and last centerline nodes have the same Y value
if abs(diff(centerline.Y([1 end])))>1e-3
    error('adujust_centerline_nodes.m: Centerline start and end Y-coordinates are offset')
end
    
end