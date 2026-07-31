function[Ro]=nominal_migration_rate(X,Y,w)
% nominal_migration_rate.m: Calculate nominal migration rate for each channel
% centerline node based on local curvature. Uses a periodic boundary condition 
% to compute the curvature at the centerline endpoints.
% Input arguments:
%     X: X-coordinates of channel centerline
%     Y: Y-coordinates of channel centerline
%     w: channel width
% Output arguments:
%     Ro: Nominal mingration rates, sensu Howard and Knutson (1984). 
    
% Geometry: [point 1] ----> [point 2] ----> [point 3]
L12=[[NaN;X(2:end)-X(1:end-1)],[NaN;Y(2:end)-Y(1:end-1)]]; % Nx2 array, where each row is the vector from point 1 to point 2.
L12(1,:)=[X(end)-X(end-1),Y(end)-Y(end-1)]; % For the first centerline node, set L12 using the the vector from node (end-1) to node (end).
L12 = L12./(repmat(sqrt(sum(L12.^2,2)),1,2)); % Normalize to create unit vectors.

L23=[[X(2:end)-X(1:end-1);NaN],[Y(2:end)-Y(1:end-1);NaN]]; % Nx2 array, where each row is the vector from point 2 to point 3.
L23(end,:)=[X(2)-X(1),Y(2)-Y(1)]; % For the last centerline node, set L23 using the the vector from node (1) to node (2).
L23 = L23./(repmat(sqrt(sum(L23.^2,2)),1,2)); % Normalize to create unit vectors.

% Determine the sign of phi, which sets the direction of node movement. Looking downstream, phi is positive where the centerline path is locally clockwise
% and negative where the centerline path is locally counter-clockwise. Use the vector cross-product to determine clockwise/counter-clockwise.
S=numel(X); % Number of nodes in the centerline.

L12=[L12,zeros(S,1)];
L23=[L23,zeros(S,1)];
cross_prod = L12(:,1).*L23(:,2) - L12(:,2).*L23(:,1); % third component of cross-product.
% In order to define clockwise as positive and counter-clockwise to be negative, multiply the sign of the cross-product by -1.

bend_sign = -sign(cross_prod); % sign function gives 1 for positive, 0 for 0, -1 for negative    
Rc = circle_only(X,Y); % For each node on the centerline, fit a circle to determine the local centerline radius of curvature.
Rc(isnan(Rc))=Inf; % Set radius of curvature to infinite where undefined.
Ro=w*bend_sign./Rc; % Nominal migration rate is the channel width divided by the local radius of curvature, with a sign factor.
end