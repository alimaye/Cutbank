% createBedElevationChangeTimeseries_example.m: This example script
% demonstrates how to format an input timeseries of channel bed elevation 
% change (erosion or aggradation).
% Created May 28, 2020 by Ajay Limaye, University of Virginia
% (ajay@virginia.edu). 
% Last edited July 24, 2026 by Ajay Limaye.

t_max = 1000; % maximum run time (yr)
t_increment = 2; % time increment (yr)

% calcultethe number of iterations (time steps) for the model run
nTimesteps = 1+ceil(t_max/t_increment); % 1+ because first timestep is at t==0

% Step 2: Create the timeseries of bed elevation change rate in m/yr. The
% timeseries is formatted as an vector with dimensions nTimesteps x 1, 
% where each value denotes the rate of bed eleavation change at the 
% corresponding timestep.

% This example sets the same rate of bed elevation change of -1 mm/yr for each time step.
bed_elev_chg_rate = repmat(-1e-3,nTimesteps,1);

% To specify changes in the rate of bed elevation change over time,
% construct a vector with the same size, but different
% values for different elements. For example, to double the erosion rate for 
% the second half of the model run:
ind_rate_change = ceil(nTimesteps/2);
bed_elev_chg_rate(ind_rate_change:nTimesteps) = -2e-3;



% this check ensures that the number of elements in the timeseries of bed
% elevation change equals the number of timesteps
if ne(numel(bed_elev_chg_rate),nTimesteps)
    error('Number of elements in timeseries of bed elevation change rate does not match number of timesteps.');
end

% plot the timeseries
figure
t = linspace(0,t_max,nTimesteps);
plot(t,bed_elev_chg_rate*1e3,'k-','linewidth',2)
xlabel('Time (yr)')
ylabel('Rate of bed elevation change (mm/yr)')
set(gca,'ylim',max(abs(bed_elev_chg_rate*1e3))*[-1 1])
grid on

% Step 2: save the centerline coordinates to a .mat file
filename = 'inputBedElevationChangeTimeseries_example.mat'; % Edit filename as desired
save(filename,'bed_elev_chg_rate')

% export as figure
print('inputBedElevationChangeTimeseries_example','-dpng')