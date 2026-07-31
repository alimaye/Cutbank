function [leftBank,rightBank,channelFootprint] = channel_margins(centerline,w)
% channel_margins.m: Creates channel banks from the channel centerline and width. Bank geometry is output for the each bank (leftBank, rightBank) as well as the full channel area (channelFootprint, a polygon).
% Input arguments:
%   centerline: structure array for coordinates of channel centerline
%   w: channel width
% Output arguments:
%   leftBank: structure array that stores coordinates for downstream-left
%   bank
%   rightBank: structure array that stores coordinates for downstream-right
%   bank
%   channelFootprint: structure array that stores coordinates for the
%   overall footprint of the channel in mapview

nodes_add=2;
[centerline_periodic] = replicate_centerline_periodic(centerline,nodes_add);

v1=[[NaN;centerline_periodic.X(2:end)-centerline_periodic.X(1:end-1)],[NaN;centerline_periodic.Y(2:end)-centerline_periodic.Y(1:end-1)]];
v2=[[centerline_periodic.X(2:end)-centerline_periodic.X(1:end-1);NaN],[centerline_periodic.Y(2:end)-centerline_periodic.Y(1:end-1);NaN]];

% Normalize v1 and v2 to get unit vectors
ind0=v1==0;
v1 = v1./(repmat(sqrt(sum(v1.^2,2)),1,2));
v1(ind0)=0; % avoids getting NaN from divide by zero

ind0=v2==0;
v2 = v2./(repmat(sqrt(sum(v2.^2,2)),1,2));
v2(ind0)=0; % avoids getting NaN from divide by zero
v3=v1+v2;
tangent_az=atan2(v3(:,2),v3(:,1));
tangent_az([1 2 end-1 end])=[];

leftBank.X = centerline.X+(w/2)*cos(tangent_az+pi/2);
leftBank.Y = centerline.Y+(w/2)*sin(tangent_az+pi/2); 
rightBank.X= centerline.X+(w/2)*cos(tangent_az-pi/2);
rightBank.Y= centerline.Y+(w/2)*sin(tangent_az-pi/2); 
channelFootprint.x=[leftBank.X(end:-1:1);rightBank.X]; % lowercase 'x' and 'y' because these fields are used by PolygonClip
channelFootprint.y=[leftBank.Y(end:-1:1);rightBank.Y];
end