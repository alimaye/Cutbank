function [centerline] = create_centerline_geometry(init_centerline_type,init_centerline_file,init_plane_max_elev,w,D,init_plane_slope,init_spacing,domain)
% create_centerline_geometry.m: Creates channel centerline geometry. 
% Input arguments:
%    init_centerline_type: specifies geometric model for creating channel
%    centerline
%    init_centerline_file: optionally, specifies channel centerline from a
%    file
%    init_plane_max_elev: maximum elevation of plane that defines initial
%    topography surround the channel
%    w: channel width
%    D: channel depth
%    init_plane_slope: slope of initial plane surrounding channel
%    init_spacing: initial spacing of nodes within channel centerline
%    domain: structure array that specifies geometry of model domain
% Output arguments:
%   centerline: structure array width coordinates of channel centerline


%%% Load or create centerline (X,Y) coordinates
if ~isempty(init_centerline_file) && ~isempty(dir(init_centerline_file))
    load(init_centerline_file,'centerline') % Load the channel centerline structure (with fields "X" and "Y") from an existing file.
else
    centerline.X=(0:init_spacing:(domain.xExtentChannelWidths*w))'; % Establish the X-coordinates of the channel centerline to span the x-direction extent of the domain.
    switch init_centerline_type
       case {'straight','evolved'}
            % Initialize the channel centerline Y-coordinates from noise.   
            % In compiled applications, that MATLAB built-in function "rand" can give the
            % same numbers for different executions. In order to overcome this, use the current time to reset the random number generator. For more information, see http://www.mathworks.com/support/solutions/en/data/1-18WH6/
            reset(RandStream.getGlobalStream,sum(100*clock));
            centerline.Y=rand(size(centerline.X)); % Initialize the centerline y-coordinates with meter-scale, pseudo-random noise.
       case 'sinusoidal'
            
           centerline_xRange_temp = [centerline.X(1)+init_spacing/2 centerline.X(end)+init_spacing/2];
           % need to fit an integer number of wavelengths in the domain so
           % centerline.Y(1) is approximately centerline.Y(end).
           nominal_wavelength=10*w; % i.e., set nominal meander wavelength to 10 channel widths, after Leopold et al. (1960).
           n_loops=round(range(centerline_xRange_temp)/nominal_wavelength);
           adjusted_wavelength=range(centerline_xRange_temp)/n_loops; % True wavelength differs from nominal wavelength so that an integer number of wavelengths fits within the model domain
           centerline.Y = 5*w*sin(2*pi*centerline.X*1/(adjusted_wavelength))+[0;rand(numel(centerline.X)-2,1);0];
        case 'custom'
            % Coordinates should already be defined using the
            % initial centerline file, so if this point is reached then
            % throw an error.
            err='Error (create_centerline_geometry.m): init_centerline_type set to "custom" but init_centerline_file not found';
            filename=[outputDir,'run_',trial,'_error_data.mat'];
            save(filename)
            error(err)            
    end
end

switch init_centerline_type
    case {'straight','evolved','sinusoidal'}
        % Enforce boundary conditions for (X,Y) coordinates
        centerline.Y(end)=centerline.Y(1); % As part of the periodic boundary condition, set the starting and ending nodes of the channel centerline have the same y-coordinate.
        centerline.X = centerline.X-centerline.X(1); % Start the centerline X coordinate at the convenient value of zero.

        %%% Create centerline Z coordinates (i.e., longitudinal profile)
        init_along_valley_relief=range(domain.xExtentChannelWidths*w)*init_plane_slope; % valley relief = domain.xExtent*init_plane_slope
        channel_cumulative_distance=[0;cumsum(sqrt(sum(diff([centerline.X,centerline.Y],1,1).^2,2)))]; % calculate distance along the channel
        % determine the constant channel slope: init_channel_slope =
        % valley_relief/channel_length
        init_channel_slope=init_along_valley_relief/channel_cumulative_distance(end);

        % Initialize a longitudinal profile with this constant channel slope. The highest
        % point on the centerline is set at the initial maximum elevation of the
        % surrounding plane, inset by the channel depth.
        centerline.Z=(init_plane_max_elev-D)-init_channel_slope*channel_cumulative_distance;
    case 'custom'
        % Adjust the coordinates to (1) match the periodic boundary condition (subtract x- and
        % y-offsets, rotate opposite angle from start to end point so points west to east, find
        % azimuths and trim to the first and last points with east-directed
        % azimuths; and (2) interpolate to node spacing 'init_spacing'
        
        % subtract x- and y- offsets from loaded coordinates
        centerline.import.XoffsetMeters = centerline.X(1);
        centerline.import.YoffsetMeters = centerline.Y(1);
        centerline.X = centerline.X - centerline.X(1);
        centerline.Y = centerline.Y - centerline.Y(1);

        % find the angle from the starting point to the ending point and
        % substract it from the coordinates so that the direction is
        % west-to-east
        vSE = [centerline.X(end)-centerline.X(1),centerline.Y(end)-centerline.Y(1)]; % vector from start to end of centerline
        % normalize vector
        ind0 = vSE==0;
        vSE = vSE./(repmat(sqrt(sum(vSE.^2,2)),1,2));
        vSE(ind0)=0; % avoids getting NaN from divide by zero
        centerline.import.angularOffsetRadians = atan2(vSE(2),vSE(1)); % % i.e., initial angle, in radians and measured counterclockwise, between the origin and the vector from start-to-end of centerline, 
        rotationAngle = -centerline.import.angularOffsetRadians; % i.e., we want to rotate in the direction opposite the angular offset
        % Rotate so that vector from start to end of segment is aligned with
        % x-axis
        R = [cos(rotationAngle) -sin(rotationAngle); sin(rotationAngle) cos(rotationAngle)];
        xy = [centerline.X';centerline.Y'];
        xyRotated = R*xy; % matrix multiplication. R must be on the left (https://en.wikipedia.org/wiki/Rotation_matrix)
        centerline.X = xyRotated(1,:)';
        centerline.Y = xyRotated(2,:)';
        
        %%% get node-to-node azimuth series

        % Centered-difference azimuth series, "unwrapped" to remove abrupt jumps due to crossings of
        % 0,2*pi
        v1=[[NaN;centerline.X(2:end)-centerline.X(1:end-1)],[NaN;centerline.Y(2:end)-centerline.Y(1:end-1)]];
        v2=[[centerline.X(2:end)-centerline.X(1:end-1);NaN],[centerline.Y(2:end)-centerline.Y(1:end-1);NaN]];
        
        % Normalize v1 and v2 to get unit vectors
        ind0=v1==0;
        v1 = v1./(repmat(sqrt(sum(v1.^2,2)),1,2));
        v1(ind0)=0; % avoids getting NaN from divide by zero
        
        ind0=v2==0;
        v2 = v2./(repmat(sqrt(sum(v2.^2,2)),1,2));
        v2(ind0)=0; % avoids getting NaN from divide by zero
        v3=v1+v2;
        centerline.A=atan2(v3(:,2),v3(:,1));
        
        % assign azimuth for endpoints
        centerline.A(1)=centerline.A(2);
        centerline.A(end) = centerline.A(end-1);
        
        % "unwrap" azimuth series to prevent abrupt jumps
        centerline.A = unwrap(centerline.A);

        % find first and last zero-crossings of azimuth and trim centerline
        % to these points
        [~,~,iZeroAzIntersections,~] = intersections((1:numel(centerline.A))',centerline.A,[1;numel(centerline.A)],[0;0]);
        
        iStart = iZeroAzIntersections(1);
        iEnd = iZeroAzIntersections(end);
        XStart = interp1(1:numel(centerline.X),centerline.X,iStart);
        XEnd = interp1(1:numel(centerline.X),centerline.X,iEnd);
        YStart = interp1(1:numel(centerline.Y),centerline.Y,iStart);
        YEnd = interp1(1:numel(centerline.Y),centerline.Y,iEnd);
        
        centerline.X = [XStart; centerline.X(ceil(iStart):floor(iEnd));XEnd];
        centerline.Y = [YStart; centerline.Y(ceil(iStart):floor(iEnd));YEnd];
        centerline.distance=[0;cumsum(sqrt(sum(diff([centerline.X,centerline.Y],1,1).^2,2)))]; % calculate distance along the channel
      
        % interpolate to node spacing 'init_spacing'
        distanceNew = (0:init_spacing:max(centerline.distance))'; % note that only linear interpolation will output these distances precisely
        xyNew=interp1(centerline.distance,[centerline.X,centerline.Y],distanceNew,'spline'); % spline and node spacing after Guneralp and Rhoads (2008). They recommend 0.5 or 1 w as the spacing (greater noise for 0.5). 
        centerline.X = xyNew(:,1);
        centerline.Y = xyNew(:,2);
        
        % Remove remaining rotation so starting and ending y-coordinates
        % are equal

        % find the angle from the starting point to the ending point and
        % substract it from the coordinates so that the direction is
        % west-to-east
        vSE = [centerline.X(end)-centerline.X(1),centerline.Y(end)-centerline.Y(1)]; % vector from start to end of centerline
        % normalize vector
        ind0 = vSE==0;
        vSE = vSE./(repmat(sqrt(sum(vSE.^2,2)),1,2));
        vSE(ind0)=0; % avoids getting NaN from divide by zero
        
        newAngularOffsetRadians= atan2(vSE(2),vSE(1)); % % i.e., initial angle, in radians and measured counterclockwise, between the origin and the vector from start-to-end of centerline, 
        centerline.import.angularOffsetRadians = centerline.import.angularOffsetRadians + newAngularOffsetRadians; % update angular offset
        rotationAngle = -newAngularOffsetRadians; % i.e., we want to rotate in the direction opposite the angular offset
        % Rotate so that vector from start to end of segment is aligned with
        % x-axis
        R = [cos(rotationAngle) -sin(rotationAngle); sin(rotationAngle) cos(rotationAngle)];
        xy = [centerline.X';centerline.Y'];
        xyRotated = R*xy; % matrix multiplication. R must be on the left (https://en.wikipedia.org/wiki/Rotation_matrix)
        centerline.X = xyRotated(1,:)';
        centerline.Y = xyRotated(2,:)';
        centerline.Z = zeros(size(centerline.X)); %% this could be replaced in the future, but for now use placeholder elevations for longitudinal profile
end