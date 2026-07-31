function [modelDataFinal_filename] = meander_vector(inputs)
% meander_vector: Main function for modeling channel evolution within a
% vector-based framework for tracking bank materials.
% Input arguments:
%   inputs: structure array that holds all input variables.
% Output arguments:
%   modelDataFinal_filename: name of final output file with model data.

start_time=clock;
% Unpack the input variables. Cannot use a function to do this (e.g., v2struct.m)  because
% nested functions are used in meander_VBBMT.m; variables cannot 'pop' into existence
% within this function, they must be defined first.
outputDir = inputs.outputDir;
trial = inputs.trial;
k_erode_sediment = inputs.k_erode_sediment;
bed_elev_chg_rate = inputs.bed_elev_chg_rate;
w = inputs.w;        
D = inputs.D;
vertical_incision_style = inputs.vertical_incision_style;
t_max = inputs.t_max;
t_increment = inputs.t_increment;
save_interval = inputs.save_interval;
vertical_file = inputs.vertical_file;
init_centerline_type = inputs.init_centerline_type;
bedrock_erosion = inputs.bedrock_erosion;
overbank_deposition = inputs.overbank_deposition;
nu = overbank_deposition.parameters.nu;
mu_d = overbank_deposition.parameters.mu_d;
lambda = overbank_deposition.parameters.lambda;
oxbow_erode_coeff = overbank_deposition.parameters.oxbow_erode_coeff;
init_plane_slope = inputs.init_plane_slope;
init_centerline_file = inputs.init_centerline_file;
centerline_spacing_coeff = inputs.centerline_spacing_coeff;
domain.xExtentChannelWidths = inputs.domain.xExtentChannelWidths;
BMT = inputs.BMT;
startfile = inputs.startfile;
Cf = inputs.Cf;
epsilon = inputs.epsilon;
g = inputs.g;
gam = inputs.gam;
k = inputs.k;
om = inputs.om; 
rho = inputs.rho;
enforceChannelDisplacementLimit = inputs.enforceChannelDisplacementLimit;

% Parameters specific to vector-based bank-material tracking
k_erode_bedrock = inputs.k_erode_bedrock;
init_plane_max_elev = inputs.init_plane_max_elev;
chkpt.spacing_coeff = inputs.chkpt_spacing_coeff;
bed_elev_chg_poly_addn_thresh = inputs.bed_elev_chg_poly_addn_thresh;
unconfined_alluvial_belt_width = inputs.unconfined_alluvial_belt_width;
init_alluv_width_coeff = inputs.init_alluv_width_coeff;
init_Ev_pulse = inputs.init_Ev_pulse;
pulse_coeff = inputs.init_Ev_pulse;

switch BMT
    case {'channel-only', 'grid-based'}
        run_VBBMT = false;
    case 'vector-based'
        run_VBBMT = true;
end

% Determine the maximum erosion rate coefficient.
if ~isnan(k_erode_bedrock)
    k_erode_max = max([k_erode_bedrock;k_erode_sediment]);
end

% Set maximum run time.
t_max = ceil(t_max/t_increment)*t_increment; % Using ceil ensures that run enough timesteps to include the input maximum time, even if t_increment doesn't divide evenly into maximum time (Example: if t_increment=7 and t_max=100, won't stop at t=98).

%% Define other constants that depend on the input parameters.
init_spacing = centerline_spacing_coeff*w;  

if strcmp(vertical_incision_style,'flat_unsteady')
    load(vertical_file,'bed_elev_chg_rate') % bed_elev_chg_rate replaces existing variable. save times is for saving at times of peak vertical incision rates in pulses (when terraces being abandoned)
end

init_alluv_width=NaN;
init_alluv_depth=NaN; 
if run_VBBMT
    % Set time interval for saving unique polygons.
    poly_save_interval = (D*bed_elev_chg_poly_addn_thresh)/mean(abs(bed_elev_chg_rate));
    if isinf(poly_save_interval) % i.e., when bed_elev_chg_rate = 0, set a finite polygon save interval.
        poly_save_interval=10;
    end
    % Set width and depth of initial alluvial belt.
    if init_alluv_width_coeff > 0
        init_alluv_width=init_alluv_width_coeff*unconfined_alluvial_belt_width;
        init_alluv_depth = D;   
    end
end

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
domain.yExtent = mean(centerline.Y)+[-100000 100000]; % y-extent of domain. The y-extent is arbitrarily large and centered on the mean y-coordiante of the centerline.
domain.corners.x = (domain.xExtent([1 1 2 2]))'; % "frame" is a data structure to hold the domain extent data.
domain.corners.y = (domain.yExtent([1 2 2 1]))';
domain.corners.hole=false; % This field indicates that the model domain polygon coordiantes are not a hole.
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

if run_VBBMT
    % Create a polygon to represent the initial alluvial belt.
    init_alluv_poly = create_init_alluv_poly(domain,init_alluv_width);
    % Create a polygon to represent the initial channel planform extent.
    [newpoly]=create_polygon(centerline,w,domain);

    % Initialize a data structure with fields that store the bank-material polygon
    % and channel geometry, as well as instantaneous erosion rates and bank conditions,
    % for each iteration. Each element of the data structure corresponds to
    % one time step.
    % The fields of the data structure are:
    % "t": Model time
    % "bdrk_topo_polygon": Geometry of polygon that represents the surviving
    % scour surface formed by the channel at iteration "it"
    % "bounding_box": Bounding boxes for each separate polygon in bdrk_topo_polygon.
    % "long_profile": Centerline coordinates at iteration "it"
    % "f_bedrock" (optional):Fraction of bedrock in the bank, measured at each advancing
    % bank (cutbank) location, at iteration "it"
    % "bank_height_ratio" (optional): ratio of channel depth to height of
    % cutbank for case in which lateral erosion rate varies with bank height.
    % "f_oxbow (optional)": Fraction of cutbank composed of oxbow-filling
    % sediments for case in which those sediments alter lateral erosion
    % rate.
    % "El_mean_median_max": mean, median, and maximum lateral erosion rates at
    % iteration "it"
    % "Ev_mean_median_max": mean, median, and maximum lateral erosion rates at
    % iteration "it"

    Data(nTimesteps,1).bdrk_topo_polygon=[]; % Preallocate the data structure with the maximum possible size, set by duration of model run and the time step
    Data(1).bdrk_topo_polygon=newpoly;    
    % Calculate bounding box for each polygon in "bdrk_topo_polygon"
    for q=1:numel(newpoly)
        Data(1).bounding_box(q,1:4)=[min(newpoly(q).x) max(newpoly(q).x) min(newpoly(q).y) max(newpoly(q).y)]; % nx4 array, where each row is [xmin xmax ymin ymax] of a polygon piece
    end
    
    % Initialize variables that will be shared with nested function
    remaining_poly_itStart = []; % Vector to store the iteration number for the initiation of polygons that have not been fully eroded (i.e., remaining)
    bank_height_ratio = [];
    f_oxbow = [];
end

% If simulation starts with a pulse of vertical incision, than enact it. 
switch init_Ev_pulse
    case 'knick'
        centerline.Z(end)=centerline.Z(end)-pulse_coeff*D; % lower only end of centerline
    case 'pulse'
        centerline.Z=centerline.Z-pulse_coeff*D; % lower all parts of centerline
end

% Record additional data from this timestep.
Data(1).centerline=centerline;

if bedrock_erosion.modify_lateral_erosion_bedrock
    Data(1).f_bedrock = [];
end
        
if overbank_deposition.modify_lateral_erosion_bank_height
    Data(1).bank_height_ratio = [];
end

if overbank_deposition.modify_lateral_erosion_resistant_oxbows
     Data(1).f_oxbow = [];
end
    
Data(1).El_mean_median_max=[];
Data(1).Ev_mean_median_max=[];

if run_VBBMT
    % Create a void polygon ("voidpoly") to record the geometry of the
    % parts of the model domain that haven't been occupied by the channel.
    voidpoly=domain.corners;
    voidpoly = PolygonClip(voidpoly,newpoly,0);
    for q=1:numel(voidpoly)
        voidpoly(q).bounding_box = [min(voidpoly(q).x) max(voidpoly(q).x) min(voidpoly(q).y) max(voidpoly(q).y)];
    end

    % Set thresholds for adding new bank-material polygons during the simulation.
    all_poly_itStart=1;  % For all polygons, stores the iteration number at which the polygon initiated. This sets first polygon as it's own (it's unlumped), because for constant-width simulations, this polygon is derived from a single centerline which may have width greater than the channel width
    current_poly_itStart=1; % For the currently active polygon, stores the iteration number at which it was initiated.
    vertical_incision_stored=0; % Total vertical incision since creation of the current polygon, in units of channel depth.
end

next_save_time=save_interval; % Next time at which to export model data.
initialization_tf = false; % Flag the end of the initialization phase.																						
																						
% Start of time loop - evolve channel, topography, and bedrock-sediment interface.
last_percent_complete=0; % Variable for reporting simulation progress.
																						
for it = 2:nTimesteps % Treat iteration 1 as the initial condition, so start with iteration 2
    t = t+t_increment; % increment time
    Data(it).t = t;
    if run_VBBMT
        if strcmp(vertical_incision_style,'flat_unsteady')
            vertical_incision_stored=vertical_incision_stored + abs(bed_elev_chg_rate(it)*t_increment)/D; % % Increment the total vertical incision since creation of the current polygon, in units of channel depth.
        else
            vertical_incision_stored=vertical_incision_stored + (abs(bed_elev_chg_rate)*t_increment)/D; % Increment the total vertical incision since creation of the current polygon, in units of channel depth.
        end
    end
    
	% Compute (x,y,z) increments to move channel centerline nodes. Lateral migration increments (x,y) are scaled initially for a maximum lateral migration rate of ~ 1 m/yr). Also output the direction of node dshifting and the sinuosity.
    max_step_init = NaN; % this parameter is only used during the initialization phase, so set to NaN here.
	
    [x_increment,y_increment,z_increment,move_az,~,~,R1prime] = howard_knutson_periodic(initialization_tf,max_step_init,outputDir,trial,centerline,init_spacing,w,D,Cf,k,om,gam,epsilon,k_meander,t_increment,vertical_incision_style,bed_elev_chg_rate,it);
    
    if run_VBBMT
        % Create a search buffer vector, with x- and y-components, to restrict the search for intersected polygons during bank composition check.
        % The search buffer vector is chosen to be slightly longer than the maximum possible bank migration distance that corresponds to the maximum lateral erosion coefficient k_erode_max.
        search_buffer_x = 1.02*k_erode_max*x_increment;
        search_buffer_y = 1.02*k_erode_max*y_increment;
        % Run bank composition check by calling nested function "bank_composition_check"
        bank_composition_check; % Generates the variable "move_dist", which is a vector of the distance to move node accounting for bank-material properties.
        move_dist(end)=move_dist(1); 	% The first node and last node in the centerline vector move in tandem as part of the periodic boundary condition.
        f_bedrock = ((move_dist./abs(R1prime))-k_erode_sediment)/(k_erode_bedrock-k_erode_sediment); % f_bedrock recalculates the fraction of bedrock in the cutbank for each node, measured from the channel bed to the bankfull height.
        % Recalculate the (x,y) movement increments for the centerline nodes following the bank-material composition check.
    	x_increment=move_dist.*cos(move_az);
    	y_increment=move_dist.*sin(move_az); 
    else
        % If not running vector-based bank-material tracking, calculate the
        % x- and y-increments using the maximum erodibility coefficient.
        k_e = max([k_erode_sediment,k_erode_bedrock]);
        x_increment = k_e*x_increment;
        y_increment = k_e*y_increment;
    end				
    increments = sqrt(x_increment.^2+y_increment.^2);
        
    if enforceChannelDisplacementLimit
        % Throw an error and output variables if the bank migration distance anywhere is greater than or equal to the channel width.
        if any(increments>=w)
            err='Error (meander_vector.m): Bank migration larger than a channel width in one timestep. Review move_dist/w and decrease timestep';
            filename=[outputDir,'run_',trial,'_error_data.mat'];
            save(filename)
            error(err)
        end
    end
    
	% Adjust the centerline nodes using the calculated increments and check for cutoff and interpolation.																				
	[centerline,cutoff_interp_stats] = adjust_centerline_nodes(centerline,w,init_spacing,x_increment,y_increment,z_increment,domain,vertical_incision_style,it,trial,outputDir,cutoff_interp_stats);

    if run_VBBMT
        % Create the polygon that represents the current channel footprint; name it "newpoly".
        newpoly=create_polygon(centerline,w,domain);

        % Based on the current time step and the cumulative vertical incison since the saving of a new bank-material polygon, determine whether to save a new polygon.																					
        save_to_new_poly=false; % Reset "save_to_new_poly" to false.
        if it==2 % Always save a new polygon at second iteration so that the polygon corresponding to the initial condition (iteration 1) is preserved. 
            save_to_new_poly=true;
            vertical_incision_stored=0; % Reset the cumulative vertical incision since the last time a new polygon was saved to 0.
        else
            if strcmp(vertical_incision_style,'flat_unsteady')
               if vertical_incision_stored >= bed_elev_chg_poly_addn_thresh  % Save a new polygon if sufficient vertical incision has occurred.
                   save_to_new_poly=true;
                   vertical_incision_stored=0; % reset to zero
               end
            else
                if (t-poly_save_interval)> Data(current_poly_itStart).t  % Save a new polygon if sufficient time has elapsed since initiation of current polygon.
                    save_to_new_poly=true;
                end
            end
        end

        % Merge the new channel footprint with most the recent polygon, if warranted, and clip pre-existing polygons.
        if save_to_new_poly
            all_poly_itStart=[all_poly_itStart;it]; % Update vector that stores all the iterations with unique lumping polygons (even if they get erased).
            current_poly_itStart = it; % Update iteration of initiation of current bank-material polygon.
            Data(it).bdrk_topo_polygon = newpoly; % Save the new polygon to the "Data" data structure.
            % Create the bounding box for each separate piece of the new polygon.
            Data(it).bounding_box = zeros(numel(newpoly),4); 
            for i9=1:numel(newpoly)
                Data(it).bounding_box(i9,1:4)=[myMinMax(newpoly(i9).x) myMinMax(newpoly(i9).y)];
            end
        else
            % Find the union of the new channel polygon with the current bank-material polygon and add to "Data" data structure.																				
            unionpoly = PolygonClip(Data(current_poly_itStart).bdrk_topo_polygon,newpoly,3); % case 0, A-B; case 1, A&B; case 2, xor(A,B); case 3, A+B.
            Data(current_poly_itStart).bdrk_topo_polygon = unionpoly;

            % Update bank-material polygon bounding boxes.
            Data(current_poly_itStart).bounding_box = zeros(numel(unionpoly),4);
            for i9=1:numel(unionpoly)
                Data(current_poly_itStart).bounding_box(i9,1:4)=[myMinMax(unionpoly(i9).x) myMinMax(unionpoly(i9).y)];
            end
        end
    end
	% For the current iteration, save values for longitudinal profile, fraction of bedrock in the cutbank, lateral and vertical erosion rates, and the lateral migration rate unscaled for bank-material properties to the "Data" data structure.
	Data(it).centerline = centerline;
	Data(it).El_mean_median_max=[mean(increments),median(increments),max(increments)]/t_increment;
	Data(it).Ev_mean_median_max=[mean(z_increment),median(z_increment),max(z_increment)]/t_increment;
	Data(it).R1prime=R1prime;
    
    if run_VBBMT
        if bedrock_erosion.modify_lateral_erosion_bedrock
            Data(it).f_bedrock = f_bedrock; 
        end
        
        if overbank_deposition.modify_lateral_erosion_bank_height
            Data(it).bank_height_ratio = bank_height_ratio;
        end
    
        if overbank_deposition.modify_lateral_erosion_resistant_oxbows
            Data(it).f_oxbow = f_oxbow;
        end
        
        % Clip the void polygon "voidpoly" that represents the boundaries of the model domain visited by channel migration.
        voidpoly = PolygonClip(voidpoly,newpoly,0); % always keep holes in voidpoly
        % Update the "voidpoly" bounding boxes.
        for i8=1:numel(voidpoly)
            voidpoly(i8).bounding_box = [myMinMax(voidpoly(i8).x) myMinMax(voidpoly(i8).y)];
        end

        % Clip pre-existing bank-material polygons, *excluding the current bank-material polygon initiated at iteration "current_poly_itStart"*. New channel areas take precedence over old.
        for i8=1:numel(remaining_poly_itStart)
            if ne(remaining_poly_itStart(i8),current_poly_itStart)
                oldpoly=Data(remaining_poly_itStart(i8)).bdrk_topo_polygon; % "oldpoly" is structure array that holds the older polygon's geometry.
                oldpoly_clipped = PolygonClip(oldpoly,newpoly,0); % case 0, A-B; case 1, A&B; case 2, xor(A,B); case 3, A+B.
                if isempty(oldpoly_clipped)
                    % If the old polygon has been completely eroded, update the data structure "Data" to reflect that but retain the other fields for that time step.
                    Data(remaining_poly_itStart(i8)).bdrk_topo_polygon=[];
                    Data(remaining_poly_itStart(i8)).bounding_box=[];
                else
                    % If part of the old polygon remains, update its geometry and bounding box in the "Data" data structure.
                    Data(remaining_poly_itStart(i8)).bdrk_topo_polygon=oldpoly_clipped;
                    Data(remaining_poly_itStart(i8)).bounding_box = zeros(numel(oldpoly_clipped),4);
                    for i9=1:numel(oldpoly_clipped)
                        Data(remaining_poly_itStart(i8)).bounding_box(i9,1:4)=[myMinMax(oldpoly_clipped(i9).x) myMinMax(oldpoly_clipped(i9).y)];
                    end
                end
            end              
        end
    
	    % Export data at intervals set by "next_save_time"
	    if t >= next_save_time
		    model_performance.seconds_per_iteration = toc; % Time to complete one iteration, in seconds.
		    next_save_time = t-mod(t,save_interval)+save_interval;
		    filename=[outputDir,'run_',trial,'_modelData_time_',num2str(t),'.mat'];
		    save(filename)
		    fprintf('Saving data for run %s, t=%d yr\n',trial,t)
	    end
		
	    % If going to save next iteration, start iteration timer.
	    if and(t<next_save_time,(t+t_increment) >= next_save_time)
		    tic
	    end 
    
	    % Print the percentage of the model run that has been completed.
	    percent_complete = floor((t/t_max)*100);
	    percent_increment=5; % 5% increments
	    if percent_complete > (last_percent_complete+(percent_increment-1))
		    fprintf('Run %s, %d percent complete\n',trial,percent_complete)
		    last_percent_complete = percent_complete;    
	    end
																						
	    % The first and last nodes of the centerline should have the same coordinate. If they don't, throw an error.																					
	    if abs(centerline.X(end)-centerline.X(1)-domain.xRange)>0.1
		    err='Error (meander_vector.m): centerline X-coordinate range exceeded';
		    filename=[outputDir,'error_',trial,'_error_data.mat'];
		    save(filename)
		    error(err)
        end
    end
end % end time loop
    
% Save all variables at conclusion of simulation
end_time=clock; % Completion time.
model_performance.run_time=end_time-start_time; % Total time to run the model.
modelDataFinal_filename=[outputDir,'run_',trial,'_modelDataFinal.mat']; % Final data file for the model run.
save(modelDataFinal_filename)
fprintf('Finished run %s\n',trial) % Print to screen.
    
    function bank_composition_check
        % bank_composition_check: A nested function that determines the bank-
        % material composition and calculates and approprate lateral
        % erosion distance for each channel centerline node.
        S=numel(centerline.X); % Number of elements in the centerline vectory.
        move_dist=nan(S,1); % Initialize vector "move_dist" that will record the movement distances for each centerline node.
        f_bedrock=nan(S,1); % Initialize vector "f_bedrock" that will record the fraction of bedrock in the cutbank for each centerline node.
        % Define the coordinates of the the channel banks. Left and right
        % banks are defined relative to the flow direction downstream.
        [leftBank,rightBank,~] = channel_margins(centerline,w);
																						
        % Make temporary variables to store the centerline; these can be shifted
        % by domain.xRange for the purposes of the periodic boundary condition
        % without affecting the basis centerline, "centerline". The coordinates of the cutbank
        % and the maximum bank movement location "max_move" are re-defined
        % with the centerline every iteration, so there is no need to make temporary variables for them.
		centerline_periodic.X=centerline.X; % Temporary vector to store centerline x-coordinates.
		centerline_periodic.Y=centerline.Y; % Temporary vector to store centerline y-coordinates.
																						
        % Calculate node migration distance accounting for bank-material composition and move nodes.
        X_cutbank=zeros(S,1); % Preallocate cutbank x-coordinates.
        Y_cutbank=zeros(S,1); % Preallocate cutbank y-coordinates.
        X_cutbank(R1prime>0)=leftBank.X(R1prime>0); % cutbank x-coordinates for the first set of migration directions (bank advance or bank retreat).
		Y_cutbank(R1prime>0)=leftBank.Y(R1prime>0); % cutbank y-coordinates for the first set of migration directions (bank advance or bank retreat).
        X_cutbank(R1prime<0)=rightBank.X(R1prime<0); % cutbank x-coordinates for the second set of migration directions (bank advance or bank retreat).
		Y_cutbank(R1prime<0)=rightBank.Y(R1prime<0); % cutbank y-coordinates for the second set of migration directions (bank advance or bank retreat).
																						
        % Determine the maximum search distance for the bank composition check, adding a factor of 2% to avoid round-off errors.
		% "X_cutbank_max_move" and "Y_cutbank_max_move" represent the upper bounds for cutbank coordinates (x,y) if each node moved as much as it could.
        X_cutbank_max_move = X_cutbank + 1.02*k_erode_max*x_increment; 
        Y_cutbank_max_move = Y_cutbank + 1.02*k_erode_max*y_increment;
																						
        % Retrieve existing bank-material polygons.
        polygons_by_itStart = {Data(1:it-1).bdrk_topo_polygon}'; % Bank-material polygons, grouped by iteration number of polygon initiation, in each cell of a cell array.
        % Prior to checking for search vector intersections with these bank-material polygons, convert the polygons from structures inside
		% the cell array to a numeric array in which NaNs delimit polygons.
																						
        num_poly_vertices_each_it= zeros(size(polygons_by_itStart)); % Preallocate an array to store the total number of polygon vertices for the bank-material polygon from each iteration.
		num_vert_each_subpolygon = cell(size(polygons_by_itStart)); % Preallocate a cell array to store the number of vertices for each subpolygon for each iteration.
        npolygons =  sum(cellfun('length',{Data(:).bdrk_topo_polygon}')); % Number of bank-material polygons.

		% Preallocate a master polygon structure array ("poly_master") to store bank-material polygons in a convenient format for subsequent operations.					 
		poly_master.poly_vert_split_cell = cell(npolygons,1); % Cell array that stores polygon vertices, split into cells for different polygons.
        poly_master.itStart=nan(npolygons,1); % Array that stores the iteration of initiation for each polygon.
        poly_master.hole=false(npolygons,1); % Logical array that flags whether the polygon is a hole or not. Initialize as false because the data type is logical.
        poly_master.poly_index=nan(npolygons,1); % Array that stores a unique index for each polygon.
        poly_master.numel = nan(npolygons,1); % Array that stores the number of vertices in each polygon.
        								 
		% For each iteration that initiated a new polygon, retrieve the vertex coordinates of each subpolygon and populate the fields of poly_master.
		row=1; % Initialize row.
		count=1; % Initialize counter.
        for i6=1:numel(polygons_by_itStart) 
            if ~isempty(polygons_by_itStart{i6})
                % get all x and y values for all of this iteration's
                % polygons, including holes.
                polyx={polygons_by_itStart{i6}(:).x}; % Polygon x-coordinates.
                polyy={polygons_by_itStart{i6}(:).y}; % Polygon y-coordinates.
                nrows = numel(polygons_by_itStart{i6}); % Count number of rows needed to record these coordinates.
                for i10=1:nrows
                     poly_master.poly_vert_split_cell{row+i10-1,1} = [polyx{i10}([1:end,1]),polyy{i10}([1:end,1]); NaN NaN]; % This formatting lists the (x,y) coordinates of the separate subpolygons in an Nx2 array within each cell, where each subpolygon is separated by NaN values.
                     poly_master.numel(count)=numel(polyx{i10})+2;
                     count=count+1;
                end
                row=row+nrows;
                num_vert_each_subpolygon{i6} = (cellfun('length',polyx)+2)'; % Number of vertices for each subpolygon, including duplicated 1st index and NaN value.
                num_poly_vertices_each_it(i6) = sum(num_vert_each_subpolygon{i6}); % Number of polygon vertices for each iteration.
            end
        end
        clear polygons_by_itStart 
        remaining_poly_itStart = find(num_poly_vertices_each_it); % Iterations for which polygons initiated at that iteration still remain.
        subpolygon_bounding_boxes = cell2mat({Data(remaining_poly_itStart).bounding_box}'); % The bounding boxes of all subpolygons as a single nx4 array.

		% Make a vector that stores a subpolygon index for each polygon.
        row1=1;
        ind=1;
        for i3=1:numel(remaining_poly_itStart)
            for i4=1:numel(Data(remaining_poly_itStart(i3)).bdrk_topo_polygon)
                poly_master.itStart(row1)=remaining_poly_itStart(i3); % Stores iteration of initiation for each polygon.
                poly_master.hole(row1)=(Data(remaining_poly_itStart(i3)).bdrk_topo_polygon(i4).hole==1); % Stores whether polygon is a hole or not.
                poly_master.poly_index(row1) = ind; % Unique index for the subpolygon.
                row1=row1+1;   
                ind=ind+1;
            end
        end
        
        %% Void polygons
		% Get all x and y values for void polygons; make cell array for the (x,y) coordinates; 
		% use cellfun to duplicate the first element at the end of the array in order to close the polygon.
        voidpoly_x=cellfun(@(x) [x([1:end,1]);NaN],{voidpoly(:).x}','UniformOutput',false); % Formats x-coordinates as x... NaN in each column.
        voidpoly_y=cellfun(@(x) [x([1:end,1]);NaN],{voidpoly(:).y}','UniformOutput',false); % Formats y-coordinates as y... NaN in each column.
        voidpoly_master.voidpoly_vert_cell=cell(numel(voidpoly_x),1); % Cell array that stores void polygon vertices.
        for i3=1:numel(voidpoly_x)
            voidpoly_master.voidpoly_vert_cell{i3} = [voidpoly_x{i3},voidpoly_y{i3}]; % Populate the cell array that stores void polygon vertices.
        end
        voidpoly_bounding_boxes = cell2mat({voidpoly(:).bounding_box}'); % All void polygon bounding boxas as a single nx4 array.               
        
        %% Calculate migration distance for each bank node, accounting for bank-material properties.
        % Pre-screen for whether the bank properties search vector (from centerline node to max-move node) exceeds the x extent. If so, then shift the coordinates back into the domain extent using the periodic boundary condition.
        ind_exceed_extent_L = or(centerline_periodic.X<domain.xExtent(1),X_cutbank_max_move<domain.xExtent(1)); % Centerline/cutbank node indices for which the search vector passes outside the left x-extent of the model domain.
        ind_exceed_extent_R = or(centerline_periodic.X>domain.xExtent(2),X_cutbank_max_move>domain.xExtent(2)); % Centerline/cutbank node indices for which the search vector passes outside the right x-extent of the model domain.
        ind_exceed_extent = or(ind_exceed_extent_L,ind_exceed_extent_R); % All centerline/cutbank node indices for which the search vector passes outside the x-extent of the model domain.      
        for i=1:S-1 % For each centerline/cutbank node...
            if ind_exceed_extent(i) % If the search vector extends outside the model domain...
                orig_coords = [centerline_periodic.X(i),X_cutbank(i),X_cutbank_max_move(i)]; % Note the original x-coordinates of the centerline node, cutbank node, and point of maximum possible bank migration.
			    xytihd_all_orig = locate_polygon_intersections; % Identify where the search vector intersects bank-material polygons using "locate_polygon_intersections", and place those intersection points in an ordered list.  The list is an nx6 array where the columns correspond to the following properties for each intersection: x-coordinate, y-coordinate, iteration of initiation of the bank-material polygon, subpolygon index, a flag for whether the subpolygon is a hole, and the distance along the search vector.
                % Temporarily shift the bank, cutbank, and maximum possible bank migration point for the indices that exceed the extent of the model domain.
                if ind_exceed_extent_L(i)
					% If domain exceedance was on the left side of the model domain, add the shift distance.
                    centerline_periodic.X(i)=centerline_periodic.X(i)+domain.xRange; % Add domain.xRange to temporary centerline x-coordinates.
                    X_cutbank(i)=X_cutbank(i)+domain.xRange; % Add to cutbank x-coordiantes.
                    X_cutbank_max_move(i)=X_cutbank_max_move(i)+domain.xRange; % Add to point of maximum possible bank migration x-coordinates.
                    xytihd_all_shift = locate_polygon_intersections; % Locate bank-material polygon intersections for the shifted search vector x-coordinates.
                    if ~isempty(xytihd_all_shift)
                        xytihd_all_shift(:,1)=xytihd_all_shift(:,1)-domain.xRange; % Shift bank-material polygon intersection coordinates back to the same reference frame as unshifted coordinates.
                    end
                else % ind_exceed_extent_R(i)
                    % If domain exceedance was on the right side of the
                    % model domain, subtract the shift distance,
                    centerline_periodic.X(i)=centerline_periodic.X(i)-domain.xRange;
                    X_cutbank(i)=X_cutbank(i)-domain.xRange;
                    X_cutbank_max_move(i)=X_cutbank_max_move(i)-domain.xRange;
                    xytihd_all_shift = locate_polygon_intersections;
                    if ~isempty(xytihd_all_shift)
                        xytihd_all_shift(:,1)=xytihd_all_shift(:,1)+domain.xRange; % Shift bank-material polygon intersection coordinates back to the same reference frame as unshifted coordinates.
                    end
                end
                % Restore the original coordinates for the points in the
                % search vector.
                centerline_periodic.X(i)=orig_coords(1);
                X_cutbank(i)=orig_coords(2);
                X_cutbank_max_move(i)=orig_coords(3);
                % If the search vector crossed the domain extent, combine
                % the bank-material polygon intersections for the original
                % and shifted coordinates.
                n_orig_rows = size(xytihd_all_orig,1);  % Number of rows in the intersections array for the original coordinates.
                n_shift_rows = size(xytihd_all_shift,1);  % Number of rows in the intersections array for the shifted coordinates.
                if or(n_orig_rows==0,n_shift_rows==0) || mean(xytihd_all_orig(:,end))-mean(xytihd_all_shift(:,end)) > 1e-8 % If either intersections array has no elements, or the mean distance for intersections along the search vector is the same for both arrays, then concatenate with the intersections for the shifted coordinates first.
                    xytihd_all = [xytihd_all_shift;xytihd_all_orig];
                else
                    xytihd_all = [xytihd_all_orig; xytihd_all_shift]; % Otherwise, concatenate with the intersections for the original coordinates first.
                end 
                % If no bank-material polygon intersections were detected,
                % as is possible for the case where the search vector
                % extends out of the model domain, then add the cutbank
                % point to the list of bank-material polygon intersections.
                % The "t" field (element 3 of the array) is the initiation
                % iteration of the current bank-material polygon,
                % "current_poly_itStart". Set the subpolygon index to NaN, the polygon hole
                % flag to false, and the distance from the centerline node
                % as half the channel width.
                if isempty(xytihd_all)
                    xytihd_all = [X_cutbank(i) Y_cutbank(i) current_poly_itStart NaN false w/2];
                end  
            else
                xytihd_all=locate_polygon_intersections; % If none of the search vector points excent outside of the model domain, then simply locate the bank-material polygon intersections without any coordinate shifting.            
            end
            xytihd_all_save=xytihd_all; % Save a copy of the bank-material polygon intersections list so it is available for debugging purposes.
            endpt_dist = sqrt((X_cutbank_max_move(i)-centerline_periodic.X(i))^2+(Y_cutbank_max_move(i)-centerline_periodic.Y(i))^2); % For help with sorting the bank-material polygon intersections by distance along the search vector, record the distance from the channel centerline node to the point at the maximum bank migration distance. 
            
            % Compose the final list of points for inspecting bank materials. The list consists of (1) the
            % channel centerline node, (2) the cutbank node, and (3) the
            % other bank-material polygon intersection points. The cutbank
            % node may be repeated in the list - that helps with point sorting.
            
            % Bring any points associated with the current polygon
            % (iniated at iteration = current_poly_itStart) to the top of the list so that they'll be
            % ordered right after the centerline and cutbank points
            rowInd = xytihd_all(:,3)==current_poly_itStart;
            xytihd_all = [xytihd_all(rowInd,:);xytihd_all(~rowInd,:)];
            
            % Sort by distance along the search vector.
            xytihd_all=sortrows(xytihd_all,6);
            
            xytihd_all=[[centerline.X(i),centerline.Y(i),current_poly_itStart,NaN,false,0];
                            [X_cutbank(i),Y_cutbank(i),current_poly_itStart,NaN,false,w/2];
                                xytihd_all];                    
            
            xytihd_all_debug = xytihd_all;
            
           % Sort the points into pairs that define intervals within the
           % same polygon. To do so, compare the current point in the list to each of the next two
           % points in the list. If each of the next two points is at the
           % same distance (within a precision), but only the second point
           % has a polygon initiation iteration equal to the current point, 
           % then swap the order of the next two points. 
           ind=1;
           while ind<(size(xytihd_all,1)-1)
               currentPoint_it = xytihd_all(ind,3);
               onePointAhead_d = xytihd_all(ind+1,6);
               twoPointsAhead_t = xytihd_all(ind+2,3);
               twoPointsAhead_d = xytihd_all(ind+2,6);
               if twoPointsAhead_t == currentPoint_it && abs(twoPointsAhead_d-onePointAhead_d)<1e-8
                   xytihd_all([(ind+1),(ind+2)],:) = xytihd_all([(ind+2),(ind+1)],:);
               end
               ind = ind+1;
           end
           
           % Now that the points are properly ordered, add the point at the maximum possible bank migration distance
           % to the end of of the search vector intersection points list.
           xytihd_all= [xytihd_all;[X_cutbank_max_move(i) Y_cutbank_max_move(i) xytihd_all(end,3:5) endpt_dist]]; % iteration, subpolygon index, and hole flag are duplicated from the existing last point in the list; endpt_dist is the distance from the centerline node to the point at the maximum possible bank migration distance.
        
           % Remove any points in the list of points along the search
           % vector that are within channel (i.e., distance < half the
           % channel width).
            ind_remove=((xytihd_all(:,6)-w/2)<-1e-8); % Use -1e-8 rather than zero due to numerical precision.
            if all(ind_remove) % But don't remove any points if this check indicates removing all the points.
                ind_remove(end)=false;
            end
            xytihd_all(ind_remove,:)=[]; % Remove the points from the list.

            % Check that there are no unexpected distances (i.e., distances that don't increase monotonically along the search vector). Sort by
            % distance along the search vector as a backup measure.
            if any(find(diff(xytihd_all(:,6))<-1e-8))
                xytihd_all=sortrows(xytihd_all,6);
            end
            
            % With the intervals now defined, can reduce to a list of points that define the start of each new interval. 
            % Therefore, identify consecutive points with the same
            % iteration of polygon inititation and 
            % remove any duplicates after the first pair, keeping the
            % second point and always the last point.
            duplicate_point= [xytihd_all(1:end-1,3)==xytihd_all(2:end,3);false];
            solitary_point = ~duplicate_point;                       
            xytihd_all=xytihd_all(solitary_point,:);

            % Determine the iteration number and elevation of the channel scour surface that corresponds to each bank-material polygon. This elevation is hereafter 
			% referred to as the bedrock elevation ("bdrk_elev"). Either of
			% two methods is used to look up the bedrock elevation and the
			% scour iteration.
                
            % Case 1: Uses the elevation and scour iteration associated with
            % the bank-material polygon. This option is faster but less
            % precise.
                                
            % Case 2: Looks up elevation and scour iteration by using
            % checkpoints within the bank-material polygons.
                % Checks distance from the checked point to all
                % channel centerlines during time interval represented by the polygon. The algorithm checks
                % points at a regular distance interval between polygon intersection
                % locations.
                    % Steps for Case 2:
                    % 1. Define checkpoints (x,y). Fill in sampling between polygon
                    % intersections at a set distance interval.
                    % 2. Identify the set of past channel positions that correspond to each polygon
                    % intersection.
                    % 3. For each set of checkpoints in a polygon, assign the corresponding bedrock
                    % elevation and scour iteration using the elevation of closest longitudinal profile point from
                    % the past channel positions selected in step 2.
            
            % If the longitudinal profile does have a slope, then the bedrock elevation has to be looked up by querying the longitudinal profile
            % responsible for setting the elevation at the checked point. If
            % lateral erosion rate is modified by overbank deposition, the same
            % is true. So force lookup of past channel positions for those
            % cases.
            lookup_it_scour_checkpoints = false; % Initialize variable
            switch vertical_incision_style
                case {'sloping steady','shear_stress'}
                    lookup_it_scour_checkpoints = true;
            end
                    
            if overbank_deposition.enable
                lookup_it_scour_checkpoints = true;
            end
            
            if isempty(xytihd_all) % If there are no points in the polygon intersections list...
               filename=[outputDir,'run_',trial,'_error_data.mat'];
               err='Error (meander_vector.m/bank_composition_check): Empty polygon intersections list';
               save(filename)
               error(err)
            end                

            if ~lookup_it_scour_checkpoints
                dist_each_interval=diff([w/2;xytihd_all(:,6)]); % The distance within each interval between bank-material polygon intersection points.
                scour_it = xytihd_all(:,3); % The initiation iteration of each bank-material polygon.
                bdrk_elev=nan(size(scour_it)); % Preallocate array to store bedrock elevation.
                bdrk_elev(scour_it==0)=init_plane_max_elev; % The bedrock elevation for poly_t==0 (i.e., a void polygon intersection) is the elevation of the initial planar surface.
                for q=1:numel(bdrk_elev) 
                    if scour_it(q)>0
                        bdrk_elev(q)=Data(scour_it(q)).centerline.Z(1); % For scour_it > 0, look up the bedrock elevation for the longitudinal profile. Use the first point in the longitudinal profile because all the points in the profile have the same elevation.
                    end
                end

                % If the width of the initial alluvial belt is greater than zero, then the bedrock elevation for any points within the initial 
                % alluvial belt must be at least as low as the original bedrock surface there. 
                if init_alluv_width >0 
                    coords_xy=xytihd_all(1,1:2); % Pull out just the (x,y) coordiantes of the polygon intersections.
                    within_init_alluv_poly = and(coords_xy(:,2)>init_alluv_poly.ymin,coords_xy(:,2)<init_alluv_poly.ymax); % Logical array indicating whether each point is within the initial alluvial belt polygon.
                    % Calculate the initial bedrock elevation in the alluvial belt as the orignal plane elevation minus the initial thickness of sediment in the alluvial belt.
                    bdrk_elev_orig = init_plane_max_elev-init_alluv_depth;
                    ind_replace = and(within_init_alluv_poly,bdrk_elev_orig<bdrk_elev); % Replace bedrock elevations or those points within the initial alluvial belt if the initial bedrock depth is lower than the bedrock depth calculated above.
                    bdrk_elev(ind_replace)=bdrk_elev_orig;
                end
            else % i.e., lookup_it_scour_checkpoints == true
                % Set spacing of bedrock elevation checkpoints (hereafter referred to as "checkpoints"), in meters.
                if it<=2
                    chkpt.spacing=chkpt.spacing_coeff*k_erode_bedrock*t_increment;  % For first two iterations, set the checkpoint coefficient spacing proportional to the bedrock erodibility and the time step.
                else
                    chkpt.spacing=chkpt.spacing_coeff*Data(it-1).El_mean_median_max(2)*t_increment; % Set the checkpoint spacing proportional to the median lateral erosion rate from that iteration, and the time step.
                end
                
                if xytihd_all(end,end)<(w/2+chkpt.spacing) % Reduce the checkpoint spacing if it is larger than the distance from the cutbank to the last polygon intersection point.
                    chkpt.spacing = (w/2-xytihd_all(end,end))/2;
                end
                interp_chkpt_dist_even_spacing = ((w/2):chkpt.spacing:xytihd_all(end,end))'; % Set the checkpoint distances along the search vector as equally spaced between the cutbank and the last polygon intersection point.
                chkpt.d = my_unique(sort([interp_chkpt_dist_even_spacing;xytihd_all(:,end)])); % Identify the unique distances along the search vector.
                chkpt.xy_fracind = interp1q([(w/2);xytihd_all(:,end)],[X_cutbank(i),Y_cutbank(i),0;[xytihd_all(:,1:2),(1:size(xytihd_all,1))']],chkpt.d); % Interpolate for the (x,y) coordinates of the checkpoints and their fractional indices between the polygon intersection indices. 
                chkpt.xy_fracind((chkpt.xy_fracind(:,3)==0),3)=1; % This condition ensures that the index for the first point after the cutbank doesn't round to zero.

                rows_remove=isnan(chkpt.xy_fracind(:,1)); % Sometimes get NaN rows from interpolation, so remove them.
                chkpt.d(rows_remove)=[]; % Remove NaN rows from checkpoint distance array.
                chkpt.xy_fracind(rows_remove,:)=[]; % Remove NaN rows from checkpoint (x,y,fractional index) array
                % Assign the corresponding iteration of polygon initiation  for each checkpoint.
                chkpt.poly_itStart = xytihd_all(ceil(chkpt.xy_fracind(:,3)),3); % The iteration of polygon initiation for each checkpoint is retrieved by looking up the iteration of polygon initiation assigned to the nearest polygon intersection point with a larger index (i.e., "ceil"). 
                poly_itStart_unique=my_unique(chkpt.poly_itStart); % Unique polygon initation iterations for the checkpoints.
                chkpt.bdrk = nan(size(chkpt.d)); % Preallocate array to store the bedrock elevation for each checkpoint, to be assigned in the following loop.
                chkpt.scour_it = nan(size(chkpt.d)); % Preallocate array to store the scour iteration for each checkpoint, to be assigned in the following loop.
                % In this loop, assign the proper bedrock elevation and scour iteration at each checkpoint. Query the past channel positions that correspond to each bank-material polygon and identify the profile from the latest-occurring time step that was close enough for its channel footprint to have encapsulated the checkpoint.
                for n=1:numel(poly_itStart_unique) % For each unique polygon initiation iteration represented in the checkpoint list.
                    chkpt.ind = find(chkpt.poly_itStart == poly_itStart_unique(n)); % Identify the indices of the checkpoints with this polygon initiation iteration.
                    if poly_itStart_unique(n)>1 % If the polygon initiation iteration was greater than 1. (An iteration of 0 corresponds to the voidpolygon; an iteration of 1 corresponds to the initial alluvial belt.)
                        if poly_itStart_unique(n)==current_poly_itStart % If the checkpoint's polygon initiation iteration corresponds to the currently growing polygon...
                            it_end= it-1; % Then only query past channel positions only up to the iteration before the current one.
                        else
                            it_end = all_poly_itStart(find(all_poly_itStart==poly_itStart_unique(n))+1)-1; % Otherwise, query the channel positions only up to the last time step included in the bank-material polygon.
                        end
                        % use structure array "channelLookup" to gather
                        % variables associated with looking up past
                        % channel positions.
                        channelLookup.it_query=(poly_itStart_unique(n):it_end)'; % Array of iterations to query for whether the checkpoint was within the channel
                        channelLookup.dist_channel_to_chkpt = zeros([size(chkpt.ind,1),numel(channelLookup.it_query)]); % Initialize array that records the minimum distance from each channel profile to the subset of checkpoints
                        channelLookup.normalized_dist_along_channel_all = zeros([size(chkpt.ind,1),numel(channelLookup.it_query)]); % Initialize an array that stores, for the nearest point along each queried channel to the subset of checkpoints, its normalized distance along the channel 
                        channelLookup.coords_all = cell(numel(channelLookup.it_query),1); % Initialize a cell array to store all channel coordinates for iterations that are queried
                        for h=1:numel(channelLookup.it_query) % For each iteration to query the channel position...
                            centerline_retrieved = Data(channelLookup.it_query(h)).centerline; % Retrieve the channel centerline coordinates from the "Data" data structure.
                            % In keeping with the periodic boundary condition, copy the channel upstream and downstream, using the appropriate
                            % elevation offset for Z values.
                            nodes_add = numel(centerline_retrieved.X)-1;
                            centerline_retrieved_periodic = replicate_centerline_periodic(centerline_retrieved,nodes_add); % Periodically copied version of centerline.
                            channelLookup.coords_all{h,1}=centerline_retrieved_periodic; % Enter the periodically copied channel centerline coordinates to the temporary cell array that stores all the queried channel coordinates.
                            [~,channelLookup.dist_channel_to_chkpt(:,h),channelLookup.normalized_dist_along_channel_all(:,h)] = ...
                                distance2curve([centerline_retrieved_periodic.X,centerline_retrieved_periodic.Y],chkpt.xy_fracind(chkpt.ind,1:2),'linear'); % Calculate and record the minimum Cartestian (x,y) distance from the periodically copied channel to each of the subset checkpoints. Also record the fractional distance of the nearest point along the longitudinal profile.
                        end

                        % For each checkpoint, find the latest iteration
                        % during which the checkpoint was located within
                        % the channel footprint. 
                        % For that condition to be true, the distance from the channel centerline to the checkpoint ("channelLookup.dist_channel_to_chkpt") must be less than the half-width of the channel.																																																																																
                        channelLookup.it_select = zeros(size(channelLookup.normalized_dist_along_channel_all,1),1); % Preallocate an array to store the iteration for the channel position used to calculate the bedrock elevation for each checkpoint.
                        chkpt.frac_ind_along_channel = zeros(size(channelLookup.normalized_dist_along_channel_all,1),1); % Preallocate an array to store the fractional index along the corresponding channel to use for each checkpoint.
                        for h=1:numel(chkpt.ind) % For each checkpoint
                            xx=find(channelLookup.dist_channel_to_chkpt(h,:)<=(w/2+1e-8),1,'last'); % Find the index of the element within channelLookup.dist_channel_to_chkpt that represents the latest channel posotin (i.e., "last" in list, since the list is iteration-ordered) with a distance to the checkpoint of less than half the channel width, allowing for a buffer value of 1e-8 for numerical precision issues.																																				  
                            if isempty(xx) % If no channel position is found that includes the checkpoint, then throw an error
                                err = 'Error (meander_vector.m/bank_composition_check): No longitudinal profile found for checkpoint - check handling of intersections along bank composition serach vector (variable xytihd_all)';
                                filename=[outputDir,'run_',trial,'_error_data.mat'];
                                save(filename)
                                error(err)
                            else
                                channelLookup.it_select(h) = xx; % If a point was found, then note the index that the iteration that correspond to that particular channel position 
                                channelLookup.normalized_dist_along_channel_selected = channelLookup.normalized_dist_along_channel_all(h,channelLookup.it_select(h)); %  array that stores, for the nearest point along the selected channel to the subset of checkpoints, its normalized distance along the channel
                                chkpt.frac_ind_along_channel(h) = ... % Interpolate to retrieve the fractional node index (along the channel) 
                                    interp1q((1:numel(channelLookup.coords_all{channelLookup.it_select(h)}.Z))'/numel(channelLookup.coords_all{channelLookup.it_select(h)}.Z),...
                                    (1:numel(channelLookup.coords_all{channelLookup.it_select(h)}.Z))',channelLookup.normalized_dist_along_channel_selected); 
                            end
                        end
                        scour_it = channelLookup.it_select; % set the scour iteration as the iteration that corresponds to the selected channel 

                        % Linearly interpolate along the selected channel to retrieve the bedrock elevation. For speed the interpolation is conducted in-line rather than calling interp1.																																																																																							
                        flr_ind=floor(chkpt.frac_ind_along_channel); % Floor of the fractional node index along the channel
                        ceil_ind=ceil(chkpt.frac_ind_along_channel); % Ceiling of the fractional node index along the channel
                        mod_ind=mod(chkpt.frac_ind_along_channel,1); % Modulus of the fractional node index along the channel and 1.
                        bdrk_elev=zeros(numel(channelLookup.it_select),1); % Preallocate an array to store the bedrock elevation for each checkpoint.
                        for h=1:numel(bdrk_elev) % For each point that needs a bedrock elevation assigned...
                            % Use linear interpolation to calculate the longitudinal profile elevation to assign to the checkpoint.																																																																													
                            bdrk_elev(h) = channelLookup.coords_all{channelLookup.it_select(h)}.Z(flr_ind(h)) + mod_ind(h)*diff(channelLookup.coords_all{channelLookup.it_select(h)}.Z([flr_ind(h) ceil_ind(h)]));																																																																		
                        end
                    else % poly_itStart_unique== 0 or 1 (The iteration that marks the voidpolygon or initial alluvial belt)
                        bdrk_elev=init_plane_max_elev-init_plane_slope*(chkpt.xy_fracind(chkpt.ind(:,1))-domain.xExtent(1)); % Calculate the bedrock elevation using the initial elevation of the planar surface with a correction for the downvalley (x-direction) slope.
                        scour_it = poly_itStart_unique(n);
                    end

                    chkpt.scour_it(chkpt.ind) = scour_it;
                    chkpt.bdrk(chkpt.ind) = bdrk_elev; % Assign the bedrock elevation to the appropriate index in chkpt.bdrk

                    % If there was an initial alluvial belt, then the bedrock elevation could be lower than the channel bed elevation at the iteration of scour. 
                    % For points within the initial alluvial belt, interpolate for the bedrock elevation along original alluvial belt polygon and use that bedrock elevation if it is lower than the bedrock elevation currently assigned to the checkpoint.																																																					
                    if init_alluv_width>0 % If the width of the initial alluvial belt is greater than zero... 
                        coords_xy=chkpt.xy_fracind(chkpt.ind,1:2); % Extract the (x,y) coordinates of the the checkpoints.
                        within_init_alluv_poly = and(coords_xy(:,2)>init_alluv_poly.ymin,coords_xy(:,2)<init_alluv_poly.ymax); % Create a logical array that stores whether or not the checkpoints are located within the bounds of the initial alluvial belt, which is rectangular.
                        % For a rectangular initial alluvial belt with a planar, sediment-bedrock interface in the subsurface,
                        % find the bedrock elevation from the x-distance along the initial alluvial belt.
                        bdrk_elev_orig = init_plane_max_elev-init_plane_slope*(coords_xy(:,1)-init_alluv_poly.xmin)-init_alluv_depth;
                        ind_replace = and(within_init_alluv_poly,bdrk_elev_orig<chkpt.bdrk(chkpt.ind)); % Indices of the checkpionts whose bedrock elevations should be replaced. These are the points within the initial alluvial belt and whose currently assigned bedrock elevations are above the bedrock elevation for the initial alluvial belt.
                        chkpt.bdrk(chkpt.ind(ind_replace))=bdrk_elev_orig(ind_replace); % Replace the bedrock elevations for the checkpoints.  
                    end																																											

                    % For cases in which bedrock modifies lateral
                    % erosion rate, run a preliminary check to determine whether
                    % the inspected checkpoints are sufficient to
                    % determine where lateral erosion should stop
                    % (i.e., cost >=1). This prevents unncessary lookup
                    % of bedrock elevations and scour iterations for more checkpoints. Note
                    % that this check does not occur in cases with
                    % overbank deposition enabled, and so in those
                    % cases the full list of checkpoints and scour iterations is looked up.
                    if bedrock_erosion.modify_lateral_erosion_bedrock 
                        % Determine the cost associated with lateral erosion between each checkpoint.																																																														
                        ind_end=find(isnan(chkpt.bdrk),1,'first'); % Identify the first NaN element of the vector that stores the bedrock elevation for each checkpoint and assign that as the endpoint for calcuating cost.
                        if ind_end>1 % If the detected endpoint is not the first element in the checkpoint bedrock elevation array, then proceed.
                            bdrk_elev=chkpt.bdrk(1:ind_end-1); % Extract the bedrock elevations from the checkpoint bedrock elevation array, up to the endpoint index.
                            dist_each_interval=diff([w/2;chkpt.d(1:ind_end-1)]); % Extract the distance from the channel centerline node to each checkpoint. The first point is at the distance of the cutbank (half the channel width).
                            % Find proportion of bank materials that are bedrock within in each interval between checkpoints.
                            proportion_bedrock = NaN(size(bdrk_elev)); % Initialize an array to store the proportion of bedrock.
                            ind = (bdrk_elev >= (centerline.Z(i) + D)); % If the sediment-bedrock interface elevation is greater than or equal to the channel bottom elevation plus the channel depth (the water surface)...
                                proportion_bedrock(ind) = 1; % Then the bank is all bedrock (i.e, proportion_bedrock equals 1 for those indices).
                            ind = (bdrk_elev < centerline.Z(i)); % If the sediment-bedrock interface elevation is below the channel bottom elevation...
                                proportion_bedrock(ind) = 0; % Then the bank is all sediment (i.e., proportion_bedrock equals 0 for those indices).
                            ind = isnan(proportion_bedrock); % Identify the indices with unassigned values for the proportion of bedrock..
                                proportion_bedrock(ind) = (bdrk_elev(ind) - centerline.Z(i))/D; % For these indices, the bank materials are partially bedrock and partially sediment. The proportion of bedrock is determined by differencing the assigned bedrock elevation and the current elevation of the channel centerline node. 																																																																															
                            k_erode_interval = k_erode_sediment*(1-proportion_bedrock)+k_erode_bedrock*proportion_bedrock; % "k_erode_interval" is the effective erodibility coefficent based on the erodibilities of bedrock and sediment and the proportion of bedrock in the bank materials.
                            cost = dist_each_interval./(k_erode_interval*(sqrt(x_increment(i)^2+y_increment(i)^2))); % The cost of moving through each interval between checkpoints is calculated as the distance in each interval divided by the erodibility of the bank materials in that interval multiplied by the magnitude of the lateral erosion increment determined for a 1 m/yr maximum lateral migration rate.
                            if sum(cost)>1 % If the sum of the cost is greater than 1, then there is no need to check the bedrock elevations for the remaining checkpoints, so break out of the for loop.
                                ind_end=find(isnan(chkpt.bdrk),1,'first'); % Then find the first NaN value in the list of checkpoint bedrock elevations.
                                chkpt.d(ind_end:end)=[]; % Remove the checkpoint distances after that index.
                                chkpt.bdrk(ind_end:end)=[]; % Remove the checkpoint bedrock elevations after that index.
                                break % Break out of the for loop.
                            end
                        end
                    end
                    dist_each_interval=diff([w/2;chkpt.d]); % The distance of each interval between each checkpoint is the difference of the checkpoint distances.
                    bdrk_elev=chkpt.bdrk; % The bedrock elevation used subsequently is the bedrock elevation of the checkpoints.
                end
            end
            
            if bedrock_erosion.modify_lateral_erosion_bedrock
                % Find proportion of bank materials that are bedrock within in each interval.
                proportion_bedrock = NaN(size(bdrk_elev)); % Initialize an array to store the proportion of bedrock.
                ind = (bdrk_elev >= (centerline.Z(i) + D)); % If the sediment-bedrock interface elevation is greater than or equal to the channel bottom elevation plus the channel depth (the water surface)...
                proportion_bedrock(ind) = 1; % Then the bank is all bedrock (i.e, proportion_bedrock equals 1 for those indices).
                ind = (bdrk_elev < centerline.Z(i)); % If the sediment-bedrock interface elevation is below the channel bottom elevation...
                proportion_bedrock(ind) = 0; % Then the bank is all sediment (i.e., proportion_bedrock equals 0 for those indices).
                ind = isnan(proportion_bedrock); % Identify the indices with unassigned values for the proportion of bedrock..
                proportion_bedrock(ind) = (bdrk_elev(ind) - centerline.Z(i))/D; % For these indices, the bank materials are partially bedrock and partially sediment. The proportion of bedrock is determined by differencing the assigned bedrock elevation and the current elevation of the channel centerline node. 																																																																															
                f_bedrock(i) = proportion_bedrock(1); % Record an output statistic: the fraction of bedrock in the bank materials at the cutbank (i.e., the location of the first checkpoint).
                k_erode_interval = k_erode_sediment*(1-proportion_bedrock)+k_erode_bedrock*proportion_bedrock; % "k_erode_interval" is the effective erodibility coefficent based on the erodibilities of bedrock and sediment and the proportion of bedrock in the bank materials.
            end            
            
            % If overbank deposition is enabled and channel migration rates adjust to bank height, 
            % then the bank height that accounts for overbank deposition needs to be calculated. The calculation is the same whether the channel longitudinal profile is flat or sloping. 																																																																																			
            if overbank_deposition.enable % If overbank deposition is enabled...
                if overbank_deposition.modify_lateral_erosion_bank_height
                    % use structure array "channelLookup" to gather variables associated with looking up past channel positions.
                    channelLookup.it_query = (min(chkpt.scour_it(chkpt.scour_it>0))+1):1:it-1; % For the past channel positions to query, change the iteration immediately following the scour iteration for the checkpoint, and up to the iteration just before the current one.
                    if any(chkpt.scour_it==0)
                        channelLookup.it_query = [1, channelLookup.it_query];
                    end
                    % Compute the distance from each checkpoint to all centerlines after the oldest checkpoint, as those are the iterations that could have contributed overbank sediment after the initial scour.
                    channelLookup.dist_channel_to_chkpt=zeros(numel(chkpt.scour_it),numel(channelLookup.it_query)); % Preallocate an array to store the distance from each checkpoint to the channel centerline for each iteration that could have contributed overbank sediment.
                    for h=1:numel(channelLookup.it_query) % For each longitidnal profile iteration to check...
                        centerline_retrieved = Data(channelLookup.it_query(h)).centerline; % Retrieve the channel centerline at that iteration from the data structure "Data."
                        % In keeping with the periodic boundary condition, copy the channel centerline coordinates (x,y,z) upstream and downstream, with appropriate
                        % elevation offset for the z-values.
                        nodes_add = numel(centerline_retrieved.X)-1;
                        centerline_retrieved_periodic = replicate_centerline_periodic(centerline_retrieved,nodes_add);
                        [~,channelLookup.dist_channel_to_chkpt(:,h),~] = distance2curve([centerline_retrieved_periodic.X,centerline_retrieved_periodic.Y],chkpt.xy_fracind(:,1:2),'linear'); % Calculate the distance in the xy-plane from each checkpoint coordinate to the past channel position and assign to one column of the array channelLookup.dist_channel_to_chkpt.
                    end

                    % For checkpoints that that have scour iteration after the latest iteration of the channel positions, assign a distance
                    % of infinity (Inf) to those channel positions -- because the spatially decaying component of the overbank deposition rate goes to zero for an infinitely distant channel, this sets the overbank deposition contribution to the checkpoint from the channel at those iteration to zero.
                    for h=1:numel(chkpt.ind) % For each element checkpoint array...
                        dist_row = channelLookup.dist_channel_to_chkpt(h,:); % Row vector of distance values from the checkpoint to the channel centerline position from each iteration.
                        dist_row(channelLookup.it_query<=chkpt.scour_it(h))=Inf; % Set the distance values to infinity for the channel position iterations that are after the scour iteration for this checkpoint.
                        channelLookup.dist_channel_to_chkpt(h,:)=dist_row; % Replace the distance values in the array "channelLookup.dist_channel_to_chkpt" with the updated values for this row.
                    end
                    channelLookup.dist_channel_to_chkpt=channelLookup.dist_channel_to_chkpt-w/2; % The distance to the past channel positions was calculated using the channel centerlines. To convert to the distance to the nearest channel bank, subtract half the channel width. 
                    init_elev= bdrk_elev+D; % The elevation without overbank deposition is the scour elevation plus the channel depth. This assumes point bar accretion to the channel depth and complete, instantaneous filling of cutoff loops.																																																																											
                    % Now calculate the final checkpoint elevation ("chkpt.elev") including the overbank sediment contribution.
                    % On the right-hand side of the equation that follows the terms are:
                    % Term 1: the initial elevation without the overbank sediment contribution.																																							
                    % Term 2: the elapsed time that this checkpoint has been in the floodplain times the constant (space-independent) deposition rate.
                    % Term 3: the time increment times the space-dependent deposition rate.
                    timeElapsed = t - Data(chkpt.scour_it).t+t_increment;
                    bank_elevs = init_elev + timeElapsed*nu + (t_increment*sum(mu_d*exp(-channelLookup.dist_channel_to_chkpt/lambda),2));
                    bank_height_ratio = D./(bank_elevs-centerline.Z(i)); % The ratio of the channel depth to the bank height, where bank height is the difference between the local surface elevation and the local elevation of the channel centerline.
                    k_erode_interval = k_erode_sediment*bank_height_ratio; % Adjust the erodibility of this interval according to the bank height ratio.
                end

                if overbank_deposition.modify_lateral_erosion_resistant_oxbows
                    % check if point belonged to an oxbow >3w from channel
                    if isempty(chkpt.scour_it) % All bank-material polygons related to the channel position have an associated iteration. So if 'chkpt.scour_it' is empty, the checkpoints did not overlap with any polygons.
                        k_erode_interval=k_erode_sediment; % In this case, the erosion rate coefficient is just k_erode_sediment
                    else
                        use_harder_k_erode=false(size(chkpt.scour_it)); % outside channel influence (cutoff is within 3*w, after Howard, 1996)
                        oxbow_frac_coeff=zeros(size(chkpt.scour_it)); 
                        for vv=1:numel(chkpt.scour_it)
                            % cutoff happens in the subsequent iteration
                            % check that iteration
                            if chkpt.scour_it(vv)==0
                                in_oxbow=false;
                            elseif isnan(chkpt.scour_it(vv))
                                err = 'Error (meander_vector.m/bank_composition_check): NaN found in scour iteration';
                                filename=[outputDir,'run_',trial,'_error_data.mat'];
                                save(filename)
                                error(err)
                            else
                                if ~cutoff_interp_stats.cutoff_log(chkpt.scour_it(vv)+1) % i.e., if there was no cutoff in the next iteration
                                  in_oxbow=false;
                                else % Then there was a cutoff. check if the recorded distance along the associated channel position that the checkpoint was within the footprint of the cutoff.
                                    if any(and(chkpt.frac_ind_along_channel(vv)>cutoff_interp_stats.nodes_removed_ranges{chkpt.scour_it(vv)+1}(:,1),chkpt.frac_ind_along_channel(vv)<cutoff_interp_stats.nodes_removed_ranges{chkpt.scour_it(vv)+1}(:,2)))
                                      in_oxbow=true;
                                    else
                                      in_oxbow=false;
                                    end
                                end
                            end
                            if in_oxbow % Check if the checkpoint was beyond the e-folding distance for coarse sediment deposition (overbank_deposition.parameters.lambda), measured from the channel centerline (which adds an additional length of half the channel width). If so, then assume that the channel filled with resistant, fine-grained sediments.
                                old_centerline = Data(chkpt.scour_it(vv)+1).centerline; % again, checking distance to the *next* iteration's centerline
                                % copy long profile upstream and downstream, with appropriate
                                % elevation offset
                                nodes_add = numel(old_centerline.X)-1;
                                [old_centerline_periodic] = replicate_centerline_periodic(old_centerline,nodes_add);
                                [~,channelLookup.dist_channel_to_chkpt,frac_ind] = distance2curve([old_centerline_periodic.X,old_centerline_periodic.Y],chkpt.xy_fracind(vv,1:2),'linear');
                                current_local_channel_bed_elev = centerline.Z(i);
                                if channelLookup.dist_channel_to_chkpt > (overbank_deposition.parameters.lambda + w/2) 
                                    use_harder_k_erode(vv)=true;
                                    oxbow_floor_elev=interp1((1:numel(old_centerline_periodic.Z))'/numel(old_centerline_periodic.Z),old_centerline+periodic.Z,frac_ind);
                                    if oxbow_floor_elev >= current_local_channel_bed_elev % if the oxbow scour elevation is greater than or equal to the current local centerline elevation, then treat the bank as fully oxbow-fill.
                                        oxbow_frac_coeff(vv)=1;
                                    elseif (oxbow_floor_elev+D) < current_local_channel_bed_elev % if the oxbow scour elevation plus the channel depth is below the current local centerline elevation, then bank has no oxbow-fill.
                                        oxbow_frac_coeff(vv) = 0; 
                                    else % then the bank materials include some oxbow-fill and some non-oxbow fill. This assumes centerline.Z(i) > oxbow_floor_elev
                                        oxbow_frac_coeff(vv) = ((oxbow_floor_elev+D)-current_local_channel_bed_elev)/D; % Set the erodibility based on the proportion of bank (from channel bottom to bank full) that is oxbow-fill.
                                    end
                                end
                            end
                        end
                      k_erode_interval=repmat_lightspeed(k_erode_sediment,numel(chkpt.scour_it),1);
                      k_erode_interval(use_harder_k_erode)=oxbow_frac_coeff(use_harder_k_erode)*oxbow_erode_coeff*k_erode_sediment;
                      k_erode_interval(oxbow_frac_coeff==0)=k_erode_sediment;
                      f_oxbow(i) = oxbow_frac_coeff(1);
                    end
                end
            end
            
            % If no process to modify lateral erosion rates is set, then
            % set the erodibility of all intervals to the sediment
            % erodibility.
            if ~bedrock_erosion.modify_lateral_erosion_bedrock && ~overbank_deposition.modify_lateral_erosion_bank_height && ~overbank_deposition.modify_lateral_erosion_resistant_oxbows
                k_erode_interval = repmat(k_erode_sediment,numel(dist_each_interval),1);
            end

			% The cost of moving through each interval between checkpoints is calculated as the distance in each interval divided by the erodibility of the bank materials in that interval multiplied by the magnitude of the lateral erosion increment determined for a 1 m/yr maximum lateral migration rate.
            cost = dist_each_interval./(k_erode_interval*(sqrt(x_increment(i)^2+y_increment(i)^2))); 

			% For very small distance intervals, numerical precision limits can result in erroenous cost calculations. 
			% This condition sets the cost to infinity for the last interval if the total length of the intervals is less than a threshold (1 micron).
            if sum(dist_each_interval)<1e-6 
                cost(end)=Inf; 
            end

		    % Check for errors in the cost vector (i.e., if the sum of the cost is less than 1, or if the length of the cost vector does not match the length of the vector of distance in each interval).
            if or(lt(sum(cost),1),ne(numel(cost),numel(dist_each_interval)))																																																																													
	           % These errors can occur for very small movement increments, due to numerical precision limits. Check if the maximum migration distance, multiplied over the timeframe of the simulation, would give a total erosion distance greater than a threshold (10 cm). 
			   % If not, then as a workaround set the cost to infinite. 
				if (endpt_dist-w/2)*(t_max/t_increment) < 0.1 
                    cost=Inf;
                    dist_each_interval=1;
                else % Otherwise, throw an error. 
                    err = 'Error (meander_vector.m/bank_composition_check): Bank composition check failed';
                    filename=[outputDir,'run_',trial,'_error_data.mat'];
                    save(filename)
                    error(err)
                end
            end
			% Determine the movement increment such that the cost sums to 1. This implementation is faster than interpolation using interp1.m. 																																																																																				
            cost = [0;cumsum(cost)]; % Convert "cost" to the cumulative cost along the search vector.
            dist=[0;cumsum(dist_each_interval)]; % Convert "dist_each_interval" to the cumulative distance along the search vector.																																																																																		
            ind_cost_gt1 = find(cost>1,1,'first'); % Find the index for which the cumulative cost first exceeds 1.
            add_ratio = (1-cost(ind_cost_gt1-1))/(cost(ind_cost_gt1)-cost(ind_cost_gt1-1)); % This is the fractional index between elements in the distance vector that is needed in order to reach cost == 1.
            move_dist(i) = dist(ind_cost_gt1-1)+add_ratio*(dist(ind_cost_gt1)-dist(ind_cost_gt1-1)); % This is the distance to move the channel centerline nodesuch that cost == 1.     
            if isnan(move_dist(i)) % If NaN was calculated for the movement distance ("move_dist"), then throw an error.
				err = 'Error (meander_vector.m/bank_composition_check): NaN calculated for node movement distance.';
                filename=[outputDir,'run_',trial,'_error_data.mat'];
                save(filename)
                error(err)
            end
        end
    
        function [xytihd_temp]=locate_polygon_intersections
            % locate_polygon_intersections: Nested function (inside bank_composition_check) 
            % to identify where the bank migration search vector intersects
            % the edges of bank-material polygons.

            % Use logical operations to discard polygons that are not within the possible move distance of the cutbank, allowing for a search buffer with x- and y-components. Use the bounding box for each bank material subpolygon.
            if search_buffer_x(i)>=0 % If the x-component of the the search buffer is non-negative...
                d1 = subpolygon_bounding_boxes(:,1) > X_cutbank(i)+search_buffer_x(i); % "d1" is a logical array; records if the left edge of each subpolygon is rightward of maximum rightward move position of the cutbank node.
                d2 = subpolygon_bounding_boxes(:,2) < X_cutbank(i); % "d2" is a logical array; records if the right edge of each subpolygon is leftward of cutbank (which can only move rightward in this case).
            else % i.e., the x-component of the the search buffer is negative...
                d1 = subpolygon_bounding_boxes(:,1) > X_cutbank(i); % "d1" is a logical array; records if the left edge of the subpolygon is rightward of cutbank (which can only move further left in this case).
                d2 = subpolygon_bounding_boxes(:,2) < X_cutbank(i)+search_buffer_x(i); % "d2" is a logical array; records if the right edge of each subpolygon is leftward of the maximum leftward move position of the cutbank.
            end

            if search_buffer_y(i)>=0 % If the y-component of the the search buffer is non-negative...
                d3 = subpolygon_bounding_boxes(:,3) > Y_cutbank(i)+search_buffer_y(i); % "d3" is a logical array; records if the bottom edge of each subpolygon is above the maximum upward move position of the cutbank.
                d4 = subpolygon_bounding_boxes(:,4) < Y_cutbank(i); % "d4" is a logical array; records if the bottom edge of each subpolygon is below the cutbank position (which can only move higher in this case).
            else % i.e., the y-component of the the search buffer is negative...
                d3 = subpolygon_bounding_boxes(:,3) > Y_cutbank(i); % "d3" is a logical array; records if the bottom edge of each subpolygon is above the cutbank (which can only move further down in this case).
                d4 = subpolygon_bounding_boxes(:,4) < Y_cutbank(i)+search_buffer_y(i); % "d4" is a logical array; records if the top edge of each subpolygon is below the maximum downward move position of the cutbank.
            end

            discard_spatial = (d1+d2+d3+d4)>0; % This vector is true if any of the conditions (d1,d2,d3,d4) is true.
            % Take a subset of bank-material subpolygons, discarding others using the logical array "discard_spatial." Save the subset of subpolygons to the data structure "poly_subset."
            poly_subset.poly_vert_split_cell = poly_master.poly_vert_split_cell(~discard_spatial);
            poly_subset.itStart = poly_master.itStart(~discard_spatial); % Subset of subpolygon initiation iterations.
            poly_subset.hole = poly_master.hole(~discard_spatial); % Subset of subpolygon hole flags.
            poly_subset.poly_index = poly_master.poly_index(~discard_spatial); % Subset of subpolygon identifier indices.
            poly_subset.numel = poly_master.numel(~discard_spatial); % Subset of subpolygon element counts.
            poly_ind_bins = 1+[0;cumsum(poly_subset.numel)]; % This vector holds the bin edges for the elements of all the subpolygons (i.e., when all of the subpolygon points are put in a single array, this vector indicates how to select the elements that belong to a single subpolygon by supplying the bin edges). 

            % Select a spatial subset of the void polygons as well.
            if search_buffer_x(i)>=0 % If the x-component of the the search buffer is non-negative...
                d1 = voidpoly_bounding_boxes(:,1) > X_cutbank(i)+search_buffer_x(i); % "d1" is a logical array; records if the left edge of each subpolygon is rightward of maximum rightward move position of the cutbank node.
                d2 = voidpoly_bounding_boxes(:,2) < X_cutbank(i); % "d2" is a logical array; records if the right edge of each subpolygon is leftward of cutbank (which can only move rightward in this case).
            else % i.e., the x-component of the the search buffer is negative...
                d1 = voidpoly_bounding_boxes(:,1) > X_cutbank(i); % "d1" is a logical array; records if the left edge of the subpolygon is rightward of cutbank (which can only move further left in this case).
                d2 = voidpoly_bounding_boxes(:,2) < X_cutbank(i)+search_buffer_x(i); % "d2" is a logical array; records if the right edge of each subpolygon is leftward of the maximum leftward move position of the cutbank.
            end

            if search_buffer_y(i)>=0 % If the y-component of the the search buffer is non-negative...
                d3 = voidpoly_bounding_boxes(:,3) > Y_cutbank(i)+search_buffer_y(i); % "d3" is a logical array; records if the bottom edge of each subpolygon is above the maximum upward move position of the cutbank.
                d4 = voidpoly_bounding_boxes(:,4) < Y_cutbank(i); % "d4" is a logical array; records if the bottom edge of each subpolygon is below the cutbank position (which can only move higher in this case).
            else % i.e., the y-component of the the search buffer is negative...
                d3 = voidpoly_bounding_boxes(:,3) > Y_cutbank(i); % "d3" is a logical array; records if the bottom edge of each subpolygon is above the cutbank (which can only move further down in this case).
                d4 = voidpoly_bounding_boxes(:,4) < Y_cutbank(i)+search_buffer_y(i); % "d4" is a logical array; records if the top edge of each subpolygon is below the maximum downward move position of the cutbank.
            end
            discard_ind = (d1+d2+d3+d4)>0; % % This vector is true if any of the conditions (d1,d2,d3,d4) is true.
            polygon_vert_nrows = sum(poly_subset.numel); % The total number of vertices in void polygons.
            % Combine the subset lists of bank-material subpolygon vertices and void polygon vertices in a single numeric array. This is done to reduce the number of calls to the function that looks for polygon intersetions.																																																																																				
            poly_voidpoly_subset_vert_numeric = cell2mat([poly_subset.poly_vert_split_cell;voidpoly_master.voidpoly_vert_cell(~discard_ind)]); 

            % Find intersections between the bank-material search vector and the existing polygons within search window.
            if isempty(poly_voidpoly_subset_vert_numeric) % If the list of polygon vertices is not empty...
                if ~ind_exceed_extent(i) % That should only occur if the search vector extends beyond the x-extent. So if the search vector does not exceed the x-extent, then throw an error.
                    err = 'Error (meander_vector.m/bank_composition_check/locate_polygon_intersections): no intersections detected despite search vector within domain x-extent';
                    filename=[outputDir,'run_',trial,'_error_data.mat'];
                    save(filename)
                    error(err)
                end
                xytihd_temp=[]; % The temporary list of intersection coordinates and attributes is set to empty.
            else % i.e., if the spatial subset of polygons was not empty, then proceed to look for intersections with the search vector.
                [xo_temp,yo_temp,~,int_ind]=my_intersections(... % Outputs: (x,y) coordinates of intersections, and the scalar index of the intersection point within the polygon array.																																																																																			
                [centerline_periodic.X(i); X_cutbank_max_move(i)+1e-8],[centerline_periodic.Y(i);Y_cutbank_max_move(i)],... % x- and y- components of the search vector from the cutbank to the point of maximum movement.
                poly_voidpoly_subset_vert_numeric(:,1),poly_voidpoly_subset_vert_numeric(:,2),true); % The first two arguments in this line are the x- and y- components of the polygons.
                % Note: the intersections function has trouble with the polygons that coincide with the cutbank. Therefore, the 1e-8 deviation added to the x-component of the search vector is to prevent the search vector from going exactly through a vertex of the current polygon initiated at iteration it = current_poly_itStart.
                int_ind=floor(int_ind); % Round down the intersection index, as it can be fractional. 
                remove_int_ind=or(isnan(int_ind),isinf(int_ind)); % Flag any intersections for removal for which the intersection index came back as NaN or infinite.
                xo_temp(remove_int_ind)=[]; % Remove the flagged intersections from the intersection x-coordiantes.
                yo_temp(remove_int_ind)=[]; % Remove the flagged intersections from the intersection y-coordiantes.
                int_ind(remove_int_ind)=[]; % Remove the flagged intersections from the intersection indices.
                poly_rows = int_ind<=polygon_vert_nrows; % Identify the intersectios that correspond to bank-material polygons as those with intersection indices less than the number of vertices in the bank-material polygon array.
                xo=xo_temp(poly_rows); % Select the x-coordinates of bank-material polygon intersections.
                yo=yo_temp(poly_rows); % Select the y-coordinates of bank-material polygon intersections.
                xo_void=xo_temp(~poly_rows); % The other intersections (~poly_rows) correspond to void polygon intersections. These are the x-coordiantes of void polygon intersections.
                yo_void=yo_temp(~poly_rows); % The y-coordiantes of void polygon intersections.

                % For the bank-material polygon intersections, map the intersection index to the corresponding cell of "poly_subset".
                [~,bin]=histc(int_ind(poly_rows),poly_ind_bins); % int_ind(poly_rows) is the index of the submitted polygons. The result "bin" indicates the corresponding cell of "poly_subset".
                index=poly_subset.poly_index(bin); % This index is the unique bank-material polygon index, and will be added to the array that gathers intersection coordinates and their attributes.

                if ~isempty(xo) % If bank-material polygon intersections were detected...
                    xytih = [xo,yo,poly_master.itStart(index),index,poly_master.hole(index)]; % Gather in an array: the x- and y- coordinates of the intersections, the intersected subpolygon iteration of initiation, the intersected subpolygon index, and the flag for whether or not the subpolygon is a hole. All of these attributes are used for sorting the intersections.
                else
                    xytih=[]; % If no bank-material polygons were intersected, then set this intersection attribute array to empty.
                end

                % Assign -9999 as a placeholder, "NoData" index for all void polygon intersections. Don't assign an a meaningful index to voidpolygon because no such index is needed for intersection sorting. 
                % Also assign -9999 as a placeholder hole flag.
                if ~isempty(xo_void) % If there were intersections with void polygons...
                    temp=size(xo_void); % Get the size of the intersections vector.
                    xytih_void = [xo_void,yo_void,zeros(temp),-9999*ones(temp),-9999*ones(temp)]; % Gather in an array: the x- and y-coordinates of the void polygon intersection, a iteration of 0 (which is assigned by default void polygon intersections), and the placeholder values for the void polygon index and hole flag.
                else
                    xytih_void=[]; % If no intersections with void polygons were detected, then set this intersetion attribute array to empty.
                end
                xytih_all = [xytih;xytih_void]; % Combine the intersection attribute arrays from bank-material subpolygon intersections and void polygon intersections.

                if ~ind_exceed_extent(i) && isempty(xytih_all) % If the search vector does not exceed the domain x-extent and the combined intersections attribute array is empty (this can happen if lumping is enabled if the cutbank point is interior to the boundary of the current bank-material polygon)...
                    xytih_all = [X_cutbank(i) Y_cutbank(i) current_poly_itStart NaN false]; % Add an intersection at the cutbank with the iteration of initiaton for the current polygon with  "current_poly_itStart". Set the subpolygon index to NaN and the hole flag to false.
                end

                if ~isempty(xytih_all) % If the intersections attribute array is not empty...
                    % Make sure dealing only with unique intersections - remove duplicates that are sometimes returned by intersections function.																																																																															
                    dist_ctrline_checkpoints = sqrt((xytih_all(:,1)-centerline_periodic.X(i)).^2+(xytih_all(:,2)-centerline_periodic.Y(i)).^2); % The euclidean distance from the centerline node to each of the intersections.
                    dist_ctrline_checkpoints = round(1e8*dist_ctrline_checkpoints)/(1e8); % Round the distances to 1e-8, for numerical precision issues.
                    xytihd_temp = [xytih_all,dist_ctrline_checkpoints]; % Add the distance vector the intersections attribute array.
                    % Identify duplicates.
                    [m,~]=size(xytihd_temp);
                    thresh=1e-7; % Threshold for differentiating the distances, chosen as 1e-7 because the distances were rounded to 1e-8.
                    if m>1 % If the number of rows of the intersections attribute array is greater than 1...
                        duplicate_rows=[false;sum(abs(diff(xytihd_temp(:,[4 6]),1))<thresh,2)==2]; % Difference the subpolygon index and distance for all the point. If the differences are less than the threshold "thresh," then the "duplicate_rows" array will be true. "False" is a placeholder for the intersection in first row, which is by definition not a duplicate.
                        xytihd_temp(duplicate_rows,:)=[]; % Remove rows for duplicate points from the intersections attribute array.
                    end                        
                end
                if  ~isempty(xytih_all) && ~isempty(xytihd_temp) % If the original intersections attribute array wasn't empty, and the final intersections attribute array isn't empty, then last step is to replace any NaN values with a numeric NoData value, -9999, so that the final check for unique rows works properly (it fails with NaN array elements).
                    ind=isnan(xytihd_temp); % Identify NaN indices in the intersections attribute array.
                    xytihd_temp(ind)=-9999; % Replace NaN values with -9999 as a NoData value.
                    xytihd_temp=unique(xytihd_temp,'rows'); % Select unique rows of the intersections attribute array.
                    xytihd_temp(xytihd_temp==-9999)=NaN; % convert the -9999 values back to NaN.                     
                else
                    xytihd_temp=[]; % Otherwise, set the intersections attribute array to empty.
                end
            end
        end % End double-nested function locate_polygon_intersections.
    end  % End of nested function bank_composition check.   
end % End of main function.