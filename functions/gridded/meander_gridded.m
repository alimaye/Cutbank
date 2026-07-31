function [modelDataFileFinal] = meander_gridded(inputs)
% meander_gridded.m: Main function for modeling channel evolution within a
% grid-based framework for tracking bank materials.
% Input arguments:
%   inputs: structure array that packages all variables for model
% Output arguments:
%   modelDataFileFinal: name of file with final output data from model.

    start_time=clock;
    
    % Unpack variables
    outputDir = inputs.outputDir;
    trial = inputs.trial;
    k_erode_bedrock = inputs.k_erode_bedrock;
    k_erode_sediment = inputs.k_erode_sediment;
    bed_elev_chg_rate = inputs.bed_elev_chg_rate;
    w = inputs.w;
    D = inputs.D;
    vertical_incision_style = inputs.vertical_incision_style;
    init_plane_slope = inputs.init_plane_slope;
    init_plane_max_elev = inputs.init_plane_max_elev;
    cell_width = inputs.cell_width;
    t_increment = inputs.t_increment;
    t_max = inputs.t_max;
    save_interval = inputs.save_interval;
    init_centerline_file = inputs.init_centerline_file;
    centerline_spacing_coeff = inputs.centerline_spacing_coeff;
    domain.xExtentChannelWidths= inputs.domain.xExtentChannelWidths;
    init_alluv_width_coeff = inputs.init_alluv_width_coeff;
    unconfined_alluvial_belt_width = inputs.unconfined_alluvial_belt_width;
    k = inputs.k;
    Cf = inputs.Cf;
    om = inputs.om;
    gam = inputs.gam;
    epsilon = inputs.epsilon;
    g = inputs.g;
    rho = inputs.rho;
    startfile = inputs.startfile;
    init_centerline_type = inputs.init_centerline_type;
    init_Ev_pulse = inputs.init_Ev_pulse;
    enforceChannelDisplacementLimit = inputs.enforceChannelDisplacementLimit;
    
    % Parameters specific to bank-material tracking.
    bedrock_erosion = inputs.bedrock_erosion;
    overbank_deposition = inputs.overbank_deposition;
    nu = overbank_deposition.parameters.nu;
    mu_d = overbank_deposition.parameters.mu_d;
    lambda = overbank_deposition.parameters.lambda;
    oxbow_erode_coeff = overbank_deposition.parameters.oxbow_erode_coeff;
    stratigraphy_3D = inputs.stratigraphy_3D;
    
    % Set maximum run time.
    t_max = ceil(t_max/t_increment)*t_increment; % Using ceil ensures that run enough timesteps to include the input maximum time, even if t_increment doesn't divide evenly into maximum time (Example: if t_increment=7 and t_max=100, won't stop at t=98).

    %% Define other constants the depend on the input paramters.
    init_spacing = centerline_spacing_coeff*w;  

    if strcmp(vertical_incision_style,'flat_unsteady')
        load(vertical_file,'bed_elev_chg_rate') % bed_elev_chg_rate replaces existing variable
    end

    % Set width and depth of initial alluvial belt.   
    init_alluv_width=init_alluv_width_coeff*unconfined_alluvial_belt_width;
    if init_alluv_width>0
        init_alluv_depth = D;
    else
        init_alluv_depth = 0;
    end
    
    % Initialize other variables that will be shared with nested functions.
    dem = struct;
    resize_grids_flag = false; % flag for resizing grids
    bank_height_ratio = [];

    %% Initialize channel planform geometry and erosion rate coefficeints.
    % Set channel planform geoemtry and run initialization phase to empirically 
    % determine the coeffients that yield the desired lateral erosion rate 
    % ("k_meander") and vertical erosion rate ("kv"), respectively.
    if ~isempty(startfile) && ~isempty(dir(startfile))
        fprintf('Run %s, using pre-existing initialization file\n',trial)
        % Initialize variables prior to loading them from a file so that
        % they don't "pop" into the workspace unexpectedly. 
        centerline=[];
        k_meander=[];
        kv=[];
        load(startfile,'centerline','k_meander','kv')    
    else
        fprintf('Run %s, started initialization\n',trial)
        [centerline,k_meander,kv]= meander_initialization(outputDir,trial,w,D,vertical_incision_style,bed_elev_chg_rate,init_plane_slope,init_centerline_file,domain,init_alluv_width,Cf,k,epsilon,g,gam,om,rho,init_spacing,init_centerline_type,init_plane_max_elev);
        fprintf('Run %s, completed initialization\n',trial)
    end

    %% Set model domain geometry.
    domain.xExtent = [centerline.X(1) centerline.X(end)]; % x-extent of domain
    domain.yExtent= mean(centerline.Y)+[-100000 100000]; % y-extent of domain. The y-extent is arbitrarily large and centered on the mean y-coordinate of the centerline.
    domain.corners.x = (domain.xExtent([1 1 2 2]))'; % "domain" is a data structure to hold the domain extent data.
    domain.corners.y = (domain.yExtent([1 2 2 1]))';
    domain.corners.hole=false; % This field indicates that the model domain polygon stored is not a hole.
    domain.xRange = centerline.X(end)-centerline.X(1); % The x-direction distance offset between the first and last elements of the centerline vector.
    
    % Initialize time for first iteration
    it = 1; % iteration number (for-loop over iterations below starts at it=2)
    t=0; % Initialize time as 0 (years)
    Data(1).t = t;
    nTimesteps = 1+ceil(t_max/t_increment); % 1+ because first timesteps is t=0
    
    % Initialize arrays to store information about cutoffs and interpolation.
    cutoff_interp_stats.centerline_interp_log=false(nTimesteps,1);
    cutoff_interp_stats.cutoff_log = false(nTimesteps,1);
    cutoff_interp_stats.n_cutoffs=zeros(nTimesteps,1); 
    cutoff_interp_stats.cutoff_length=cell(nTimesteps,1);
    cutoff_interp_stats.nodes_removed_ranges=cell(nTimesteps,1);

    % Update the channel centerline, checking for cutoffs and proper node
    % spacing.
    x_increment = zeros(size(centerline.X));
    y_increment = zeros(size(centerline.Y));
    z_increment = zeros(size(centerline.Z));
    
    [centerline,~] = adjust_centerline_nodes(centerline,w,init_spacing,x_increment,y_increment,z_increment,domain,vertical_incision_style,it,trial,outputDir,cutoff_interp_stats);

    % If simulation starts with a pulse of vertical incision, than enact it. 
    switch init_Ev_pulse
        case 'knick'
            centerline.Z(end)=centerline.Z(end)-pulse_coeff*D; % lower only end of centerline
        case 'pulse'
            centerline.Z=centerline.Z-pulse_coeff*D; % lower all parts of centerline
    end

    % Record data from this first iteration
    Data(1).centerline=centerline;
    if bedrock_erosion.modify_lateral_erosion_bedrock
        Data(1).f_bedrock = [];
    elseif overbank_deposition.modify_lateral_erosion_bank_height
        Data(1).bank_height_ratio = [];
    elseif overbank_deposition.modify_lateral_erosion_resistant_oxbows
         Data(1).f_oxbow = [];
    end
    Data(1).El_mean_median_max=[];
    Data(1).Ev_mean_median_max=[];
    Data(1).visited_area = [];

    initialization_tf = false; % Flag the end of the initialization phase.																						

    % Create periodically copied version of centerline
    centerline_periodic = replicate_centerline_periodic(centerline,numel(centerline.X)-1); % second argument is the number of nodes to add to both upstream and downstream

    % build elevation grid, and gridLines that define cell edges
    grid_addition_buffer=max(5*cell_width,2*k_erode_sediment*t_increment); % set minimum grid addition buffer, which can handle large migration rates and has a minimum number of pixels.
    gridLines = []; % Need to initialize gridLines before calling create_grids
    % Set geometry of initial alluvial belt
    if init_alluv_width_coeff > 0
        init_alluv_width=init_alluv_width_coeff*unconfined_alluvial_belt_width;
        init_alluv_depth = D;   
    end
    init_alluv_poly = create_init_alluv_poly(domain,init_alluv_width);
    init_alluv_poly.init_alluv_depth = init_alluv_depth;
    create_grids;    
    
    % Start of time loop - evolve channel, topography, and bedrock-sediment interface.
    last_percent_complete=0; % Variable for reporting simulation progress.
    next_save_time = t+save_interval;
    max_step_init = NaN; % This is an argument to howard_knutson_periodic.m that is only used during the initialization phase, so set to NaN.
    
    for it = 2:nTimesteps % Treat iteration 1 as the initial condition, so start with iteration 2
        t = t+t_increment; % increment time
        Data(it).t = t;
        % Compute (x,y,z) increments to move channel centerline nodes. Lateral migration increments (x,y) are scaled initially for a maximum lateral migration rate of ~ 1 m/yr). Also output the direction of node dshifting and the sinuosity.
        [x_increment,y_increment,z_increment,move_az,mu,~,R1prime] = howard_knutson_periodic(initialization_tf,max_step_init,outputDir,trial,centerline,init_spacing,w,D,Cf,k,om,gam,epsilon,k_meander,t_increment,vertical_incision_style,bed_elev_chg_rate,it);    
        % Run bank composition check
        bank_composition_check_gridded; % Calls nested function. Generates the variable "move_dist", which is a vector of the distance to move node accounting for bank-material properties.
        move_dist(end)=move_dist(1); % The first node and last node in the centerline vector move in tandem as part of the periodic boundary condition.
        f_bedrock = ((move_dist./abs(R1prime))-k_erode_sediment)/(k_erode_bedrock-k_erode_sediment); % f_bedrock recalculates the fraction of bedrock in the cutbank for each node, measured from the channel bed to the bankfull height.
        % Recalculate the (x,y) movement increments for the centerline nodes following the bank-material composition check.
        x_increment=move_dist.*cos(move_az);
        y_increment=move_dist.*sin(move_az); 
        increments = sqrt(x_increment.^2+y_increment.^2);

        
        if enforceChannelDisplacementLimit
        % Throw an error and output variables if the bank migration distance anywhere is greater than or equal to the channel width.
            if any(increments>=w)
                err='Error (meander_gridded.m): Bank migration larger than a channel width in one timestep. Review move_dist/w and decrease timestep';
                filename=[outputDir,'run_',trial,'_error_data.mat'];
                save(filename)
                error(err)
            end
        end
        
        centerline_before_adjustment = centerline;
        % Adjust the centerline nodes using the calculated increments and check for cutoff and interpolation.																				
        [centerline,cutoff_interp_stats] = adjust_centerline_nodes(centerline,w,init_spacing,x_increment,y_increment,z_increment,domain,vertical_incision_style,it,trial,outputDir,cutoff_interp_stats);
        
        % Update grids
        centerline_periodic = replicate_centerline_periodic(centerline,numel(centerline.X)-1); % second argument is number of nodes to add to bonth upstream and downstream
        [~,~,channel_poly]=channel_margins(centerline,w);        
        mode = 'update_grids';
        update_grids(mode,channel_poly); % updates the structure "dem"
        
        % Save values for longitudinal profile, fraction of bedrock in the cutbank, lateral and vertical erosion rates, and the lateral migration rate unscaled for bank-material properties to the "Data" data structure.
        Data(it).centerline = centerline;
        Data(it).El_mean_median_max=[mean(increments),median(increments),max(increments)]/t_increment;
        Data(it).Ev_mean_median_max=[mean(z_increment),median(z_increment),max(z_increment)]/t_increment;
        Data(it).R1prime=R1prime;

        if bedrock_erosion.modify_lateral_erosion_bedrock
            Data(it).f_bedrock = f_bedrock; 
        elseif overbank_deposition.modify_lateral_erosion_bank_height
            Data(it).bank_height_ratio = bank_height_ratio;
        elseif overbank_deposition.modify_lateral_erosion_resistant_oxbows
            Data(it).f_oxbow = f_oxbow;
        end

        resize_grids_check; % Creates resize_grids_flag
        if resize_grids_flag
           resize_grids; % Updates the structures "dem" and "gridLines"
        end
        
        % In principle, movie export could be added here, but would
        % likely entail embedding a nested function largely duplicative of  
        % that in export_grids_movie.m. Therefore, movie export is left as a
        % post-processing step. This choice sacrifices some computational
        % efficiency in order to streamline code maintainance (i.e., avoids code
        % duplication) and enable a consistent workflow for running the
        % model and exporting movies.
    
        % Export data at intervals set by "next_save_time"
        if t >= next_save_time
            model_performance.seconds_per_iteration = toc; % Time to complete one iteration, in seconds.
            next_save_time = t-mod(t,save_interval)+save_interval;
            filename=[outputDir,'gridded_data_trial_',trial,'_time_',num2str(t),'.mat'];
            save(filename)
            fprintf('Saving gridded data for trial %s, t=%d\n',trial,t)
        end

        % If going to save next iteration, start iteration timer.
        if and(t<next_save_time,(t+t_increment) >= next_save_time)
            tic
        end 

        % Print the percentage of the model run that has been completed.
        percent_complete = floor((t/t_max)*100);
        percent_increment=5;
        if percent_complete > (last_percent_complete+(percent_increment-1))
            fprintf('Run %s, %d percent complete\n',trial,percent_complete)
            last_percent_complete = percent_complete;    
        end

        % The first and last nodes of the centerline should have the same coordinate. If they don't, throw an error.																					
        if abs(centerline.X(end)-centerline.X(1)-domain.xRange)>0.1
            err='Error (meander_gridded.m): centerline X-coordinate range exceeded';
            filename=[outputDir,'error_',trial,'_error_data.mat'];
            save(filename)
            error(err)
        end
        
    end% end for loop
    
    % Save all model data at end of run
    modelDataFileFinal=[outputDir,'run_',trial,'_modelDataFinal.mat'];
    save(modelDataFileFinal)
    fprintf('Finished run %s\n',trial)
    
    % More on nested functions:
    % https://www.mathworks.com/help/matlab/matlab_prog/nested-functions.html
    function create_grids %%% Nested function
        % create_grids.m: Creates grid for storing elevation data and calls the
        % function update_grids.m to create other grids for tracking elevation of
        % scour surface, surface age, planform extent of cutoffs, and age
        % statistics and location of eroded sediment.
        
        [~,~,bdyall] = channel_margins(centerline,w);
        dem.x_min=domain.xExtent(1);
        dem.x_max=domain.xExtent(2);
        ymin=min(bdyall.y);
        ymax=max(bdyall.y);
        dem.y_min=ymin-grid_addition_buffer; 
        dem.y_max=ymax+grid_addition_buffer;
        ncells_x = round(range(domain.xExtent)/cell_width);
        cell_width = range(domain.xExtent)/ncells_x; % adjust cell width so round number of cells fits into x extent. (extent of grid in y direction is fluid so don't have to be as precise in setting initial extent)
        [dem.x,dem.y]=meshgrid(dem.x_min:cell_width:dem.x_max,dem.y_max-cell_width/2:-cell_width:dem.y_min+cell_width/2);
        dem.z = init_plane_max_elev-init_plane_slope*dem.x;

        % The elevation grid serves as a template for making the other grids
        % Create arrays for storing cell-edge coordinates
        create_gridlines; % creates the variable "gridLines"

        % carve in channel into DEM; initialize alluvial belt, ind_in_channel_last_timestep,
        % logical array to track planform extent of cutoffs,  double array to track surface scour time. 
        
        channel_poly=create_polygon(centerline,w,domain);
        mode_in = 'initialize';
        polyg = channel_poly;
        update_grids(mode_in,polyg);
        polyg = init_alluv_poly;
        mode_in = 'initialize_alluvial_belt';
        update_grids(mode_in,polyg);
    end
    %%% End of nested function "create_grids"
    
    
    function create_gridlines %%% Nested function
    % create_gridlines.m: takes coordinate arrays (dem.x,dem.y) and generates
    % the lines that form the cell edge boundaries (grid_all)

    % Created August 29, 2017 by Ajay Limaye, California Institute of Technology (ajay@caltech.edu)
    % Last edited August 29, 2017 by Ajay Limaye

    % to plot: imagesc(dem.x(:),dem.y(:),bdrk_topo); hold on, plot(grid_all(:,1),grid_all(:,2),'k-'),axis equal
        gridLines.x = [dem.x-0.5*cell_width,dem.x(:,end)+0.5*cell_width];
        gridLines.x = [gridLines.x;gridLines.x(end,:)];
        gridLines.y = [dem.y-0.5*cell_width;dem.y(end,:)+0.5*cell_width];
        gridLines.y = [gridLines.y,gridLines.y(:,end)];
        gridLines.x_vertical = [gridLines.x([1,end],:);nan(1,size(gridLines.x,2))];
        gridLines.x_vertical=gridLines.x_vertical(:);       
        gridLines.y_vertical = [gridLines.y([1,end],:);nan(1,size(gridLines.y,2))]; 
        gridLines.y_vertical=gridLines.y_vertical(:);
        gridLines.x_horizontal = [gridLines.x(:,[1,end]),nan(size(gridLines.x,1),1)];
        gridLines.x_horizontal=gridLines.x_horizontal'; gridLines.x_horizontal=gridLines.x_horizontal(:);
        gridLines.y_horizontal = [gridLines.y(:,[1,end]),nan(size(gridLines.y,1),1)];
        gridLines.y_horizontal=gridLines.y_horizontal'; gridLines.y_horizontal=gridLines.y_horizontal(:);
        gridLines.all = [gridLines.x_vertical,gridLines.y_vertical;gridLines.x_horizontal,gridLines.y_horizontal];

        % Output point pairs as rows
        gridLines.x_vertical = (gridLines.x([1,end],:))';
        gridLines.y_vertical = (gridLines.y([1,end],:))';
        gridLines.x_horizontal = (gridLines.x(:,[1,end]));
        gridLines.y_horizontal = (gridLines.y(:,[1,end]));
    end
    %%% End of nested function "create_gridlines"
    
    function update_grids(mode,poly) %%% Nested function
    % update_grids.m: Creates and/or updates grids that track elevation, elevation of
    % scour surface, surface age, planform extent of cutoffs, and age statistics and location of eroded sediment.
        gnc_IN=false(size(gridLines.x));
        ind_inside=false(size(dem.z));
        
        if ~isfield(poly,'x') 
            poly.x = poly.X;
            poly.y = poly.Y;
        end
        
        for m=1:numel(poly)
            IN = inpoly([gridLines.x(:),gridLines.y(:)],[poly(m).x,poly(m).y]); % gnc=grid_nodes_contained; true for grid nodes in channel
            gnc_IN(IN)=true;
            % identify cells completely contained by the present channel.
            gnc_ind = find(gnc_IN);
            if ~ isempty(gnc_ind)
                row_height=size(gridLines.x,1);
                other_corners_ind = [gnc_ind+row_height,gnc_ind+row_height+1,gnc_ind+1]; %check if nodes E, SE, and S are also contained (if so the whole cell is contained)
                other_corners_ind(other_corners_ind>numel(gnc_IN))=gnc_ind(1); % this is a way of dealing with indices that spill over. will just count them as in-channel
                other_corners_IN = gnc_IN(other_corners_ind); % 1 for indices that are in, 0 for those that are not
                gnc_ind(~all(other_corners_IN,2))=[]; % exclude  grid nodes for cells not that are not all in channel
                gnc_x=gridLines.x(gnc_ind)+0.5*cell_width;
                gnc_y=gridLines.y(gnc_ind)-0.5*cell_width;
                % interpolate for cell indices
                fully_contained_cells_ind=interp2(dem.x,dem.y,reshape(1:numel(dem.z),size(dem.z,1),size(dem.z,2)),gnc_x,gnc_y,'*nearest'); % gets cell index each x,y coordinate
                fully_contained_cells_ind(isnan(fully_contained_cells_ind))=[]; % for boundary cells can get NaN values form interpolation
                ind_inside(fully_contained_cells_ind)=true;
            end
        end        

        switch mode
            case 'initialize'
                % channel
                dem.z(ind_inside) = dem.z(ind_inside) - D;

                % bedrock topography (prior to defining alluvial belt)
                dem.z_bedrock = dem.z;

                % Initialize logical array to track grid indices in channel footprint at
                % the the last timestep. Initialize as true for the indices that start
                % within the channel footprint.
                dem.ind_in_channel_last_timestep = false(size(dem.z));
                dem.ind_in_channel_last_timestep(ind_inside) = true;

                % logical array to track planform extent of cutoffs 
                dem.cutoff = false(size(dem.z));

                % double array to track surface scour time.
                dem.t = zeros(size(dem.z));
                dem.t(ind_inside)=1;

                % Cell array to store the time since emplacement for eroded
                % sediment
                dem.eroded_sediment_time_since_emplacement = {};

                if stratigraphy_3D.enable
                    % default the (x,y) spacing and dimensions for the
                    % stratigraphy tracking grid to their values for the
                    % elevation grid
                    dem.x_strat_vec = dem.x(1,:)';
                    dem.y_strat_vec = dem.y(:,1);
                    dem.z_strat_vec = linspace(stratigraphy_3D.zMin,stratigraphy_3D.zMax,range([stratigraphy_3D.zMin,stratigraphy_3D.zMax])/stratigraphy_3D.delta_z)';                                
                    % Use low-memory data type (uint8) to track stratigraphic units. 0 = air, 1 = sand, 2 = mud.
                    dem.strat = zeros(numel(dem.y_strat_vec),numel(dem.x_strat_vec),numel(dem.z_strat_vec),'uint8');                
                end

            case 'initialize_alluvial_belt'
                % bedrock surface
                dem.z_bedrock(ind_inside) = (init_plane_max_elev-init_plane_slope*dem.x(ind_inside)) - poly.init_alluv_depth;
            case 'update_grids'
                switch vertical_incision_style
                    case {'flat_steady','flat_unsteady'}
                        channel_bed_elev = centerline.Z(1);
                    case {'sloping_steady','shear_stress'}
                        [~,~,frac_dist] = distance2curve([centerline_periodic.X,centerline_periodic.Y],[dem.x(ind_inside),dem.y(ind_inside)],'linear');
                        frac_ind = interp1q((1:numel(centerline_periodic.Z))'/numel(centerline_periodic.Z),(1:numel(centerline_periodic.Z))',frac_dist);
                        flr_frac_ind=floor(frac_ind);
                        ceil_frac_ind=ceil(frac_ind);
                        mod_frac_ind=mod(frac_ind,1);
                        % Get the longitudinal profile elevation for the proper location
                        channel_bed_elev = centerline_periodic.Z(flr_frac_ind)+ mod_frac_ind*(centerline_periodic.Z(ceil_frac_ind)-centerline_periodic.Z(flr_frac_ind));
                end
                
                dem.z(ind_inside) = channel_bed_elev;
                dem.z_bedrock(ind_inside) = channel_bed_elev; 

                if overbank_deposition.enable
                    % Enact overbank sediment deposition, sensu Howard (1996)
                    nu = overbank_deposition.parameters.nu;
                    mu_d = overbank_deposition.parameters.mu_d;
                    lambda = overbank_deposition.parameters.lambda;    
                    [~,dist_to_lp,~] = distance2curve([centerline_periodic.X(:),centerline_periodic.Y(:)],[dem.x,dem.y],'linear');
                       % On the right-hand side of the equation that follows the terms are:
                    % Term 1: the initial elevation without the overbank sediment contribution.																																							
                    % Term 2: the elapsed time that this grid cell has been in the floodplain times the constant (space-independent) deposition rate.
                    % Term 3: the time increment times the space-dependent deposition rate.
                    dem.z = dem.z + t_increment*(nu + mu_d*exp(-dist_to_lp/lambda)); 
                end

                dem.t(ind_inside) = t;
                if t>1
                    ind_abandoned = and(dem.ind_in_channel_last_timestep,~ind_inside);
                    dem.z(ind_abandoned) = dem.z(ind_abandoned) + D;
                end
                dem.ind_in_channel_last_timestep = ind_inside;

                %%% add a flag here to skip this operation if the grid was
                %%% resized in the previous timestep
                ind_newly_eroded = and(ind_inside,~dem.ind_in_channel_last_timestep); % This gives only indices that weren't contained by the channel at the last timestep. 'sparse' removes values with dem.t==0

                dem.eroded_sediment_time_since_emplacement{it} =  [find(ind_newly_eroded),t-dem.t(ind_newly_eroded)]; % Nx2 array with columns of cell index (column 1) and time in years since sediment emplacement (column 2)

                % identify grid cells contained by new meander cutoffs. To do
                % this, need to use the channel centerline from the previous
                % timestep to determine the planform extents of cutoffs, then
                % find the grid cells contained within those extents. Finally,
                % a threshold distance from the current channel position is
                % applied for the purposes of assignig grid cells to cutoffs,           
                % under the assumption that cells closer to the channel have
                % not had sufficient time to fill with resistant sediments. 

                if cutoff_interp_stats.cutoff_log(it) % then a loop was just removed
                    % identify nodes removed
                    nodes_removed_ranges=cutoff_interp_stats.nodes_removed_ranges{it};
                    % reconstruct periodic centerline from previous timestep
                    % (that's what was cut off)
                    centerline_last_timestep = Data(it-1).centerline;
                    orig_nodes_start_ind = numel(centerline_last_timestep.X);
                    orig_nodes_end_ind = 2*numel(centerline_last_timestep.X)-1;
                                                                                              
                    [centerline_last_timestep_periodic] = replicate_centerline_periodic(centerline_last_timestep,numel(centerline_last_timestep.X)-1); % the second argument is the number of nodes to add to both upstream and downstream 
                    rel_dist_all_nodes = [0;cumsum(sqrt(sum(diff([centerline_last_timestep_periodic.X,centerline_last_timestep_periodic.Y],1,1).^2,2)))]; 
                    % subtract the cumulative distance to orig_nodes_start_ind
                    rel_dist_all_nodes =  rel_dist_all_nodes -  rel_dist_all_nodes(orig_nodes_start_ind);
                    rel_dist_all_nodes = rel_dist_all_nodes/rel_dist_all_nodes(orig_nodes_end_ind); % normalize so that original nodes range is [0,1]

                    % identify the nodes within the cutoff loop range; generate polygon from each set of nodes
                    [~,~,bdyall] = channel_margins(centerline_last_timestep_periodic,w);
                    ind_check = find(and(and(dem.y(:)>=min(bdyall.y),dem.y(:)<=max(bdyall.y)),and(dem.x(:)>=min(bdyall.x),dem.x(:)<=max(bdyall.x))));
                    if any(ind_check)
                        gnc_IN=false(size(dem.x));  %%%%% check this against the other gnc_IN and which one currect (I think it's the other one)
                        for q=1:size(nodes_removed_ranges,1)
                            nodes_within_loop_range = find(and(rel_dist_all_nodes>=nodes_removed_ranges(q,1),rel_dist_all_nodes<=nodes_removed_ranges(q,2)));
                            % this might only be a few nodes, so interpolate for x
                            % and y at fine spacing so have enough points for
                            % channel_margins.m to accurately draw the boundary
                            % of the cutoff
                            if numel(nodes_within_loop_range)>2
                                cutoff_centerline.X=centerline_last_timestep_periodic.X(nodes_within_loop_range); 
                                cutoff_centerline.Y=centerline_last_timestep_periodic.Y(nodes_within_loop_range);
                                cutoff_centerline.Z=centerline_last_timestep_periodic.Z(nodes_within_loop_range);
                                d=[0;cumsum(sqrt(sum(diff([cutoff_centerline.X,cutoff_centerline.Y],1,1).^2,2)))];
                                cutoff_centerline_interp.X=interp1(d,cutoff_centerline.X,[(0:1:d(end))';d(end)]);
                                cutoff_centerline_interp.Y=interp1(d,cutoff_centerline.Y,[(0:1:d(end))';d(end)]);
                                cutoff_centerline_interp.Z=interp1(d,cutoff_centerline.Z,[(0:1:d(end))';d(end)]);
                                if numel(cutoff_centerline_interp.X)>2
                                    % identify cells completely contained by the cutoff loop
                                    [~,~,bdyall] = channel_margins(cutoff_centerline,w);
                                    IN = inpoly([dem.x(ind_check),dem.y(ind_check)],[bdyall.x,bdyall.y]);
                                    gnc_IN(ind_check(IN))=true; % gnc==grid_nodes_contained; true for grid nodes in channel
                                    gnc_ind = find(gnc_IN);

                                    % Only flag cells as belonging to cutoffs if > 3 widths from the
                                    % current channel banks. Assumes that these cells have not had time to  fill with resistant sediments.

                                    if ~ isempty(gnc_ind)
                                        row_height=size(dem.x,1);
                                        other_corners_ind = [gnc_ind+row_height,gnc_ind+row_height+1,gnc_ind+1]; %check if nodes E, SE, and S are also contained (if so the whole cell is contained)
                                        other_corners_ind(other_corners_ind>numel(gnc_IN))=gnc_ind(1); % this is a way of dealing with indices that spill over. will just count them as in-channel
                                        other_corners_IN = gnc_IN(other_corners_ind); % 1 for indices that are in, 0 for those that are not
                                        gnc_ind(~all(other_corners_IN,2))=[]; % don't remove grid nodes for cells not that are not all in channel
                                        gnc_x=dem.x(gnc_ind)+0.5*cell_width;
                                        gnc_y=dem.y(gnc_ind)-0.5*cell_width;
                                        % interpolate for cell indices
                                        cells_ind=interp2(dem.x,dem.y,reshape(1:numel(dem.z),size(dem.z,1),size(dem.z,2)),gnc_x,gnc_y,'*nearest'); % gets cell index each x,y coordinate                                    % only set these nodes to true if node center is
                                        % check that all these cell centers are
                                        % at least 3.5w+0.5*cell_width from the
                                        % centerline (0.5w) to account for centerline-bank distance, 
                                        % 0.5*cell_width to make sure all cell corners are also outside
                                        cells_ind=cells_ind(~isnan(cells_ind)); % might have some NaN at grid edge
                                        if any(cells_ind)
                                            dist=zeros(numel(cells_ind),4);
                                            [~,dist(:,1),~]=distance2curve([centerline_periodic.X,centerline_periodic.Y],[dem.x(cells_ind)-0.5*cell_width,dem.y(cells_ind)-0.5*cell_width],'linear');
                                            [~,dist(:,2),~]=distance2curve([centerline_periodic.X,centerline_periodic.Y],[dem.x(cells_ind)-0.5*cell_width,dem.y(cells_ind)+0.5*cell_width],'linear');
                                            [~,dist(:,3),~]=distance2curve([centerline_periodic.X,centerline_periodic.Y],[dem.x(cells_ind)+0.5*cell_width,dem.y(cells_ind)-0.5*cell_width],'linear');
                                            [~,dist(:,4),~]=distance2curve([centerline_periodic.X,centerline_periodic.Y],[dem.x(cells_ind)+0.5*cell_width,dem.y(cells_ind)+0.5*cell_width],'linear');
                                            cells_ind=cells_ind(min(dist,[],2)>(3.5*w)); % makes sure that even the closest cell corner in 3.5*w away from centerline, or 3*w away from bank.
                                            dem.cutoff(cells_ind)=true;
                                        end
                                    end
                                end
                            end
                        end
                    end  
                end   

                if stratigraphy_3D.enable
                    % update stratigraphy grid
                    [leftbdy,rightbdy,~] = channel_margins(centerline_periodic,w);
                    leftbdy.x = leftbdy.X;
                    leftbdy.y = leftbdy.Y;
                    rightbdy.x = rightbdy.X;
                    rightbdy.y = rightbdy.Y;
                    
                    leftbdy.zlow = centerline_periodic.Z;
                    leftbdy.zhigh = D+centerline_periodic.Z;
                    rightbdy.zlow = centerline_periodic.Z;
                    rightbdy.zhigh = D+centerline_periodic.Z;
                    fv.vertices = [leftbdy.x,leftbdy.y,leftbdy.zhigh;...
                    rightbdy.x,rightbdy.y,rightbdy.zhigh;...
                    leftbdy.x,leftbdy.y,leftbdy.zlow;...
                    rightbdy.x,rightbdy.y,rightbdy.zlow];

                    vertexNumbersTopLeft = 1:numel(leftbdy.x);
                    vertexNumbersTopRight = vertexNumbersTopLeft + numel(leftbdy.x);
                    vertexNumbersBottomLeft = vertexNumbersTopRight + numel(leftbdy.x);
                    vertexNumbersBottomRight = vertexNumbersBottomLeft + numel(leftbdy.x);

                                    %%%% Build trigulated (faces/vertices) surface
                    % Convention for face normals in triangulation: follows right-hand rule, so
                    % counterclockwise ordering points outwards
                    % https://www.mathworks.com/matlabcentral/answers/321387-what-is-matlab-convention-for-the-direction-of-normal-vector-of-a-triangulated-mesh

                    % build triangles for top face. 
                    fv.faces = [];
                    for i=1:(numel(vertexNumbersTopLeft)-1)
                        fv.faces = [fv.faces; 
                                            [vertexNumbersTopLeft(i),vertexNumbersTopRight(i),vertexNumbersTopLeft(i+1)]];                 
                    end

                    for i=1:(numel(vertexNumbersTopRight)-1)
                        fv.faces = [fv.faces; 
                                            [vertexNumbersTopRight(i),vertexNumbersTopRight(i+1),vertexNumbersTopLeft(i+1)]];                 
                    end

                    % build triangles for bottom face
                    for i=1:(numel(vertexNumbersBottomLeft)-1)
                        fv.faces = [fv.faces; 
                                            [vertexNumbersBottomLeft(i),vertexNumbersBottomLeft(i+1),vertexNumbersBottomRight(i)]];                 
                    end

                    for i=1:(numel(vertexNumbersBottomRight)-1)
                        fv.faces = [fv.faces; 
                                            [vertexNumbersBottomRight(i),vertexNumbersBottomLeft(i+1),vertexNumbersBottomRight(i+1)]];                 
                    end

                    % build triangles for downstream-left face
                    for i=1:(numel(vertexNumbersTopLeft)-1)
                        fv.faces = [fv.faces;
                                            [vertexNumbersTopLeft(i),vertexNumbersTopLeft(i+1),vertexNumbersBottomLeft(i)]];
                    end

                    for i=1:(numel(vertexNumbersBottomLeft)-1)
                        fv.faces = [fv.faces;
                                            [vertexNumbersBottomLeft(i),vertexNumbersTopLeft(i+1),vertexNumbersBottomLeft(i+1)]];
                    end

                    % build triangles for downstream-right face
                    for i=1:(numel(vertexNumbersTopRight)-1)
                        fv.faces = [fv.faces;
                                            [vertexNumbersTopRight(i),vertexNumbersBottomRight(i),vertexNumbersTopRight(i+1)]];
                    end

                    for i=1:(numel(vertexNumbersBottomRight)-1)
                        fv.faces = [fv.faces;
                                            [vertexNumbersBottomRight(i),vertexNumbersBottomRight(i+1),vertexNumbersTopRight(i+1)]];
                    end

                    % build triangles for front face
                    fv.faces = [fv.faces;...
                                        [vertexNumbersTopLeft(1),vertexNumbersBottomLeft(1),vertexNumbersTopRight(1)];...
                                        [vertexNumbersTopRight(1),vertexNumbersBottomLeft(1),vertexNumbersBottomRight(1)]];

                    % build triangles for back face
                    fv.faces = [fv.faces;...
                                        [vertexNumbersTopLeft(end),vertexNumbersTopRight(end),vertexNumbersBottomLeft(end)];...
                                        [vertexNumbersTopRight(end),vertexNumbersBottomRight(end),vertexNumbersBottomLeft(end)]];

                    % % test by plotting as a patch
                    % p = patch('Faces',fv.faces,'Vertices',fv.vertices,'facealpha',0.2,'facecolor','b');

                    %   IN = INPOLYHEDRON(..., X, Y, Z) voxelises a mask of 3D gridded query points
                    %   rather than an N-by-3 array of points. X, Y, and Z coordinates of the grid
                    %   supplied in XVEC, YVEC, and ZVEC respectively. IN will return as a 3D logical
                    %   volume with SIZE(IN) = [LENGTH(YVEC) LENGTH(XVEC) LENGTH(ZVEC)], equivalent to
                    %   syntax used by MESHGRID. INPOLYHEDRON handles this input faster and with a lower 
                    %   memory footprint than using MESHGRID to make full X, Y, Z query points matrices.

                    in = inpolyhedron(fv,dem.x_strat_vec(:),dem.y_strat_vec(:),dem.z_strat_vec(:));
                    dem.strat(in) = 1; % i.e., channel sand
                    % set voxels at or below channel elevation to 2 (i.e.,
                    % floodplain mud). Assume any slope is from left to right
                    % across the domain. Then for each stratigraphic level (k),
                    % for each column (j), if there are any values > 0 then any
                    % 0 values should be set to 2.
                    for k1=1:size(dem.strat,3)
                        for j=1:size(dem.strat,2)
                            if any(dem.strat(:,j,k1))
                                ind0 = find(dem.strat(:,j,k1)==0); % ==0 should be insensitive to rounding erros because data type is uint8 for dem.strat
                                dem.strat(ind0,j,k1)=2;
                            end
                        end
                    end
                end
        end 
    end
    %%% End of nested function update_grids
    
    function resize_grids_check %%% Nested function
    % resize_grids_check.m: Checks the distance from the channel to the edge of
    % the grid. If this distance falls below a threshold, the flag
    % 'resize_grids' is set to true.
    
        % check if grid needs to be enlarged prior to determining final
        % lateral erosion distance
        centerline_max_move.X = centerline_before_adjustment.X + 1.02*k_erode_sediment*(sqrt(x_increment.^2+y_increment.^2)).*cos(move_az); % channel coordinates if each node moved as much as it could (plus a little extra)
        centerline_max_move.Y = centerline_before_adjustment.Y + 1.02*k_erode_sediment*(sqrt(x_increment.^2+y_increment.^2)).*sin(move_az);
        centerline_max_move.Z = nan(size(centerline.Z)); % "Z" field does not affect grid resizing, but need to pass this field to channel margins, so use this placeholder.
        [~,~,bdyall_max_move] = channel_margins(centerline_max_move,w);
        y_min=min(bdyall_max_move.y);
        y_max=max(bdyall_max_move.y);
        if or(dem.y_min > (y_min-2*cell_width),dem.y_max < (y_max+2*cell_width))
          resize_grids_flag = true;
        else
          resize_grids_flag = false;
        end
    end
    %%% End nested function resize_grids_check
    
    %%% Nested function
    function resize_grids
    % resize_grids.m: Enlarges grids when
    % channel impinges on edge of grid, and re-assigns indices of pixels
    % within the channel. Note that xmin/xmax/ymin/ymax pertain to the
    % maximum move distance of the channel boundaries, and not the actual
    % channel centerline.
    
        grid_addition_buffer_cells = round(grid_addition_buffer/cell_width);

        [~,~,bdyall] = channel_margins(centerline,w);
        ymin = min(bdyall.y);
        ymax = max(bdyall.y);
        
        % re-size topography and track min/max cell coordinates
        if  dem.y_min > (ymin-2*cell_width) % channel approaching bottom margin; add to bottom
            dem.y_min = dem.y_min-grid_addition_buffer_cells*cell_width;
            [dem.x,dem.y]=meshgrid(dem.x_min:cell_width:dem.x_max,dem.y_max:-cell_width:dem.y_min);
            cells_add = size(dem.x,1)-size(dem.z_bedrock,1);

            dem.cutoff = [dem.cutoff;false(cells_add,size(dem.cutoff,2))];
            dem.t = [dem.t;zeros(cells_add,size(dem.t,2))];
            dem.ind_in_channel_last_timestep = [dem.ind_in_channel_last_timestep; false(cells_add,size(dem.ind_in_channel_last_timestep,2))];

            if isinf(init_alluv_width)
                dem.z_bedrock = [dem.z_bedrock;init_plane_max_elev-init_plane_slope*(dem.x(1:cells_add,:)-domain.xExtent(1))-init_alluv_depth];
            else
                dem.z_bedrock = [dem.z_bedrock;init_plane_max_elev-init_plane_slope*(dem.x(1:cells_add,:)-domain.xExtent(1))];
            end
    
            dem.z = [dem.z; init_plane_max_elev-init_plane_slope*(dem.x(1:cells_add,:)-domain.xExtent(1))];
            
            if stratigraphy_3D.enable
                dem.strat = cat(1,dem.strat,zeros(cells_add,size(dem.strat,2),size(dem.strat,3),'uint8'));
                dem.y_strat_vec = [dem.y_strat_vec; (dem.y_strat_vec(end)-(cell_width*(1:cells_add)'))];
                
                if ~isequal([numel(dem.y_strat_vec),numel(dem.x_strat_vec),numel(dem.z_strat_vec)],size(dem.strat))
                    err='Error (meander_gridded.m/resize_grids): Dimensions of stratigraphy array inconsistent with defined vectors';
                    filename=[outputDir,'error_',trial,'_error_data.mat'];
                    save(filename)
                    error(err)
                end
                % set voxels at or below channel elevation to 2 (i.e.,
                % floodplain mud). Assume any slope is from left to right
                % across the domain. Then for each stratigraphic level (k),
                % for each column (j), if there are any values > 0 then any
                % 0 values should be set to 2.
                for k2=1:size(dem.strat,3)
                    for j=1:size(dem.strat,2)
                        if any(dem.strat(:,j,k2))
                            ind0 = find(dem.strat(:,j,k2)==0); % ==0 should be insensitive to rounding erros because data type is uint8 for dem.strat
                            dem.strat(ind0,j,k2)=2;
                        end
                    end
                end
            end
        end
        
        if  dem.y_max < (ymax+2*cell_width) % channel approaching top margin; add to top
            dem.y_max = dem.y_max+grid_addition_buffer_cells*cell_width;
            [dem.x,dem.y]=meshgrid(dem.x_min:cell_width:dem.x_max,dem.y_max:-cell_width:dem.y_min);
            cells_add = size(dem.x,1)-size(dem.z_bedrock,1);

            dem.cutoff = [false(cells_add,size(dem.cutoff,2));dem.cutoff];
            dem.t = [zeros(cells_add,size(dem.t,2));dem.t];
            dem.ind_in_channel_last_timestep = [false(cells_add,size(dem.ind_in_channel_last_timestep,2)); dem.ind_in_channel_last_timestep];

            if isinf(init_alluv_width)
                dem.z_bedrock = [init_plane_max_elev-init_plane_slope*(dem.x(1:cells_add,:)-domain.xExtent(1))-init_alluv_depth;dem.z_bedrock];
            else
                dem.z_bedrock = [init_plane_max_elev-init_plane_slope*(dem.x(1:cells_add,:)-domain.xExtent(1));dem.z_bedrock];
            end
            
            dem.z = [init_plane_max_elev-init_plane_slope*(dem.x(1:cells_add,:)-domain.xExtent(1));dem.z];
            
            if stratigraphy_3D.enable
                dem.strat = cat(1,zeros(cells_add,size(dem.strat,2),size(dem.strat,3),'uint8'),dem.strat);
                dem.y_strat_vec = [(dem.y_strat_vec(1)+(cell_width*(cells_add:-1:1)'));dem.y_strat_vec];
                if ~isequal([numel(dem.y_strat_vec),numel(dem.x_strat_vec),numel(dem.z_strat_vec)],size(dem.strat))
                    err='Error (meander_gridded.m/resize_grids): Dimensions of stratigraphy array inconsistent with defined vectors';
                    filename=[outputDir,'error_',trial,'_error_data.mat'];
                    save(filename)
                    error(err)
                end
                % set voxels at or below channel elevation to 2 (i.e.,
                % floodplain mud). Assume any slope is from left to right
                % across the domain. Then for each stratigraphic level (k),
                % for each column (j), if there are any values > 0 then any
                % 0 values should be set to 2.
                for k3=1:size(dem.strat,3)
                    for j=1:size(dem.strat,2)
                        if any(dem.strat(:,j,k3))
                            ind0 = find(dem.strat(:,j,k3)==0); % ==0 should be insensitive to rounding erros because data type is uint8 for dem.strat
                            dem.strat(ind0,j,k3)=2;
                        end
                    end
                end
            end
        end    

        % regenerate arrays for storing cell-edge coordinates
        create_gridlines; % Regenerates structure "gridLines"
    end
    %%% End of nested function resize_grids
    
    function bank_composition_check_gridded %%% Nested function
    % bank_composition_check_gridded.m: % Determines the bank-material composition and calculates an approprate lateral
    % erosion distance for each node in the channel centerline.
        S=numel(centerline.X);
        move_dist=nan(S,1);
        X_cutbank=zeros(S,1); 
        Y_cutbank=zeros(S,1);
        % Define the coordinates of the the channel banks. Left and right
        % banks are defined relative to the flow direction downstream.
        [leftBank,rightBank,~] = channel_margins(centerline,w);
        X_cutbank(R1prime>0)=leftBank.X(R1prime>0); Y_cutbank(R1prime>0)=leftBank.Y(R1prime>0);
        X_cutbank(R1prime<0)=rightBank.X(R1prime<0); Y_cutbank(R1prime<0)=rightBank.Y(R1prime<0);
        X_cutbank_max_move = X_cutbank + 1.02*k_erode_sediment*x_increment; % channel coordinates if each node moved as much as it could (plus a little extra)
        Y_cutbank_max_move = Y_cutbank + 1.02*k_erode_sediment*y_increment; 
        % pre-screen for whether the bank inspection vector (from
        % centerline node to max-move node) exceeds the x extent.
        ind_exceed_extent_L = or(centerline.X<domain.xExtent(1),X_cutbank_max_move<domain.xExtent(1));
        ind_exceed_extent_R = or(centerline.X>domain.xExtent(2),X_cutbank_max_move>domain.xExtent(2));

        % calculate migration distance for each bank node
        for i=1:S % for each bank node
            % 1. Define bank materials search vector from bank node to max. movement node
            % 2. List cells that the search vector crosses
            % 3. Locate intersections between the nominal bank
            % migration vector and grid to determine cells traversed
            
            lgi_mode = 'noshift'; 
            dem_xvec = dem.x(1,:);
            dem_yvec = dem.y(:,1);
            grid_size = size(dem.z);
            [grid_ind,dist_each_interval] = locate_grid_intersections(X_cutbank(i),Y_cutbank(i),X_cutbank_max_move(i),Y_cutbank_max_move(i),gridLines,grid_size,dem_xvec,dem_yvec,lgi_mode,domain);
            
            if ind_exceed_extent_L(i) % temporarily shift search vector back into domain, periodically
                lgi_mode = 'shift1';
                [grid_ind_shift,dist_each_interval_shift] = locate_grid_intersections(X_cutbank(i),Y_cutbank(i),X_cutbank_max_move(i),Y_cutbank_max_move(i),gridLines,grid_size,dem_xvec,dem_yvec,lgi_mode,domain);
            elseif ind_exceed_extent_R(i) % temporarily shift search vector back into domain, periodically
                lgi_mode = 'shift2';
                [grid_ind_shift,dist_each_interval_shift] = locate_grid_intersections(X_cutbank(i),Y_cutbank(i),X_cutbank_max_move(i),Y_cutbank_max_move(i),gridLines,grid_size,dem_xvec,dem_yvec,lgi_mode,domain);
            else
                grid_ind_shift = [];
                dist_each_interval_shift = [];
            end
            grid_ind = [grid_ind;grid_ind_shift];
            dist_each_interval = [dist_each_interval;dist_each_interval_shift];
            
            % Throw an error if any NaN values are returned for the grid index
            % search.
            if any(isnan(grid_ind))                
                err='Error (meander_gridded.m/bank_composition_check_gridded): NaN detected in during grid index search';
                filename=[outputDir,'error_',trial,'_error_data.mat'];
                save(filename)
                error(err)
            end

            % 4. Look up erodibility for the traversed cells. Calculate cost for erosion through each interval, and assign
            % bank migration distance. Erosion can be modified by either bank height, resistant oxbow-filling sediments, or bedrock.
            if bedrock_erosion.modify_lateral_erosion_bedrock
                bdrk_elev = dem.z_bedrock(grid_ind);
                proportion_bedrock = NaN(size(bdrk_elev));
                ind = bdrk_elev >= centerline.Z(i); % if the interface elevation is greater than or equal to the channel bottom elevation plus the channel depth (the water surface), then the bank is all bedrock
                    proportion_bedrock(ind) = 1; 
                ind = bdrk_elev <= centerline.Z(i); % if the interface elevation is below the channel bottom elevation, then the bank is all sediment
                    proportion_bedrock(ind) = 0; 
                ind = isnan(proportion_bedrock); % any unassigned erodibility value represents a bank with some bedrock and some sediment
                    proportion_bedrock(ind) = (bdrk_elev(ind) - centerline.Z(i))/D; % else the interface is sediment over bedrock; change the erodibility based on the proportion of bank (from channel bottom to bank full) that is bedrock
                k_erode_interval = k_erode_sediment*(1-proportion_bedrock)+k_erode_bedrock*proportion_bedrock; % vector
            elseif overbank_deposition.modify_lateral_erosion_bank_height
                bank_elevs = dem.z(grid_ind);
                bank_height_ratio = D./(bank_elevs-centerline.Z(i)); % The ratio of the channel depth to the bank height, where bank height is the difference between the local surface elevation and the local elevation of the channel centerline.
                k_erode_interval = k_erode_sediment*bank_height_ratio; % Adjust the erodibility of this interval according to the bank height ratio.
            elseif overbank_deposition.modify_lateral_erosion_resistant_oxbows
                cutoff_tf = dem.cutoff(grid_ind);
                cell_age=dem.t(grid_ind);      

                % use age of cutoff cells to determine elevation and
                % whether felt or not
                if numel(bed_elev_chg_rate)>1
                     err='Error (meander_gridded.m/bank_composition_check_gridded): Model case with erosion-resistant oxbows only configured for constant rate of bed elevation change';
                    filename=[outputDir,'error_',trial,'_error_data.mat'];
                    save(filename)
                    error(err)    
                else
                    oxbow_elev=centerline.Z(i)-((t-cell_age(cutoff_tf))*bed_elev_chg_rate);
                end
                
                oxbow_frac_coeff=zeros(size(oxbow_elev));
                for j=1:numel(oxbow_frac_coeff)
                    if oxbow_elev(j) >= centerline.Z(i) % if the oxbow scour elevation is greater than or equal to the current local centerline elevation, then bank is all oxbow
                       oxbow_frac_coeff(j)=1;
                    elseif (oxbow_elev(j)+D) < centerline.Z(i) % if the oxbow scour elevation plus the channel depth is below the current local centerline elevation, then bank is all non-oxbow
                        oxbow_frac_coeff(j) = 0; 
                    else % then some oxbow and some non-oxbow. this assumes centerline.Z(i) > oxbow_elev
                        oxbow_frac_coeff(j) = (oxbow_elev(j)+D-centerline.Z(i))/D; % else the interface is sediment over bedrock; change the erodibility based on the proportion of bank (from channel bottom to bank full) that is bedrock
                    end
                end
                k_erode_interval(cutoff_tf)=oxbow_frac_coeff*cutoff_erode_coeff*k_erode_sediment; %%% check this, may need to be linear combination instead
                k_erode_interval(oxbow_frac_coeff==0)=k_erode_sediment;
            end

            % If no process to modify lateral erosion rates is set, then
            % set the erodibility of all intervals to the sediment
            % erodibility.
            if ~bedrock_erosion.modify_lateral_erosion_bedrock && ~overbank_deposition.modify_lateral_erosion_bank_height && ~overbank_deposition.modify_lateral_erosion_resistant_oxbows
                k_erode_interval = repmat(k_erode_sediment,numel(dist_each_interval),1);
            end
            
            cost = dist_each_interval./(k_erode_interval*(sqrt(x_increment(i)^2+y_increment(i)^2))); % cost of moving through each interval

            if sum(dist_each_interval)<1e-6 % would move 1 m/Myr at this rate
                cost(end)=Inf; %For tiny distances, arithmetic is not reliable and can't get a cost >1. This check prevents an error in those cases, forces the node not to move.
            end

            if or(lt(sum(cost),1),ne(numel(cost),numel(dist_each_interval)))
                err='Error (meander_gridded.m/bank_composition_check_gridded): Bank composition check failed';
                filename=[outputDir,'error_',trial,'_error_data.mat'];
                save(filename)
                error(err)                
            end

            cost = [0;cumsum(cost)];
            dist=[0;cumsum(dist_each_interval)];
            % interpolates to find the distance to move where the cost is equal to one.  
            % next three lines are a faster, inline version of interp1
            ind_cost_gt1 = find(cost>1,1,'first');
            add_ratio = (1-cost(ind_cost_gt1-1))/(cost(ind_cost_gt1)-cost(ind_cost_gt1-1));
            move_dist(i) = dist(ind_cost_gt1-1)+add_ratio*(dist(ind_cost_gt1)-dist(ind_cost_gt1-1));      
        end
        %%% bank_composition_check_gridded)
    end
    %%% End of nested function bank_composition_check_gridded
end