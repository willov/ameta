function [m, estimationData, validationData, D, resultsFolder] = Initialize(modelName, compileModel, estimateOnAllData, validations)
if nargin<2, compileModel=0; end
if nargin<3, estimateOnAllData=0; end
if nargin<4
    validations = ["Okabe_Water2", "Okabe_Glucose", "Okabe_UG400", "Sarkola", "Javors_Low", "Frezza_Woman", "Frezza_Men"]; %need Javors_low for Javors_Combined
end

addpath('Models/')
addpath(genpath('Results/'))

if isunix
    addpath(genpath('../../matlab_general/IQM Tools'))
    addpath(genpath('../../matlab_general/meigo64'))
elseif contains(path, "IQMtools")
    strToFind = 'IQMtools';
    dirs = regexp(path,['[^;]*'],'match');
    whichCellEntry = find(cellfun(@(dirs) ~isempty( strfind(dirs, strToFind) ), dirs) == 1);
    baseDir = dirs(whichCellEntry(1));
    run( strcat(baseDir, '/installIQMtools.m') )
end

%% Load and partition data
D = parseData('../data.json');

estimationData = struct();
validationData = struct();

if estimateOnAllData
    estimationData = D;
    validationData = [];
    resultsFolder = ['All/' modelName];

else
    for field_cell = fieldnames(D)'
        field = field_cell{:};
        if ismember(field, validations)
            validationData.(field) = D.(field);
        else
            estimationData.(field) = D.(field);
        end
    end
    estimationData.Sarkola = D.Sarkola;
    estimationData.Sarkola = rmfield(estimationData.Sarkola, 'EtOH');    % split the Sarkola data into estimation/validation group
    validationData.Sarkola = rmfield(validationData.Sarkola, 'Acetate'); % split the Sarkola data into estimation/validation group

    estimationData.Javors_Low = D.Javors_Low;
    estimationData.Javors_Low.PEth.SEM = inf; % Disables using PEth data from Javors_Low in the cost calculations
    estimationData.Javors_Low.BrAC.SEM = inf; % Disables using BrAC data from Javors_Low in the cost calculations

    resultsFolder = ['Estimation/' modelName];
end

%% setup model files

compiledMEXfiles = dir('Models/AlcoholModel_FoodH*.mex*');
if length(compiledMEXfiles)<3 % If the food hypothesis models have not been compiled, compile them.
    cd ./Models
    files = dir('*.txt');
    for i = 1:length(files)
        if contains(files(i).name, '_FoodH')
            IQMmakeMEXmodel(IQMmodel(files(i).name))
        end
    end
    cd ..
end

if compileModel
    cd ./Models
    IQMmakeMEXmodel(IQMmodel(strcat(char(modelName),'.txt')))
    cd ..
end

m = str2func(modelName);

%% Setup PI and PPL start guesses, if not already available

% init folder
if ~exist(sprintf('Results_PPL/%s', resultsFolder),'dir')
    mkdir(sprintf('Results_PPL/%s', resultsFolder))
end

if ~exist(sprintf('Results_PI/%s', resultsFolder),'dir')
    mkdir(sprintf('Results_PI/%s', resultsFolder))
end

try
    Results = load_parameters("min_cost", resultsFolder);
    cost = obj_f(Results.xbest, m, estimationData);
    dgfEst = getDgf(estimationData);
    limit = chi2inv(0.95, dgfEst);
    % Save an initial set of parameter based on the optimal solution if no
    % other results are saved

    % For PI:
    if length(dir(sprintf('Results_PI/%s', resultsFolder)))==2 && cost<=limit %2 for . and .. (currrent and parent directory)
        [~, problem] = optsettings(m, 100);
        ub = problem.x_U;
        lb = problem.x_L;

        pNames = IQMparameters(m);
        pNames = [pNames(1:length(lb)-2); 'PEth_L'; 'PEth_h'];
        for pIdx = 1:length(pNames)
            save(sprintf('Results_PI/%s/%s (%.4e).mat', resultsFolder, pNames{pIdx}, Results.xbest(pIdx)), "Results")
        end
    end

    % For PPL:
    if length(dir(sprintf('Results_PPL/%s', resultsFolder)))==2 && cost<=limit %2 for . and .. (currrent and parent directory)
        for experiment = string(fieldnames(estimationData))'
            for var = string(fieldnames(estimationData.(experiment)))'
                if ~ismember(var, ["meta", "info", "input", "inputs"])
                    for t = estimationData.(experiment).(var).Time(:).'
                        [PPL_obj, cost] = obj_f_PPL(Results.xbest, m, estimationData, experiment, var, t, 1, limit, 1e99);

                        if cost>limit
                            disp("cost>limit")
                        else
                            point = sprintf('[%s, %s, %g]',experiment, var, t);
                            mkdir(sprintf('Results_PPL/%s/%s', resultsFolder, point))
                            save(sprintf('Results_PPL/%s/%s/%s optPPL(%.4e).mat', resultsFolder, point, point, PPL_obj), "Results")
                        end

                    end
                end
            end
        end
    end

catch e
    if ~strcmp(e.message, "Unrecognized function or variable 'R'.") % typically error occurs only if no parameter sets are available
        disp(getReport(e))
    end
end

end
