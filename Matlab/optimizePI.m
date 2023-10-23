function [] = optimizePI(seed, modelName, estimateOnAllData, maxTime)
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
pNames = IQMparameters(m);
pNames = [pNames(1:length(lb)-2); 'PEth_L'; 'PEth_h'];


warning('off','all')
optim_algorithm = 'ess'; % 'multistart'; %  'cess'; %ess

% Run optimization
for pIdx = shuffle(1:length(pNames)) % in a randomized order
    for pol = shuffle([-1, 1])
        fprintf('Starting with %s\n', pNames{pIdx})
        % Setup optimization bounds
        problem=struct();
        problem.f         = 'obj_f_PI';

        if pol== -1
            problem.vtr = -9.999e19;
            problem.x_U = ub;
            problem.x_L = lb;
            problem.x_U(pIdx) = 1e20;
        else
            problem.vtr = 9.999e-19;
            problem.x_U = ub;
            problem.x_L = lb;
            problem.x_L(pIdx) = 1e-20;
        end

        % Load the best solution found so far
        files = dir(sprintf('Results_PI/%s/%s *.mat', resultsFolder,pNames{pIdx}));

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
        vOpt = problem.x_0(pIdx);

        % Start the optimization
        if vOpt>9.999e-19 && vOpt<9.999e19
            disp(pwd)

            %% MEIGO version:
            Results_sol = MEIGO(problem,opts,optim_algorithm,m, D, pIdx, pol, limit, vOpt);
           
            %% simannealing verison
%             obj = @(p) obj_f_PI(exp(p), m, D, pIdx, pol, limit, vOpt);
%             options = optimoptions('simulannealbnd', 'Display', 'iter');
%             [xbest, fbest] = simulannealbnd(obj, log(problem.x_0),  log(problem.x_L), log(problem.x_U), options);
%             Results_sol = struct();
%             Results_sol.xbest = exp(xbest);
%             Results_sol.fbest = fbest;
           
            %%
            Results_sol.fbest = pol*Results_sol.fbest; % Switcing back maximizations
            fileName = sprintf('./Results_PI/%s/%s (%.4e) %s.mat', resultsFolder,pNames{pIdx}, Results_sol.xbest(pIdx), datestr(now,'yymmdd-HHMMSS'));
            SaveFile(fileName,Results_sol, "Results")
            disp('Solution is saved to:')
            disp(fileName)
        else
            disp('Solution is not saved')
        end
        fprintf('Done with %s\n', pNames{pIdx})

    end
end
end
