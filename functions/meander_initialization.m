function [centerline,k_meander,kv]= meander_initialization(data_directory,trial,w,D,vertical_incision_style,bed_elev_chg_rate,init_plane_slope,init_centerline_file,domain,init_alluv_width,Cf,k,epsilon,g,gam,om,rho,init_spacing,init_centerline_type,init_plane_max_elev)
% meander_initialization.m: Runs initialization phase to determine
% dimensional erosion rate coefficients and channel centerline coordinates.
% Input arguments:
%   data_directory:  directory for saving model files
%   trial: name of model run
%   w: channel width
%   D: channel depth
%   vertical_incision_style: for simulations with vertical incision, specifies the submodel for this process
%   bed_elev_chg_rate: rate of elevation change for channel bed
%   init_plane_slope: slope of initial plane surrounding channel
%   init_centerline_file: optionally, specifies channel centerline from a file
%   domain
%   init_alluv_width: initial width of sediment-filled zone surrounding
%   channel
%   Cf: dimensionless friction coefficient
%   k: dimensionless coefficient in Howard and Knutson (1984)
%   epsilon: dimensionless coefficient in Howard and Knutson (1984)
%   meandering model
%   g: gravitational acceleration
%   gam: dimensionless coefficient in Howard and Knutson (1984)
%   meandering model
%   om: dimensionless coefficient in Howard and Knutson (1984)
%   meandering model
%   rho: density of water
%   init_spacing: initial spacing of nodes within channel centerline
%   a: dimensionless coefficient in Howard and Knutson (1984)
%   init_centerline_type: specifies geometric model for creating channel
%   init_plane_max_elev: maximum elevation of plane that defines initial
% Output arguments:
%   centerline: structure array with channel centerline coordinates
%   k_meander: rate constant for specifying lateral erosion rates
%   kv: rate constant for vertical incision erosion rates

    % Create channel centerline coordinates (X,Y,Z)
    centerline = create_centerline_geometry(init_centerline_type,init_centerline_file,init_plane_max_elev,w,D,init_plane_slope,init_spacing,domain);
    
    % Save un-evolved centerline for potential output
    centerline_notEvolved = centerline;
    
    % Define parameters for initialization fo channel centerline geometry
    % and rate constants.
    t_increment = 1; % Set the time step as 1 yr for the initialization phase.
    max_step_init=0.05*w; % Fix maximum step length for initialization phase at 5% of the channel width. 
	t_max=round(50*w/(max_step_init)); % Total time of initialization phase, expressed in channel widths worth of migration. (i.e., the time to migrate 50 channel widths).
    domain.xExtent = centerline.X([1 end]);
    
    nTimesteps = round(t_max/t_increment); % number of timesteps in initialization phase
	spinupTimeseries.t = nan(nTimesteps,1); % Array to store time values
    spinupTimeseries.t_record_values_min = round(10*w/(max_step_init)); % Time at which to start recording values of sinuosity and coefficients for lateral (k_meander) and vertical (kv) erosion rates, set as the estimated time for channel migration equivalent to 10 channel widths.
	spinupTimeseries.sinuosity=nan(nTimesteps,1); % Array to store sinuosity timeseries.
	spinupTimeseries.k_meander=nan(nTimesteps,1); % Array to store timeseries of lateral erosion rate coefficients that yield a maximum migration rate of 1 m/yr.
	spinupTimeseries.kv=nan(t_max,1); % Array to store timeseries of vertical erosion rate coefficients.
	spinupTimeseries.t_increment = t_increment;
    spinupTimeseries.t_max = t_max;
        
	cutoff_interp_stats.centerline_interp_log=false(t_max,1); % Array record iterations in which the centerline was interpolated.
	cutoff_interp_stats.cutoff_log = false(t_max,1); % Array record time steps in which a cutoff occurred.
	cutoff_interp_stats.n_cutoffs=zeros(t_max,1);  % Array record the number of cutoffs that occurred at each time step.
	cutoff_interp_stats.cutoff_length=cell(t_max,1); % Cell array to record the length of cutoffs that occurred during the timestep.
	cutoff_interp_stats.nodes_removed_ranges=cell(t_max,1); % Cell array to record the indices of the centerline nodes removed by cutoff in each timestep.
    
    k_meander = NaN; % Initialize the the lateral erosion rate constant
    kv=NaN; % Initialize the the vertical erosion rate constant
	switch vertical_incision_style
		case 'shear_stress' % If using stream power vertical incision model, set the vertical erosion rate constant for a given average slope.
			kv=(abs(bed_elev_chg_rate)*t_increment)/(rho*g*D*init_plane_slope);         
	end
	
	initialization_tf = true; % Flag to indicate initialization phase.
    % Evolve the channel. 
    t = 0;
	for it_initialization = 1:nTimesteps
        t = t+t_increment;
		% Compute (x,y,z) increments to move channel centerline nodes. Lateral migration increments (x,y) are scaled initially for a maximum lateral migration rate of ~ 1 m/yr). Also output the direction of node shifting and the sinuosity.
		[x_increment,y_increment,z_increment,~,mu,k_meander,~] = howard_knutson_periodic(initialization_tf,max_step_init,data_directory,trial,centerline,init_spacing,w,D,Cf,k,om,gam,epsilon,k_meander,t_increment,vertical_incision_style,bed_elev_chg_rate,it_initialization);
        if t > spinupTimeseries.t_record_values_min % if the time exceeds a threshold, then record sinuosity and rate coefficients for lateral and vertical erosion.
            spinupTimeseries.t(it_initialization) = t;
            spinupTimeseries.sinuosity(it_initialization) = mu;
            spinupTimeseries.k_meander(it_initialization)=k_meander;
            spinupTimeseries.kv(it_initialization)=kv;
        end
        
        % Adjust (x,y) increments to account for confinement to the initial alluvial belt.
		if init_alluv_width>0 
			y_temp = centerline.Y+y_increment; % Temporary copy of centerline y-coordinates, moved without the constraint of the initial alluvial belt.
            init_alluv_half_width = init_alluv_width/2; % Half width of the initial alluvial belt.
            ind_overshoot = abs(y_temp)>(init_alluv_half_width-w/2); % Indices of centerline coordinates that overshoot the initial alluvial belt.
            frac_overshoot = (abs(y_temp(ind_overshoot))-(init_alluv_half_width-w/2))./(sqrt(x_increment(ind_overshoot).^2 + y_increment(ind_overshoot).^2)); % Fraction of the total node movement distance in this timestep by which the initial alluvial belt was overshot.
            x_increment(ind_overshoot)=x_increment(ind_overshoot).*(1-frac_overshoot); % Channel centerline x-coordinate increment, corrected for the initial alluvial belt constraint.
			y_increment(ind_overshoot)=y_increment(ind_overshoot).*(1-frac_overshoot); % Channel centerline y-coordinate increment, corrected for the initial alluvial belt constraint.
        end
        
		% Adjust the centerline nodes using the calculated increments and check for cutoff and interpolation.
		[centerline,cutoff_interp_stats] = adjust_centerline_nodes(centerline,w,init_spacing,x_increment,y_increment,z_increment,domain,vertical_incision_style,it_initialization,trial,data_directory,cutoff_interp_stats);
		spinupTimeseries.centerline{it_initialization}=centerline; % Record the centerline coordinates for this timestep.
    end
	k_meander=mean(spinupTimeseries.k_meander(~isnan(spinupTimeseries.k_meander)))/max_step_init; % Set the lateral migration rate coefficient as the mean of its value during the phase it was recorded; normalize by the maximum step for the initialization phase to ensure that this coefficient yields a maximum lateral migration rate of 1 m/yr.
	kv=mean(spinupTimeseries.kv(~isnan(spinupTimeseries.kv))); % Set the vertical incision rate coeffcient as the mean of its value during the recording phase.
    
    % Select centerline to output based on 'init_centerline_type'
    switch init_centerline_type
        case {'straight','sinusoidal','custom'}
            centerline = centerline_notEvolved; % i.e., reset the centerline to the un-evolved centerline
        case 'evolved'
            % do nothing -- i.e., output the evolved centerline
    end
    
    % Subtract offsets from centerline coordinates such that the first
    % x-coordinate is x=0 and the mean y-coordinate is y=0.
    centerline.X = centerline.X - centerline.X(1);
    centerline.Y = centerline.Y - mean(centerline.Y);
    
    % Save variables from the initialization phase.
    startfile=[data_directory,'run_',trial,'_initialization.mat'];     
    save(startfile,'centerline','k_meander','kv','spinupTimeseries')
end