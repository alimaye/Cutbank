function export_grids_movie(modelParameterFile,exportParameterFile)
% export_grids_movie.m: generates grids and/or movies. Grids correspond to 
% surface topography, bedrock topography, and surface scour time for model 
% data using the time-series of channel planform traces and longtiudinal profile, and  
% and geometry for the initial alluvial-belt, if any. Movie export 
% generates a movie file and associated movie frames.
% Input arguments:
%   modelParameterFile: name of file with model parameters
%   exportParameterFile: name of file with parameters for exporting grids
%   and/or movies.
% Output arguments:
%   None

    % Load selected model parameters
    load(modelParameterFile,'inputs')
    
    t_increment = inputs.t_increment;
    bed_elev_chg_rate = inputs.bed_elev_chg_rate;
    vertical_incision_style = inputs.vertical_incision_style;
    w = inputs.w;
    D = inputs.D;
    domain.xExtentChannelWidths = inputs.domain.xExtentChannelWidths;
    init_plane_max_elev = inputs.init_plane_max_elev;
    init_plane_slope = inputs.init_plane_slope;
    BMT = inputs.BMT;
    overbank_deposition = inputs.overbank_deposition;
    trial = inputs.trial;
    outputDir = inputs.outputDir;
    
    % Load export parameters
    load(exportParameterFile,'exportParameters')
    
    % Load model data    
    load(exportParameters.modelDataFile,'Data')

    switch BMT
        case {'channel-only', 'grid-based'}
            run_VBBMT = false;
        case 'vector-based'
            run_VBBMT = true;
    end

    % If vector-based bank-material tracking was used during the model run,
    % also load the geometry of the model domain and the initial alluvial-belt.
    if run_VBBMT
        load(exportParameters.modelDataFile,'init_alluv_poly')
    end
    
    load(exportParameters.modelDataFile,'init_alluv_width','init_alluv_depth','domain')
    
    % Create directories for file export
    if exportParameters.grid.export
        exportParameters.grid.dir = [outputDir,'grids\'];
        mkdir(exportParameters.grid.dir) % Grids
    end
    
    if exportParameters.movie.export
        exportParameters.movie.frame_dir = [outputDir,'movieFrames'];
        mkdir(exportParameters.movie.frame_dir) % Movie frames
    end
    
    if exportParameters.movie.plot_terraces
        exportParameters.terrace_mapping.dir = [outputDir,'terraceMaps\'];
        mkdir(exportParameters.terrace_mapping.dir) % Terrace mapping files
    end

    % Extract parameters from overbank deposition structure
    nu = overbank_deposition.parameters.nu;
    mu_d = overbank_deposition.parameters.mu_d;
    lambda = overbank_deposition.parameters.lambda;

    cell_width = exportParameters.grid.cell_width;
    t_max_model_run = max(cell2mat({Data(:).t})); % maximum time
    
    if exportParameters.grid.export
        exportParameters.grid.times = [0:exportParameters.grid.export_interval_yr:(t_max_model_run-exportParameters.grid.export_interval_yr),t_max_model_run]';
    else
        exportParameters.grid.times = [];
    end
    
    if exportParameters.movie.export
        exportParameters.movie.times = [0:exportParameters.movie.frame_interval_yr:(t_max_model_run-exportParameters.movie.frame_interval_yr),t_max_model_run]';
        frame_number = 1; % Initialize movie frame number.
        colors = [1 1 0;...
             0.13 0.55 0.13]; % yellow,forest green - color scheme used for terrace mapping
        %%%fh = figure('visible','off'); % initialize figure handle (called in parent and nested function)
        fh = figure; % initialize figure handle (called in parent and nested function). Movie export requires fixed figure size, so set option to prevent resizing.
    else
        exportParameters.movie.times = [];
    end
    
    switch exportParameters.movie.format
        case 'MPEG-4'
            % Create video file
            % See VideoWriter help for additional properties
            v = VideoWriter([exportParameters.outputDir,exportParameters.movie.name],...
                exportParameters.movie.format); % Create video object v with the given save name
            v.FrameRate = exportParameters.movie.fps; % Set the frames per second of the video
            %v.Quality = 100;            % Set the video quality (%)
            open(v)     
        case 'GIF'
            % setup occurs after the figure is made, so create this logical
            % flag that is used below for flow control involving the
            % function gif.m
            GIF_initialized = false;
    end
    
    
    if ~and(isempty(exportParameters.grid.times),isempty(exportParameters.movie.times))
        t_max = max([exportParameters.grid.times(:); exportParameters.movie.times(:)]); % Maximum time to proceed with gridding/movie frame export
    else
        t_max = t_max_model_run;
    end
    last_percent_complete=0; 
    axis_handles = []; % Initializes variable to pass axis handles to and from nested function that makes movie frames
             
    % Determine the needed grid y-extent using the extents of all channel centerlines, and by an additional buffer of the channel width.
    buffer=w/2; % Use half-channel width as buffer
    ymin=Inf;
    ymax=-Inf;
    for i1=1:numel(Data)
        y=Data(i1).centerline.Y;
        ymin_temp=min(y);
        ymax_temp=max(y);
        if ymin_temp<ymin
            ymin=ymin_temp;
        end
        if ymax_temp>ymax
            ymax=ymax_temp;
        end
    end
    
    domain.xExtent = [0 domain.xExtentChannelWidths*w];
    ymin=ymin-buffer;
    ymax=ymax+buffer;
    xmin=domain.xExtent(1)-buffer;
    xmax=domain.xExtent(2)+buffer;
    clear bb_all
    
    % Create a grid of (x,y) values using the minimum and maximum x and y
    % values and the cell width.
    [grid.x,grid.y]=meshgrid(xmin:cell_width:xmax,ymax:-cell_width:ymin); % Creates grids x-coordinates and y-coordinates (m)
    [nrows,ncols]=size(grid.x); % Extract size of grid (used for export).
    grid.z= (init_plane_max_elev*ones(size(grid.x))) - init_plane_slope*grid.x; % Grid of surface elevations (m)    
    grid.t= zeros(size(grid.x)); % Grid of time of last surface scour by channel (years). Initialize with t = 0.
    
    % Create the grid of bedrock elevations. Initialize it with the surface
    % elevations, then lower the bedrock elevation for all points within
    % the initial alluvial belt by an amount corresponding to the initial
    % depth of alluvium there.
    grid.z_bdrk=grid.z;
    if init_alluv_width>0
        [in,on]=inpoly([grid.x(:),grid.y(:)],[init_alluv_poly.x(:),init_alluv_poly.y(:)]); % % Find grid cells within initial alluvial belt.
        grid.z_bdrk(or(in,on))=grid.z_bdrk(or(in,on))-init_alluv_depth; % Calculate the bedrock elevation for those grid cells.
    else
        if ~isnan(init_alluv_depth)
            grid.z_bdrk = grid.z - init_alluv_depth; % Grid of bedrock surface elevations (m)
        end
    end
    
    % Record the bedrock elevation within the initial alluvial belt so that the
    % subsequent calculated bedrock elevations can be corrected if they are
    % above the initial bedrock scour surface.
    grid.z_bdrk_orig=grid.z_bdrk; 
    
    % Reshape the grids as Nx1 vectors, which are simpler to query and
    % update.
    grid.x=grid.x(:); 
    grid.y=grid.y(:);
    grid.t=grid.t(:);
    grid.z=grid.z(:);  
    grid.z_bdrk = grid.z_bdrk(:);
    grid.z_bdrk_orig=grid.z_bdrk_orig(:); 
    
    % Update grid using time-series of channel extents and longitudinal
    % profiles.
    for i1=1:numel(Data) % have to go youngest to oldest here, so proceed in order of elements in 'Data'
        t = Data(i1).t;
        centerline = Data(i1).centerline;

        % Create channel footprint polygon and periodically replicated
        % centerline
        nodes_add = numel(centerline.X)-1;
        [centerline_periodic] = replicate_centerline_periodic(centerline,nodes_add);
        channel_poly = create_polygon(centerline_periodic,w,domain);
        
        %%% Note: a more conservative test for grid cell containment within
        %%% the channel is used in meander_gridded.m.
        % Points-in-polygon test for grid points. Don't have to loop over
        % elements of newpoly because not clipping by domain corners
        in_channel_this_timestep = false(size(grid.x));
        for q=1:numel(channel_poly)
            [in,on]=inpoly([grid.x,grid.y],[channel_poly(q).x,channel_poly(q).y]);
            in_channel_this_timestep(or(in,on)) = true;
        end
                
        if i1==1
            in_channel_last_timestep = in_channel_this_timestep;
        end
        
        % Update surface and bedrock elevation grids based on the style of
        % vertical incision.
        switch vertical_incision_style
            case {'flat_steady','flat_unsteady'}
                channel_bed_elev = centerline.Z(1);
            case {'sloping_steady','shear_stress'}
                [~,~,frac_dist] = distance2curve([centerline_periodic.X,centerline_periodic.Y],[grid.x(in_channel_this_timestep),grid.y(in_channel_this_timestep)],'linear');
                frac_ind = interp1q((1:numel(centerline_periodic.Z))'/numel(centerline_periodic.Z),(1:numel(centerline_periodic.Z))',frac_dist);
                flr_frac_ind=floor(frac_ind);
                ceil_frac_ind=ceil(frac_ind);
                mod_frac_ind=mod(frac_ind,1);
                % get the long profile elevation for this timestep at the proper location
                channel_bed_elev = centerline_periodic.Z(flr_frac_ind)+ mod_frac_ind*(centerline_periodic.Z(ceil_frac_ind)-centerline_periodic.Z(flr_frac_ind));
        end
        
        % Add overbank sediment to the surface elevation grid if overbank depostion was enabled during the model run.
        if overbank_deposition.enable
            [~,dist_to_lp,~] = distance2curve([centerline_periodic.X(:),centerline_periodic.Y(:)],[grid.x,grid.y],'linear');
            grid.z = grid.z + t_increment*(nu + mu_d*exp(-dist_to_lp/lambda)); % The second term is the overbank sediment deposited in this time step.
        end
        
        ind_abandoned = and(in_channel_last_timestep,~in_channel_this_timestep);
        % Update grids of surface elevation, bedrock elevation, and time of surface scour
        grid.z_bdrk(in_channel_this_timestep)=channel_bed_elev;
        grid.z(in_channel_this_timestep) = grid.z_bdrk(in_channel_this_timestep);
        grid.z(ind_abandoned) = grid.z(ind_abandoned) + D;
        grid.t(in_channel_this_timestep)=t;
        in_channel_last_timestep = in_channel_this_timestep; % Reset for next iteration
        
        % check that never raise the bedrock-sediment interface (it
        % can only be lowered - i.e., channel bottom only resets
        % the bedrock-sediment interface if it is lowering it)
        ind_restore = grid.z_bdrk > grid.z_bdrk_orig;
        grid.z_bdrk(ind_restore)=grid.z_bdrk_orig(ind_restore);
        
        % Export grids if the current time step is one of the specified
        % output time steps.
        if or(ismember(t,exportParameters.grid.times),ismember(t,exportParameters.movie.times))
            dem.x=reshape(grid.x,nrows,ncols);
            dem.y=reshape(grid.y,nrows,ncols);
            dem.z=reshape(grid.z,nrows,ncols);
            dem.z_bedrock = reshape(grid.z_bdrk,nrows,ncols);
            dem.t = reshape(grid.t,nrows,ncols);
            dem.cell_width = cell_width;
            
            % calculate fraction of bedrock in bank materials
            dem.f_bedrock = NaN(size(dem.z_bedrock)); % Initialize an array to store the proportion of bedrock.
            % For each grid cell, find the nearest point on the channel and
            % retrieve its elevation.
            [~,~,centerline_dist_frac] = distance2curve([centerline_periodic.X,centerline_periodic.Y],[dem.x(:),dem.y(:)],'linear');            
            nearest_channel_bed_elev = interp1(linspace(0,1,numel(centerline_periodic.Z))',centerline_periodic.Z,centerline_dist_frac);
            nearest_channel_bed_elev = reshape(nearest_channel_bed_elev,nrows,ncols); % To query nearest channel bed elevation as a map
            ind = (dem.z_bedrock >= (nearest_channel_bed_elev + D)); % If the sediment-bedrock interface elevation is greater than or equal to the channel bottom elevation plus the channel depth (the water surface)...
            dem.f_bedrock(ind) = 1; % Then the bank is all bedrock (i.e, proportion_bedrock equals 1 for those indices).
            ind = (dem.z_bedrock < nearest_channel_bed_elev); % If the sediment-bedrock interface elevation is below the channel bottom elevation...
            dem.f_bedrock(ind) = 0; % Then the bank is all sediment (i.e., proportion_bedrock equals 0 for those indices).
            ind = isnan(dem.f_bedrock); % Identify the indices with unassigned values for the proportion of bedrock.
            dem.f_bedrock(ind) = (dem.z_bedrock(ind) - nearest_channel_bed_elev(ind))/D; % For these indices, the bank materials are partially bedrock and partially sediment. The proportion of bedrock is determined by differencing the assigned bedrock elevation and the current elevation of the channel centerline node. 																																																																															
        end
        
        if ismember(t,exportParameters.grid.times)
            output_filename = [exportParameters.grid.dir,'trial_',trial,'_t_',num2str(t),'_gridded.mat'];
            save(output_filename,'dem','trial','t')
        end
        
        if  ismember(t,exportParameters.movie.times) % Then make movie frame
            [axis_handles] = export_movie_frame(axis_handles); % Calls nested function to export a movie frame
            frame_number=frame_number+1; % Update movie frame number
        end

        % Display progress.
        percent_complete = floor((t/t_max)*100);
        percent_increment=5;
        if percent_complete > (last_percent_complete+(percent_increment-1))
            fprintf('Run %s, %d percent complete\n',trial,percent_complete)
            last_percent_complete = percent_complete;    
        end

    end % End of time loop
    
    if exportParameters.movie.export
        close(fh) % Close any figure windows generated from movie export 
    end
    fprintf('Finished file export for run %s \n',trial);

    % Nested function
    function[axis_handles] = export_movie_frame(axis_handles)
    % export_movie_frame.m: Generates still images for a movie of a model run.
    % The images include a shaded relief map, a topographic cross section, and
    % optionally terraces and the time-series of bed elevation change rate.
        % set figure parameters   
        if frame_number==1
            set(gcf,'renderer','painters') 
            set(gcf,'color','w')
            desired_width=exportParameters.movie.image_width_cm; % centimeters
            set(gcf,'Units','centimeters','outerposition',[0 0 desired_width desired_width]) % this way scales for proper height, but width is set
            set(gcf,'PaperPositionMode','auto')
            set(gcf, 'PaperUnits', 'centimeters');
            siz=get(gcf,'position');
            siz=siz(3:4); % just get width and height
            set(gcf, 'PaperSize', siz)
            
            % Create subplot axes with labels so can preview fit
            % ax0 = colorbar
            % ax1= hillshade with channel trace and contours, and
            % optionally bank-material bedrock fraction or terraces
            % ax2= cross section of surface and optionally bedrock surface
            % ax3 = vertical incision time-series
            
            ax0=subplot('position',[0.11 0.80 0.50 0.10]);
            ax1=subplot('position',[0.10 0.10 0.50 0.70]); 
            ax2=subplot('position',[0.70 0.60 0.25 0.35]);
            ax3=subplot('position',[0.70 0.10 0.25 0.35]);
            axis_handles = [ax0 ax1 ax2 ax3];
            
            %%% ax0: colorbar
            % only need to plot colorbar once - doesn't get deleted
            set(fh,'currentaxes',ax0)
            if exportParameters.movie.plot_f_bedrock
                imfile = 'bedrock_fraction_colorbar_horiz.tif'; % loads colorbar from image because the axis already uses grayscale as the colormap
            elseif exportParameters.movie.plot_terraces
                imfile  = 'terrace_colorbar_horiz.tif'; % loads colorbar from image because the axis already uses grayscale as the colormap
            end
            [im,~]=imread(imfile);  
            im = im(:,:,1:3); % Imports with a blank fourth dimension.
            image(im)
            axis off tight equal

            %%% ax1: hillshade with channel trace and contours, and optionally bank-material bedrock fraction or terraces
            set(fh,'currentaxes',ax1)
            xlabel(sprintf('Distance (divided by channel width)'),'fontsize',10);
            
            %%% ax2= cross section of surface and optionally bedrock surface
            set(fh,'currentaxes',ax2)
            xlabel(sprintf('Distance (divided by channel width)'),'fontsize',10);
            ylabel(sprintf('Elevation \n (divided by channel depth)'),'fontsize',10);
            set(ax2,'fontsize',10)
            set(gca,'tickdir','out') % so not overplotted by patch
            
            %%% ax3 = Time-series of bed-elevation change
            set(fh,'currentaxes',ax3)
            xlab3=xlabel(sprintf('Time (yr)'),'fontsize',10);
            ylab3=ylabel(sprintf('Bed elevatoin change rate (mm/yr)'),'fontsize',10);
            set(ax3,'fontsize',10)    
        else
            ax0 = axis_handles(1);
            ax1 = axis_handles(2);
            ax2 = axis_handles(3);
            ax3 = axis_handles(4);
        end    
        
        %%%%%% Now proceed to plot data for axes ax1, ax2, ax3
        %%% ax1
        set(fh,'currentaxes',ax1)
        cla
        % plot hillshade, optionally colored by bank bedrock fraction.
        dem.hs = hillshade(dem.x,dem.y,dem.z,315,45);
        if exportParameters.movie.plot_f_bedrock
            % set transparency to follow bank bedrock fraction.
            hold on
            h1=imagesc(dem.x(:),dem.y(:),dem.f_bedrock,'Alphadata',dem.hs);
            % change colormap
            load mycolormap.mat mycolormap
            colormap(mycolormap)
        else
            hold on
            h1=imagesc(dem.x(:),dem.y(:),dem.hs);
            colormap gray
        end
       
        % plot contours
        contour_interval = exportParameters.movie.contour_interval_depths*D;
        contours = [max(grid.z(:)):-contour_interval:min(grid.z(:))]'; 
        contours=contours(end:-1:1); % defining this way ensures that get a contour outlining the break between the initial topography and the valley
        hold on, c1=contour(dem.x,dem.y,dem.z,contours,'k-'); 
        caxis([0 1]) % restores hillshade shading
        
        % set axis properties
        axis off
        axis equal
        set(gca,'ydir','normal')

        % Overlay patches of channel extent
        for m=1:numel(channel_poly)
            hold on, p=patch(channel_poly(m).x,channel_poly(m).y,'k');
            set(p,'facecolor','b','edgecolor','none')
            uistack(p, 'top')
        end
        
        if exportParameters.movie.plot_terraces
            terraceMappingInputs.dem = dem;
            terraceMappingInputs.centerline = centerline_periodic;
            terraceMappingInputs.cell_width = cell_width;
            terraceMappingInputs.from_file = false;
            exportParameters.terrace_mapping.file_basename = trial;
            exportParameters.movie.plot_terrace_metrics = false;
            exportParameters.terrace_mapping.use_input_parameters=true;
            exportParameters.terrace_mapping.manually_tune_thresholds = false;
            exportParameters.terrace_mapping.find_assoc_channel_elev = true;
            exportParameters.terrace_mapping.make_hillshade = false;
            exportParameters.terrace_mapping.calculate_masks = true;
            exportParameters.terrace_mapping.calculate_terrace_metrics=true;
            exportParameters.terrace_mapping.plot_terrace_metrics = false;
            %%%%%% Default parameters for terrace mapping.
            terraceMappingParameters.dem_fill_sinks = false;
            terraceMappingParameters.clear_border=false;
            terraceMappingParameters.window_size=30; % meters
            terraceMappingParameters.minimum_area=100; % m^2
            terraceMappingParameters.max_elev = init_plane_max_elev;
            terraceMappingParameters.fp_level=2*D;  % meters
            terraceMappingParameters.std_z_thresh=1; % meters
            terraceMappingParameters.calculate_metrics=true;
            terraceMappingParameters.pairing_check=false;
            terraceMappingParameters.plot_pair_check=false;
            terraceMappingParameters.pairing_elev_thresh=NaN; % meters
            terraceMappingParameters.get_slope=false;
            terraceMappingParameters.calculate_masks=true;
            terraceMappingParameters.buffer_dist=500; % meters
            terraceMappingParameters.w = w; % approximate channel width, meters.
            terraceMappingParameters.channelAssociationMethod = 'nearestChannel'; % | 'nearestDownslopeChannel'
            %%%%%%%%
            
            % Execute terrace mapping.
            map_terraces(terraceMappingInputs,exportParameters,terraceMappingParameters);
            
            % use metrics file to plot terraces
            terrace_metrics_file=[exportParameters.terrace_mapping.dir,exportParameters.terrace_mapping.file_basename,'_terrace_metrics.mat'];
            load(terrace_metrics_file,'L','metrics'); % L is label matrix
            area_threshold=terraceMappingParameters.minimum_area;

            if ~isempty(metrics) % i.e., if there are any terraces, proceed to plot using mean elevation
                max_elev = init_plane_max_elev;
                min_elev = min(dem.z(:));
                for i=1:max(L(:))
                    npx = numel(find(L==i));
                    area = npx*cell_width^2;
                    if area>area_threshold
                        mean_elev = metrics(i).mean_elev;
                        relative_elev = mean_elev/(min_elev-max_elev); % ranges from 0 to 1
                        bdy = cell2mat(bwboundaries(L==i,4,'noholes'));
                        x=nan(size(bdy,1),1); y=nan(size(bdy,1),1);
                        for j=1:size(bdy,1)
                            row=bdy(j,1);
                            col=bdy(j,2);
                            x(j)=dem.x(row,col);
                            y(j)=dem.y(row,col);                    
                        end
                        if mean_elev > max_elev
                            color_interp = colors(1,:);
                        elseif mean_elev < min_elev
                            color_interp = colors(2,:);
                        else
                            color_interp=interp1((linspace(0,1,size(colors,1)))',colors,relative_elev,'linear');
                        end
                        hold on, p=patch(x,y,'k'); % because last element is NaN and prevents proper plotting
                        if ne(max_elev,min_elev) % i.e., if more than one terrace level
                            set(p,'facecolor',color_interp);
                        end
                    end
                end
            end
        end

        % clip view 
        set(gca,'xlim',[min(grid.x(:)),max(grid.x(:))])
        set(gca,'ylim',[min(grid.y(:)) max(grid.y(:))])
        
        % add dimensionless time subplot title
        title(sprintf('{Dimensionless time, \\itt*} = %d',t),'fontsize',10,'fontweight','normal');
        % % Add dimensionless time as text in upper-left corner of axis
        % text_h = text(0.02,0.96,sprintf('{Dimensionless time, \\itt*} = %d',t),'units','normalized','fontsize',10);
        % set(text_h,'BackgroundColor','w')
        
        %%% ax2
        set(fh,'currentaxes',ax2)
        cla
        y_extent = [min(grid.y(:)),max(grid.y(:))];
        xc_limits = [min(y_extent),max(y_extent)];
        yi = max(xc_limits):-1:min(xc_limits); % so goes from north to south
        xi=repmat(mean(domain.xExtent),1,numel(yi));
        n=20*round(range(xc_limits)/cell_width);
        [z_surface]=interp2(dem.x,dem.y,dem.z,xi,yi,'nearest');
        [z_bdrk]=interp2(dem.x,dem.y,dem.z_bedrock,xi,yi,'nearest');

        % plot cross-section transect
        hold on, plot(repmat(xi(1),numel(xc_limits),1),xc_limits,'k-','linewidth',1)
        max_depth = min(dem.z_bedrock(:));
        set(gca,'Ylim',[max_depth-D,0+D]);
        ylimits=get(gca,'Ylim');
        yticks = 0:-(exportParameters.movie.xc_ytick_interval_depths*D):ylimits(1);
        yticks=yticks(end:-1:1);
        set(gca,'Ytick',yticks); % by writing it this way, sure to include 0
        set(gca,'xlim',[-xc_limits(2) -xc_limits(1)])

        xlimits=get(gca,'xlim');
        ylimits=get(gca,'ylim');

        % separately plot cross-sections
        hold on, plot(-yi,z_surface,'k-') % this way, plot from north to south    
        bedrock_patch = patch([-yi,xlimits(2),xlimits(2),xlimits(1)],[z_bdrk,0,ylimits(1),ylimits(1)],'k');
        set(bedrock_patch,'facecolor','k','edgecolor','none')
        set(gca,'xlim',xlimits)
        set(gca,'ylim',ylimits)
        
        % adjust axis units
        xtick_limits=get(gca,'xlim');
        set(gca,'Xtick',xtick_limits(1):(exportParameters.movie.xc_xtick_interval_widths*w):xtick_limits(2))
        set(gca,'Xticklabel',round(get(gca,'Xtick')/w-min(get(gca,'Xtick')/w)),'Yticklabel',(get(gca,'Ytick')/D)) % so x starts at 0 (y already does just based on the data)
        set(gca,'fontsize',10)        
        xlabel(sprintf('Distance (divided by channel width)'),'fontsize',10)
        ylabel(sprintf('Elevation \n (divided by channel depth)'),'fontsize',10);
        box on
        % Set y-axis limits (divided by channel depth)
        if bed_elev_chg_rate > 0
           elevation1 = floor(((cumsum(t_max*bed_elev_chg_rate)+D)+D)/D); % First elevation to include in y-axis scale. This is one channel depth below above the highest channel scour elevation. 
        else
            elevation1 = floor(((cumsum(t_max*bed_elev_chg_rate)-D)-D)/D); % First elevation to include in y-axis scale. This is one channel depth below the lowest channel scour elevation.
        end
        elevation2 = ceil((init_plane_max_elev + D)/D);  % Highest elevation to include in y-axis scale. This is one channel depth above the highest elevation.
        set(gca,'ylim',sort([elevation1,elevation2]))
        
        %%% ax3
        set(fh,'currentaxes',ax3)
        cla
        
        if numel(bed_elev_chg_rate)>1
            hold on, plot(1:numel(bed_elev_chg_rate),bed_elev_chg_rate*1e3,'k-','linewidth',2)
            hold on, plot(t,bed_elev_chg_rate(t)*1e3,'o','markerfacecolor','g','markeredgecolor','k','markersize',10)
        else
            hold on, plot([1 t_max],repmat(bed_elev_chg_rate*1e3,1,2),'k-','linewidth',2)
            hold on, plot(t,bed_elev_chg_rate*1e3,'o','markerfacecolor','g','markeredgecolor','k','markersize',10)
        end
        xlabel(sprintf('Time (yr)'),'fontsize',10);
        ylabel(sprintf('Bed elevation change rate (mm/yr)'),'fontsize',10);
        yaxis_extend_factor = 1.5; % Factor by which to extend y-axis limit beyond the maximum bed elevation change rate.
        
        % set limits for y-axis on plot of rate of bed elevation change. 
        if(max(abs(bed_elev_chg_rate)) > eps) 
          set(gca,'xlim',[1 t_max],'ylim',sort([0 yaxis_extend_factor*ceil(bed_elev_chg_rate*1e3)])) % factor of 1e3 because plotting in mm/yr
        else
          set(gca,'xlim',[1 t_max],'ylim', [-1 1])
        end
        
        % Export image
        plotfilename=[exportParameters.movie.frame_dir,'/frame_',sprintf('%06.0f',frame_number)];
        print(fh,plotfilename,'-djpeg')
                        
        % Add figure as a new frame in the movie
        switch exportParameters.movie.format
            case 'MPEG-4'
                F = getframe(fh);
                try
                    open(v) % object must be open to write video
                    writeVideo(v,F)
                catch
                    err='Error (export_grids_movie.m): Error writing video frame';
                    filename=[outputDir,'run_',trial,'_error_data.mat'];
                    save(filename)
                    error(err)
                end
            case 'GIF'
                if ~GIF_initialized
                    gif([exportParameters.outputDir,exportParameters.movie.name],'DelayTime',1/exportParameters.movie.fps,'Overwrite',true)
                    GIF_initialized = true;
                else
                    gif;
                end
        end
    end

    switch exportParameters.movie.format
        case 'MPEG-4'
            close(v); % close video object prior to exiting the function
    end
end