function [] = optimizePPL(seed, modelName, estimateOnAllData, maxTime)
    if nargin<4, maxTime = 100; end
    rng(seed)
    addpath('scripts')

    modelName = char(modelName); % Making sure that the model name is a char array, not string array

    [m, D, ~, ~, resultsFolder] = Initialize(modelName, 0, estimateOnAllData); % Compile model, and load and partition data
    
    limit = chi2inv(0.95, getDgf(D));
    
    %optimization setting
    [opts, problem] = optsettings(m, maxTime);
    ub = problem.x_U;
    lb = problem.x_L;
    
    trigger = "min_cost"; %"min_cost" "oldest" "latest"
    
    %% Setup bounds and run optimization
    
    warning('off','all')
    optim_algorithm = 'ess'; % 'multistart'; %  'cess'; %ess
    
    % Run optimization
    for experiment = shuffle(string(fieldnames(D))')
        for var = shuffle(string(fieldnames(D.(experiment)))')
            if ~ismember(var, ["meta", "info", "input", "inputs"])
                for t = shuffle(D.(experiment).(var).Time(:).')
                    for pol = [-1, 1]

                        point = sprintf('[%s, %s, %g]', experiment, var, t);

                        fprintf('Starting with [%s, %s, %g, %i]\n',  experiment, var, t, pol)
    
                        % Setup optimization bounds
                        problem=struct();
                        problem.f         = 'obj_f_PPL';
                        problem.x_U = ub;
                        problem.x_L = lb;
    
                        % Load the best solution found so far
                        files = dir(sprintf('Results_PPL/%s/%s/%s optPPL*.mat', resultsFolder, point, point));
    
                        while true % Runs until the cost is acceptable, or no files exist
                            filesT = struct2table(files);
                            values = pol*str2double(extract(filesT.name, regexpPattern('[\+\-0-9]\.[0-9]+e[\+\-][0-9]+')));
                            [~, minIdx] = min(values);
    
                            Results_temp = load_file(files(minIdx));
                            cost = obj_f(Results_temp.xbest, m, D);
    
                            if cost<=limit+0.1
                                break
                            elseif isempty(values)
                                Results_temp = load_parameters(trigger, resultsFolder);
                                break
                            end
                            files(minIdx) = [];
                        end
    
                        problem.x_0  = Results_temp.xbest;
                        vOpt = Results_temp.fbest;
    
                        % Start the optimization
                        Results_sol = MEIGO(problem,opts,optim_algorithm,m, D, experiment, var, t, pol, limit, vOpt);
                        Results_sol.fbest = pol*Results_sol.fbest; % Switcing back maximizations
                        cost = obj_f(Results_sol.xbest, m, D);
                        if cost<=limit
                            SaveFile(sprintf('Results_PPL/%s/%s/%s optPPL(%.4e) %s.mat', resultsFolder, point, point, Results_sol.fbest, datestr(now,'yymmdd-HHMMSS')),Results_sol, "Results")
                        else
                            SaveFile(sprintf('Results_PPL/%s/%s/%s opt-not-valid(%.4e) %s.mat', resultsFolder, point, point, Results_sol.fbest, datestr(now,'yymmdd-HHMMSS')),Results_sol, "Results")
                        end
                        fprintf('Done with [%s, %s, %g, %i]\n',  experiment, var, t, pol)
                    end
                end
            end
        end
    
    end
end
