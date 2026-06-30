try
    run('run_reviewer2_1_real.m');
catch ME
    report=getReport(ME,'extended'); disp(report);
    fid=fopen('Reviewer2_1_Real_Error.log','w');
    if fid>=0, fprintf(fid,'%s\n',report); fclose(fid); end
    exit(1);
end
exit(0);
