% This script runs all the wrapper scripts in sequence.
dbstop if error
clc,clear,close all

thisFile = 'testingWrapper.m';

files = dir('*.m');
files(strcmp({files.name}, thisFile)) = []; % exclude running this mfile

for k = 1:numel(files)
    [~, scriptName] = fileparts(files(k).name);

    fprintf('Running %s\n', scriptName);

    try
        run(files(k).name);
    catch ME% catch ME you see why a particular script failed while allowing the loop to continue with the remaining files
        fprintf('Error in %s:\n%s\n', files(k).name, ME.message);
    end
end