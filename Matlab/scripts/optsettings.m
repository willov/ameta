function [opts, problem] = optsettings(m, maxTime)
opts.ndiverse     = 100; %100; %500; %5;
opts.maxtime      = maxTime;
opts.maxeval      = 2e4;

opts.local.solver = 'dhc'; %'dhc'; %'fmincon'; %'nl2sol'; %'mix'; %
opts.local.finish = opts.local.solver;
opts.local.bestx = 0;
opts.local.iterprint = 1;
opts.dim_refset   = 'auto'; 
opts.local.use_gradient_for_finish = 0; 
opts.local.check_gradient_for_finish = 0; 

%% essOPT
problem.f         = 'obj_f';

params = IQMparameters(m);
num_opt = find(strcmp('EtOH_conc', params)) - 1 + 2; % remove EtOH_conc from num_opt and add 2 IC for PetH

[lb, ub] = get_bounds(num_opt, params);
problem.x_U = ub;
problem.x_L = lb;

opts.log_var      = 1:length(lb);
end