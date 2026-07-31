function [x_increment,y_increment,z_increment,move_az,mu,k_meander,R1prime] = howard_knutson_periodic(initialization_tf,max_step_init,data_directory,trial,centerline,init_spacing,w,D,Cf,k,om,gam,epsilon,k_meander,t_increment,vertical_incision_style,bed_elev_chg_rate,it)
% howard_knutson_periodic.m: Calculates channel lateral migration rates 
% using an implementation of the Howard and Knutson (1984) meandering model.
% Input arguments:
%   initialization_tf: Logical flag that species whether to run the model
%   in initialization mode.
%   max_step_init: desired maximum lateral erosion rate for initialization
%   phase
%   data_directory: directory for saving model files
%   trial: name of model run
%   centerline: structure array with channel centerline coordinates
%   init_spacing: initial spacing of nodes in channel centerline
%   w: channel width
%   D: channel depth
%   Cf: dimensionless friction coefficient
%   k: dimensionless coefficient for Howard and Knutson (1984) meandering model
%   om: dimensionless coefficient for Howard and Knutson (1984) meandering model
%   gam: dimensionless coefficient for Howard and Knutson (1984) meandering model
%   epsilon: dimensionless coefficient for Howard and Knutson (1984) meandering model
%   k_meander: rate constant for specifying lateral erosion rates
%   t_increment: time increment
%   vertical_incision_style: for simulations with vertical incision, specifies the submodel for this process
%   bed_elev_chg_rate: rate elevation change for channel bed
%   it: model iteration
% Output arguments:
%   x_increment: increment to apply to centerline x-coordinates
%   y_increment: increment to apply to centerline y-coordinates
%   z_increment: increment to apply to centerline z-coordinates
%   move_az: specifies local azimuth for shifts in channel centerline 
%   mu: sinuosity of channel centerline
%   k_meander: updated rate constant for lateral erosion rates
%   R1prime: vector used to calculate lateral migration rates, calculated in howard_knutson_periodic.m

    alpha=2*k*Cf/D; % weighting coefficient; Equation (6) in Howard and Knutson (1984)

    % Calculate nominal migration rate at all centerline nodes.
    S=numel(centerline.X); % Number of nodes in the centerline.
    Ro=nominal_migration_rate(centerline.X,centerline.Y,w); % Nomimal migration rate based on local curvature.

    % Set distance for curvature integration as distance at which the weighting factor falls below 1% of it's value at zero distance upstream. 
    integration_distance = interp1(exp(-alpha*(0:max(centerline.X))),0:max(centerline.X),0.01); % meters

    % Determine the maximum number of centerline nodes to integrate curvature upstream.
    upper_integ_limit_max = round(1.5*integration_distance/init_spacing); 

    if upper_integ_limit_max > S % Throw error if number of nodes involved in integration is too large.
        err='Error (howard_knutson_periodic.m): Curvature integration includes more than the total number of centerline nodes';
        filename=[data_directory,'trial_',trial,'_error_data.mat'];
        save(filename)
        error(err)
    end

    d_all=[sqrt(sum(diff([centerline.X,centerline.Y],1,1).^2,2));NaN]; % Array that stores the distance from each centerline node to the next.
    R1=zeros(size(Ro)); % Vector for dimensionless migration rate at each node, including upstream-integrated curvature.
    % Calculate the dimensionless migration rate for each centerline node (with node index "s")
    for s=1:S 
    % For each centerline node, set the other nodes to be used for the curvature integration. Use the periodic boundary condition to define the proper set of nodes.
        if s<=(upper_integ_limit_max+1)
            integration_nodes = [((S-1)-(upper_integ_limit_max-s)):(S-1),1:s]; % As part of periodic boundary condition, do not count node S and node 1 (just node 1), because they are effectively the same node for the curvature integration.
        else
            integration_nodes = s-upper_integ_limit_max:s;
        end

        if any(integration_nodes<1) % Error check in case any of the integration node indices are negative.
            err = 'Error (howard_knutson_periodic.m): Non-positive integration nodes assigned';
            filename=[data_directory,'trial_',trial,'_error_data.mat'];
            save(filename)
            error(err)
        end
        d_local =d_all(integration_nodes); % Vector of local internodal distances for the integration nodes.
        d_local(end)=0; % i.e., at node "s" the distance from node "s" is zero.
        d_local=cumsum(d_local(end:-1:1)); % Convert distances to cumulative distances from node "s".
        d_local=d_local(end:-1:1); % Reverse the sorting of the distance values for proper order.
        G = exp(-alpha*d_local); % Compute the weighting function "G" using "alpha" and the local distances
        integration_nodes=integration_nodes(G>=0.01); % Select the integration nodes for which the weighting function meets the 1% threshold.
        G=G(G>=0.01); % Select the weighting function values that meet the 1% threshold.
        Gsum=sum(G); % Sum of the weighting function values.
        R1(s) = om*Ro(s) + gam*(sum(Ro(integration_nodes).*G)/Gsum); % Calculate dimensionless migration rate (nominal + weighted upstream contribution)
    end

    % Calculate sinuosity "mu" for the full length of the channel.
    channel_length_tot=sum(sqrt(sum(diff([centerline.X,centerline.Y],1,1).^2,2))); 
    valley_length=sqrt((centerline.X(end)-centerline.X(1))^2+(centerline.Y(end)-centerline.Y(1))^2); % Cartesian distance from channel beginning to end of the channel centerline.
    mu = channel_length_tot/valley_length; %sinuosity
    R1prime=(mu^epsilon)*R1; % Adjust dimensionless lateral migration rates for sinuosity
    R1prime = 0.5*(R1prime([end-1,1:end-1])+R1prime(1:end)); % Spatially average the dimensionless migration rate using the adjacent node.

    rho = 1000; % density of water in kg/m^3. Used for stream power calculations.
    g = 9.81; % gravitational acceleration in m/s^2. Used for stream power calculations.
    
    if initialization_tf
        k_meander = max_step_init/max(abs(R1prime)); % Rescale k_meander to the the value that yields the desired maximum lateral erosion rate for the initialization phase.
        slope = [diff(centerline.Z)./sqrt(sum(diff([centerline.X,centerline.Y],1,1).^2,2));NaN]; % Slope at each centerline node, using a forward difference scheme.
        kv=abs(bed_elev_chg_rate)/(rho*g*D*mean(slope)); % Calculate scaling coeffcient for vertical incision rate, where bed_elev_chg_rate = -kv*rho*g*D*slope;      
    end

    R1prime=k_meander*R1prime; % Convert dimensionless lateral erosion rate to dimensioned lateral erosion rate.
    [x_increment,y_increment,move_az]=calc_increment(centerline.X,centerline.Y,R1prime,t_increment); % Calculate the x- and y-increments to shift the nodes.

    % Calculate the vertical (z) increments for each centerline node.
    switch vertical_incision_style
        case 'shear_stress' % Stream power vertical incision
            slope = [diff(centerline.Z)./sqrt(sum(diff([centerline.X,centerline.Y],1,1).^2,2));NaN]; % Slope at each centerline node, using a forward difference scheme.
            slope(end)=slope(end-1); % Define slope for the last centerline node.
            slope(slope>0)=0; % Temporarily set the adverse slopes to zero to prevent vertical incision there. 
            slope(slope<0)=abs(slope(slope<0)); % Take absolute value of the non-adverse slopes.
            z_increment = -kv*rho*g*D*slope*t_increment; % Calculate the vertical increments for each centerline node.
            z_increment(end) = bed_elev_chg_rate*t_increment; % Lower the last node of the centerline according to its imposed vertical incision rate.
        case {'flat_steady','sloping_steady'} % Flat or sloping longitudinal profile with a steady vertical incision rate.
            z_increment = bed_elev_chg_rate*t_increment;
        case 'flat_unsteady'  % Flat longitudinal profile with an unsteady vertical incision rate.
            if initialization_tf
                % Throw an error because 
                err = 'Error (howard_knutston_periodic.m): Time-varying vertical incision rate is not configured to operate during initialization phase';
                filename=[outputDir,'run_',trial,'_error_data.mat'];
                save(filename)
                error(err)
            else 
                z_increment = bed_elev_chg_rate(it)*t_increment;
            end
    end  
    
    if any(isnan(R1prime(:)))
        err = 'Error (howard_knutson_periodic.m): NaN detected in migration rate calculation';
        filename=[outputDir,'run_',trial,'_error_data.mat'];
        save(filename)
        error(err)
    end
end