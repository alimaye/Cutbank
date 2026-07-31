function export_movie_channelOnly(modelParameterFile,exportParameterFile)
% export_movie_channelOnly.m: movie export for model runs with channel only (i.e., 
% no bank-material tracking). Movie export generates a movie file and 
% associated movie frames.
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
    domain.xExtent = [0 inputs.domain.xExtentChannelWidths*inputs.w];
    w = inputs.w;
    trial = inputs.trial;
    outputDir = inputs.outputDir;
    
    % If vector-based bank-material tracking was used during the model run,
    % also load the geometry of the model domain and the initial alluvial-belt.
    
    % Load export parameters
    load(exportParameterFile,'exportParameters')

    % Load model data    
    load(exportParameters.modelDataFile,'Data','domain')

    % Create directories for file export
    if exportParameters.movie.export
        exportParameters.movie.frame_dir = [exportParameters.outputDir,'movieFrames'];
        if ~exist(exportParameters.movie.frame_dir)
            mkdir(exportParameters.movie.frame_dir) % Movie frames
        end
    end

    t_max_model_run = max(cell2mat({Data(:).t})); % maximum time
    
    % Set times for grid export
    if exportParameters.grid.export
        exportParameters.grid.times = [0:exportParameters.grid.export_interval_yr:(t_max_model_run-exportParameters.grid.export_interval_yr),t_max_model_run]';
    else
        exportParameters.grid.times = [];
    end
    
    if exportParameters.movie.export
        exportParameters.movie.times = [0:exportParameters.movie.frame_interval_yr:(t_max_model_run-exportParameters.movie.frame_interval_yr),t_max_model_run]';
        frame_number = 1; % Initialize movie frame number.
        %%%fh = figure('visible','off'); % initialize figure handle (called in parent and nested function)
        fh = figure; % initialize figure handle (called in parent and nested function). 
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
    buffer=w; % Use channel width as buffer
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
    
    ymin=ymin-buffer;
    ymax=ymax+buffer;
    xmin=domain.xExtent(1)-buffer; 
    xmax=domain.xExtent(2)+buffer;
    clear bb_all
    
    % Plot time-series of channel extents and longitudinal
    % profiles.
    for i1=1:numel(Data) % have to go youngest to oldest here, so proceed in order of elements in 'Data'
        t = Data(i1).t;
        centerline = Data(i1).centerline;
        % Create channel footprint polygon and periodically replicated
        % centerline
        nodes_add = numel(centerline.X)-1;
        [centerline_periodic] = replicate_centerline_periodic(centerline,nodes_add);      
        channel_poly = create_polygon(centerline_periodic,w,domain);
        
        if  ismember(t,exportParameters.movie.times) % Then make movie frame
            [axis_handles] = export_movie_frame_channelOnly(axis_handles); % Calls nested function to export a movie frame
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
    fprintf('Finished movie export for run %s \n',trial);
    
    % Nested function
    function[axis_handles] = export_movie_frame_channelOnly(axis_handles)
    % export_movie_frame_channelOnly.m: Generates still images for a movie
    % of a model run with channel evolution only.
    % The images include a map of the channel, the longitudnal profile, and
    % optionally time-series of bed elevation change rate (aggradation or
    % incision). 
  
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
            % ax1= channel extent
            % ax2= longitudinal profile
            % ax3 = vertical incision time-series
            
            ax1=subplot('position',[0.10 0.10 0.50 0.70]); 
            ax2=subplot('position',[0.70 0.60 0.25 0.35]);
            ax3=subplot('position',[0.70 0.10 0.25 0.35]);
            axis_handles = [ax1 ax2 ax3];
          
            %%% ax1: Channel trace
            set(fh,'currentaxes',ax1)
            title(sprintf('{Dimensionless time, \\itt*} = 0'),'verticalalignment','bottom','fontsize',10,'fontweight','normal');
            xlabel(sprintf('Distance (divided by channel width)'),'fontsize',10);
            
            %%% ax2: Longitudinal profile
            set(fh,'currentaxes',ax2)
            xlabel(sprintf('Distance (divided by channel width)'),'fontsize',10);
            ylabel(sprintf('Elevation \n (divided by channel depth)'),'fontsize',10);
            set(ax2,'fontsize',10)
            set(gca,'tickdir','out') % so not overplotted by patch
            
            %%% ax3: Average bed elevation time-series (aggradation or
            %%% incision)
            set(fh,'currentaxes',ax3)
            xlab3=xlabel(sprintf('Time (yr)'),'fontsize',10);
            ylab3=ylabel(sprintf('Vertical incision rate (mm/yr)'),'fontsize',10);
            set(ax3,'fontsize',10)    
        else
            ax1 = axis_handles(1);
            ax2 = axis_handles(2);
            ax3 = axis_handles(3);
        end    
        
        %%%%%% Now proceed to plot data for axes ax1, ax2, ax3
        %%% ax1: Channel extent
        set(fh,'currentaxes',ax1)
        cla
       
        % set axis properties
        axis off
        axis equal
        set(gca,'ydir','normal')

        % Plot patches of channel extent
        for m=1:numel(channel_poly)
            hold on, p=patch(channel_poly(m).x,channel_poly(m).y,'k');
            set(p,'facecolor','b','edgecolor','none')
        end

        % clip view to min/max of coordinates
        set(gca,'xlim',[xmin xmax])
        set(gca,'ylim',[ymin ymax])
        
        % Add dimensionless time as title
        title(sprintf('{Dimensionless time, \\itt*} = %d',t),'verticalalignment','bottom','fontsize',10);
        
        %%% ax2: Longitudinal profile
        set(fh,'currentaxes',ax2)
        cla
        distance = [0;cumsum(sqrt(sum(diff([centerline.X,centerline.Y],1,1).^2,2)))];
        plot(distance,centerline.Z,'k-')
        set(gca,'fontsize',10)        
        xlabel(sprintf('Distance (m)'),'fontsize',10)
        ylabel(sprintf('Elevation (m)'),'fontsize',10);
        title('Channel longitudinal profile')
        box on
        
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
        yaxis_extend_factor = 1.5; % Factor by which to extend y-axis limit beyond the maximum vertical incision rate.
        
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