function [MCMCfileName] = runMCMC( modelName, estimateOnAllData, nIter)

    [m, D, estimationData, ~, resultsFolder] = Initialize(modelName, 0, estimateOnAllData); % Compile model, and load and partition data
    
    % Set up Pesto settings
    [optionsPesto, parameters] = MCMCsettings(m, nIter);
    
    % Create folder
    FolderName=fullfile(pwd,sprintf('Results/MCMC/%s_nIter_%d_%s', modelName, nIter, datestr(now,'yymmdd-HHMMSS')));
    mkdir(FolderName)
    
    % Create file where all chi-2 acceptable parameters are saved
    FileName= 'goodParams.dat';
    FID = fopen([FolderName, '/' ,FileName],'wt');
    
    % set the objective function
    dgf = getDgf(estimationData);
    trigger = "min_cost";
    Results = load_parameters(trigger, resultsFolder);
    theta = log(Results.xbest);
    objectiveFunction=@(theta) obj_f_MCMC(theta,m,D,dgf,FID);
    
    % set intial parameters and sigma structure
    optionsPesto.MCMC.theta0 = theta';
    optionsPesto.MCMC.sigma0 = 1e5 * eye(length(optionsPesto.MCMC.theta0));
    
    % Run the sampling
    warning('off','all')
    parameters = getParameterSamples(parameters, objectiveFunction, optionsPesto);
    warning('on','all')
    
    % Save results to folder
    save(fullfile(FolderName,'parameters.mat'),'parameters')
    fclose(FID);
    
    % Takes all open figures and saves them
    FigList = findobj(allchild(0), 'flat', 'Type', 'figure');
    for iFig = 1:length(FigList)
        FigHandle = FigList(iFig);
        try
            savefig(FigHandle, fullfile(FolderName,['fig', num2str(iFig), '.fig']));
        catch
        end
    end

    % get simulation uncertainty
    MCMCfileName = CollectUncertainty(FolderName,FileName,allData,m,dgf);
end

function [optionsPesto, parameters] = MCMCsettings(m, nIter)
    %% Initial setup
    params = IQMparameters(m);
    num_opt = find(strcmp('EtOH_conc', params)) - 1 + 2; % remove EtOH_conc from num_opt and add 2 IC for PetH
    params = [params(1:num_opt-2);  {'IC_PEth_L'}; {'IC_PEth_H'}];
    
    for i=1:length(params)
        parameters.name{i} = params{i};
    end
    
    [lb, ub] = get_bounds(num_opt, params);
    
    parameters.min = log(lb);
    parameters.max = log(ub);
    parameters.number = length(parameters.name);
    
    %% Options
    optionsPesto = PestoOptions(); % loads optimization options
    
    optionsPesto.obj_type = 'negative log-posterior';
    optionsPesto.n_starts = 1;
    
    optionsPesto.mode = 'visual';
    optionsPesto.comp_type = 'sequential';
    
    % The algorithm does not need any sensitivities to work, therefore only one output
    optionsPesto.objOutNumber=1;
    
    %% Markov Chain Monte Carlo sampling -- Parameters
    
    % Building a struct covering all sampling options:
    optionsPesto.MCMC = PestoSamplingOptions();
    optionsPesto.MCMC.nIterations = nIter; % number of iterations
    optionsPesto.MCMC.mode = optionsPesto.mode;
    %% RAMPART options
    optionsPesto.MCMC.samplingAlgorithm     = 'RAMPART';
    optionsPesto.MCMC.RAMPART.nTemps           = length(params);
    optionsPesto.MCMC.RAMPART.exponentT        = 1000;
    optionsPesto.MCMC.RAMPART.maxT             = 2000;
    optionsPesto.MCMC.RAMPART.alpha            = 0.51;
    optionsPesto.MCMC.RAMPART.temperatureNu    = 1e3;
    optionsPesto.MCMC.RAMPART.memoryLength     = 1;
    optionsPesto.MCMC.RAMPART.regFactor        = 1e-8;
    optionsPesto.MCMC.RAMPART.temperatureEta   = 10;
    
    optionsPesto.MCMC.RAMPART.trainPhaseFrac   = 0.1;
    optionsPesto.MCMC.RAMPART.nTrainReplicates = 5;
    
    optionsPesto.MCMC.RAMPART.RPOpt.rng                  = 1;
    optionsPesto.MCMC.RAMPART.RPOpt.nSample              = floor(optionsPesto.MCMC.nIterations*optionsPesto.MCMC.RAMPART.trainPhaseFrac)-1;
    optionsPesto.MCMC.RAMPART.RPOpt.crossValFraction     = 0.2;
    optionsPesto.MCMC.RAMPART.RPOpt.modeNumberCandidates = 1:20;
    optionsPesto.MCMC.RAMPART.RPOpt.displayMode          = 'text';
    optionsPesto.MCMC.RAMPART.RPOpt.maxEMiterations      = 100;
    optionsPesto.MCMC.RAMPART.RPOpt.nDim                 = parameters.number;
    optionsPesto.MCMC.RAMPART.RPOpt.nSubsetSize          = 1000;
    optionsPesto.MCMC.RAMPART.RPOpt.lowerBound           = parameters.min;
    optionsPesto.MCMC.RAMPART.RPOpt.upperBound           = parameters.max;
    optionsPesto.MCMC.RAMPART.RPOpt.tolMu                = 1e-4 * (parameters.max(1)-parameters.min(1));
    optionsPesto.MCMC.RAMPART.RPOpt.tolSigma             = 1e-2 * (parameters.max(1)-parameters.min(1));
    optionsPesto.MCMC.RAMPART.RPOpt.dimensionsToPlot     = [1,2];
    optionsPesto.MCMC.RAMPART.RPOpt.isInformative        = [1,1,ones(1,optionsPesto.MCMC.RAMPART.RPOpt.nDim-2)];
end