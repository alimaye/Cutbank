function [init_alluv_poly] = create_init_alluv_poly(domain,init_alluv_width)
% create_init_alluv_poly.m: Creates data structure with geometry information 
% for the polygon that represents the initial alluvial belt.
% Input arguments:
%   domain: structure array that specifies geometry of model domain
%   init_alluv_width: initial width of area of sediment fill surrounding channel
% Output arguments:
%   init_alluv_poly: structure array with geometry of polygon that
%   represents the initial alluvial belt.

if isinf(init_alluv_width)
    init_alluv_poly.x = domain.corners.x;
    init_alluv_poly.y = domain.corners.y;
    init_alluv_poly.hole=false;
    init_alluv_poly.ymin=min(init_alluv_poly.y);
    init_alluv_poly.ymax=max(init_alluv_poly.y);
    init_alluv_poly.xmin=min(init_alluv_poly.x);
elseif init_alluv_width > 0
    init_alluv_poly.x = domain.corners.y;
    confine_half_width = init_alluv_width/2;
    init_alluv_poly.y = confine_half_width*[-1 1 1 -1]';
    init_alluv_poly.hole=false;
    init_alluv_poly.ymin=min(init_alluv_poly.y);
    init_alluv_poly.ymax=max(init_alluv_poly.y);
    init_alluv_poly.xmin=min(init_alluv_poly.x);
else
    init_alluv_poly.x = NaN;
    init_alluv_poly.y = NaN;
    init_alluv_poly.hole=false;
    init_alluv_poly.ymin=NaN;
    init_alluv_poly.ymax=NaN;
    init_alluv_poly.xmin=NaN;
end
end