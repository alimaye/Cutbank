function[xinc,yinc,move_az] = calc_increment(X,Y,R1prime,t_increment)
% calc_increment.m: Calculates the increments for moving channel centerline 
% nodes. Nodes are moved perpendicular to the local channel azimuth in a direction 
% determined by the sign of R1prime.
% Input arguments:
%     X: x-coordinates for channel centerline
%     Y: y-coordinates for channel centerline
%     R1prime: vector used to calcutale lateral migration rates, calcualted in howard_knutson_periodic.m
%     t_increment: time increment
% Output arguments:
%     xinc: increment for x-coordinates in channel centerline
%     yinc: increment for y-coordinates in channel centerline
%     move_az: specifies local azimuth for shifts in channel centerline 

v1=[[X(end)-X(end-1);X(2:end)-X(1:end-1)],[Y(end)-Y(end-1);Y(2:end)-Y(1:end-1)]];
v2=[[X(2:end)-X(1:end-1);X(2)-X(1)],[Y(2:end)-Y(1:end-1);Y(2)-Y(1)]];
% normalize v1, v2 to get unit vectors
v1 = v1./(repmat(sqrt(sum(v1.^2,2)),1,2));
v2 = v2./(repmat(sqrt(sum(v2.^2,2)),1,2));
v3=v1+v2;
tangent_az=atan2(v3(:,2),v3(:,1));   
L=numel(R1prime);
move_az=zeros(L,1); 
move_az(R1prime>0)=tangent_az(R1prime>0)+pi/2;
move_az(R1prime<0)=tangent_az(R1prime<0)-pi/2;
xinc=t_increment*abs(R1prime).*cos(move_az);
yinc=t_increment*abs(R1prime).*sin(move_az);
xinc(isnan(xinc))=0;
yinc(isnan(yinc))=0;
xinc(isinf(xinc))=0;
yinc(isinf(yinc))=0;

end