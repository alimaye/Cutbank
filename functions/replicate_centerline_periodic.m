function [centerline_periodic] = replicate_centerline_periodic(centerline,nodes_add)
% replicate_centerline_periodic.m: Copies channel centerline upstream and
% downstream for a specified length.
% Input arguments:
%     centerline: structure array of coordinates for channel centerline
%     nodes_add: number of nodes to add upstream and downstream as part of the periodic boundary condition in the model
% Output arguments:
%     centerline_periodic: structure array of channel centerline
%     coordinates after replication upstream/downstream


if nodes_add >= numel(centerline.X)
    err='Error (replicate_centerline_periodic.m): Attempted to add too many nodes to periodically replicate centerline';
    filename=[outputDir,'run_',trial,'_error_data.mat'];
    save(filename)
    error(err)
end
    
centerline_xRange_orig = centerline.X(end) - centerline.X(1);
centerline_periodic.X=[centerline.X(end-nodes_add:(end-1))-centerline_xRange_orig; centerline.X; centerline.X(2:nodes_add+1,1)+centerline_xRange_orig];
centerline_periodic.Y=[centerline.Y(end-nodes_add:(end-1));centerline.Y;centerline.Y(2:nodes_add+1)]; 
centerline_periodic.Z=[(centerline.Z(end-nodes_add:(end-1))+(centerline.Z(1)-centerline.Z(end)));centerline.Z;(centerline.Z(2:nodes_add+1)-(centerline.Z(1)-centerline.Z(end)))];
if ~isequal(numel(centerline_periodic.X),numel(centerline_periodic.Y))
    err='Error (replicate_centerline_periodic.m): Node coordinate mismatch';
    filename=[outputDir,'run_',trial,'_error_data.mat'];
    save(filename)
    error(err)
end
end