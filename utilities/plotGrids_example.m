% demo_plot_griddedData.m: Demonstrates how to plot gridded data files.

% load data
griddedDataFile = 'gridded_data_example.mat'; % generated with 
load(griddedDataFile,'dem')

figure
subplot(311) % time of surface scour by channel
imagesc(dem.x(:),dem.y(:),dem.t)
axis image
colormap turbo
xlabel('Distance (m)')
ylabel('Distance (m)')
colorbar
title('Surface scour time (yr)')

subplot(312) % Land-surface elevation
imagesc(dem.x(:),dem.y(:),dem.z)
axis image
xlabel('Distance (m)')
ylabel('Distance (m)')
colorbar
title('Land-surface elevation (m)')

subplot(313) % Elevation of bedrock surface
imagesc(dem.x(:),dem.y(:),dem.z_bedrock)
axis image
xlabel('Distance (m)')
ylabel('Distance (m)')
colorbar
title('Bedrock elevation (m)')