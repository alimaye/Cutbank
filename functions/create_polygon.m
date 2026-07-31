function [newpoly]=create_polygon(centerline,w,domain) 
% create_polygon.m: Generates a polygon representing the channel planform extent.
% The channel centerline is copied periodically; a polygon is generated from 
% the centerline; and the polygon is clipped to the model domain.
% Input arguments:
%   centerline: structure array with coordinates of channel centerline 
%   w: channel width
%   domain: structure array specifying geometry of model domain
% Output arguments:
%   newpoly: structure array with geoemtry of polgyon that represents channel planform extent

    % copy centerline upstream and downstream as one continuous form.
    nodes_add = numel(centerline.X)-1;
    centerline = replicate_centerline_periodic(centerline,nodes_add);
    [~,~,newpoly] = channel_margins(centerline,w);
    newpoly.hole=false;
    newpoly = PolygonClip(newpoly,domain.corners,1); % domain.corners has fields 'x' and 'y'
end