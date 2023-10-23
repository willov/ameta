function [] = optimize(seed, modelName, estimateOnAllData, maxTime)
    if nargin<4, maxTime = 100; end
    rng(seed)
    addpath('scripts')

    modelName = char(modelName); % Making sure that the model name is a char array, not string array

    compileModel = false;
    [m, D, ~, ~, resultsFolder] = Initialize(modelName, compileModel, estimateOnAllData); % Compile model, and load and partition data
    
    %optimization setting
    [opts, problem] = optsettings(m, maxTime);
    
    trigger = "min_cost"; %"min_cost" "oldest" "latest"
    
    warning('off','all')
    optim_algorithm = 'ess'; % 'multistart'; %  'cess'; %ess
    
    % Run optimization
    Results_temp = load_parameters(trigger, resultsFolder);
    theta = Results_temp.xbest;
    if ~exist('parfor_done.tmp','file') % eSS is pretty deterministic, therfore, we perturb the first batch of optimizations a bit.
        perturbation = 0.95 + (1.05-0.95)*rand(1,length(theta));
        theta=theta.*perturbation;
    end
    
    problem_par = problem;
    problem_par.x_0 = theta;
    
    Results_sol = MEIGO(problem_par,opts,optim_algorithm, m, D, false);
    SaveFile(sprintf('./Results/%s/optESS(%.2f), %s.mat',resultsFolder, Results_sol.fbest,  datestr(now,'yymmdd-HHMMSS')),Results_sol, "Results")
    
    %% chi2
    display("cost is " + Results_sol.fbest)
    if ~exist('parfor_done.tmp','file')
        fid = fopen('parfor_done.tmp','a');
        fclose(fid);
    end
end
