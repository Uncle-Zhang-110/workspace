try
    workspaceDir = fileparts(mfilename('fullpath'));
    cd(workspaceDir);
    Figure8_DeviceCoordination_Real;
    exit(0);
catch ME
    disp(getReport(ME, 'extended'));
    exit(1);
end
