function [fileName] = CollectUncertainty(FolderName,FileName,D,m,dgf)

    ds = datastore([FolderName,'/',FileName]);
    alldata = tall(ds);
    
    SPcost = table2array(alldata(:,1));
    SPparams = table2array(alldata(:,2:end-1));
    
    %% get best simulation
    fprintf('best simulation')
    
    [~,minIndex] = min(gather(SPcost));
    bestParams = gather(SPparams(minIndex,:));
    
    bestSimulatedOutPut = simulate_outputs(bestParams, m, D);
    
    %% Filter to the ones the are bleow chi2(#data-params)
    filterIdx = SPcost < chi2inv(0.95, dgf-length(bestParams));
    
    %% return the parameters and the cost, which fullfills the demand, into memory
    fprintf('params and cost')
    [sampledCost, sampledParameters] = gather(SPcost(filterIdx), SPparams(filterIdx,:));
    
    SPsize = size(sampledCost,1);
    
    %% run simulations
    fprintf('Finding Simulation uncertainty boundaries....\n')
    warning('off','all')
    outputUB = [];
    outputLB = [];
    
    %define the size output
    experiments = fieldnames(bestSimulatedOutPut);
    for i=1:length(experiments)
        var = fieldnames(bestSimulatedOutPut.(experiments{i}));
        for j=1:length(var)
            if ~isequal(var{j},'time')
                outputUB.(experiments{i}).(var{j}) = NaN*ones(size(bestSimulatedOutPut,1),size(bestSimulatedOutPut,2));
                outputLB.(experiments{i}).(var{j}) = NaN*ones(size(bestSimulatedOutPut,1),size(bestSimulatedOutPut,2));
            end
        end
    end
    
    % find max/min value over all simulations
    for i = 1:SPsize
        if mod(i,1000)==0
            fprintf('%d of %d.\n',i,SPsize);
        end
    
        simoutput = simulate_outputs(sampledParameters(i,:)',m,D);
    
        for j=1:length(experiments)
            var = fieldnames(simoutput.(experiments{j}));
            for k=1:length(var)
                if ~isequal(var{k},'time')
                    outputUB.(experiments{j}).(var{k}) = max(outputUB.(experiments{j}).(var{k}), simoutput.(experiments{j}).(var{k}));
                    outputLB.(experiments{j}).(var{k}) = min(outputLB.(experiments{j}).(var{k}), simoutput.(experiments{j}).(var{k}));
                end
            end
        end
    end
    
    warning('on','all')
    fprintf('Simulation uncertainty boundary search completed\n')
    
    %% Genarate stuct
    Uncertainty = [];
    for i=1:length(experiments)
        var = fieldnames(bestSimulatedOutPut.(experiments{i}));
        for j=1:length(var)
            if ~isequal(var{j},'time')
                Uncertainty.(experiments{i}).(var{j}) = struct('min',outputLB.(experiments{i}).(var{j}), 'max',outputUB.(experiments{i}).(var{j}), 'time', bestSimulatedOutPut.(experiments{i}).time, 'sim', bestSimulatedOutPut.(experiments{i}).(var{j}));
            end
        end
    end
    
    fileName = regexprep(FileName,'.dat','','ignorecase');
    fileName =  [FolderName,'/',fileName,'.mat'];
    save(fileName,'D','Uncertainty', 'bestParams')
    
    end