function [fileName] = CollectUncertainty(FolderName,FileName,D,m,dgf)

    ds = datastore([FolderName,'/',FileName]);
    alldata = tall(ds);
    
    SPcost = table2array(alldata(:,1));
    SPparams = table2array(alldata(:,2:end-1));
    
    %% Add extra simulations to the Frezza experiments
    % Females
    drinkTime = D.Frezza_Woman.inputs.t(end) - D.Frezza_Woman.inputs.t(end-1);
    
    % Higher conc woman
    D.Frezza_Woman_High = D.Frezza_Woman;
    D.Frezza_Woman_High.inputs.EtOH_conc(:) = 20; 
    volEtOH_Woman_High  = (D.Frezza_Woman_High.inputs.weight(1)*0.3)*0.001/0.7891;
    TotalVolWoman_High = (D.Frezza_Woman_High.inputs.weight(1)*0.3)*0.001/0.7891/(D.Frezza_Woman_High.inputs.EtOH_conc(1)/100);
    D.Frezza_Woman_High.inputs.vol_drink_per_time(4) = TotalVolWoman_High/drinkTime;
    D.Frezza_Woman_High.inputs.kcal_liquid_per_vol(:) = (TotalVolWoman_High-volEtOH_Woman_High)*200/TotalVolWoman_High;

    % Lower conc woman
    D.Frezza_Woman_Low = D.Frezza_Woman;
    D.Frezza_Woman_Low.inputs.EtOH_conc(:) = 5;
    volEtOH_Woman_Low  = (D.Frezza_Woman_Low.inputs.weight(1)*0.3)*0.001/0.7891;
    TotalVolWoman_Low = (D.Frezza_Woman_Low.inputs.weight(1)*0.3)*0.001/0.7891/(D.Frezza_Woman_Low.inputs.EtOH_conc(1)/100);
    D.Frezza_Woman_Low.inputs.vol_drink_per_time(4) = TotalVolWoman_Low/drinkTime;
    D.Frezza_Woman_Low.inputs.kcal_liquid_per_vol(:) = (TotalVolWoman_Low-volEtOH_Woman_Low)*200/TotalVolWoman_Low;
    
    % Males
    drinkTime = D.Frezza_Men.inputs.t(end) - D.Frezza_Men.inputs.t(end-1);
    
    % Higher conc men
    D.Frezza_Men_High = D.Frezza_Men;
    D.Frezza_Men_High.inputs.EtOH_conc(:) = 20; 
    volEtOH_Men_High  = (D.Frezza_Men_High.inputs.weight(1)*0.3)*0.001/0.7891;
    TotalVolMen_High = (D.Frezza_Men_High.inputs.weight(1)*0.3)*0.001/0.7891/(D.Frezza_Men_High.inputs.EtOH_conc(1)/100);
    D.Frezza_Men_High.inputs.vol_drink_per_time(4) = TotalVolMen_High/drinkTime;
    D.Frezza_Men_High.inputs.kcal_liquid_per_vol(:) = (TotalVolMen_High-volEtOH_Men_High)*200/TotalVolMen_High;

    % Lower conc men
    D.Frezza_Men_Low = D.Frezza_Men;
    D.Frezza_Men_Low.inputs.EtOH_conc(:) = 5;
    volEtOH_Men_Low  = (D.Frezza_Men_Low.inputs.weight(1)*0.3)*0.001/0.7891;
    TotalVolMen_Low = (D.Frezza_Men_Low.inputs.weight(1)*0.3)*0.001/0.7891/(D.Frezza_Men_Low.inputs.EtOH_conc(1)/100);
    D.Frezza_Men_Low.inputs.vol_drink_per_time(4) = TotalVolMen_Low/drinkTime;
    D.Frezza_Men_Low.inputs.kcal_liquid_per_vol(:) = (TotalVolMen_Low-volEtOH_Men_Low)*200/TotalVolMen_Low;

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
    
    %% Assign Frezza extra uncertainty max/min limits
    Uncertainty.Frezza_Woman.EtOH.max_extra = max(Uncertainty.Frezza_Woman.EtOH.max,Uncertainty.Frezza_Woman_Low.EtOH.max);
    Uncertainty.Frezza_Woman.EtOH.max_extra = max(Uncertainty.Frezza_Woman.EtOH.max_extra,Uncertainty.Frezza_Woman_High.EtOH.max);
    Uncertainty.Frezza_Woman.EtOH.min_extra = min(Uncertainty.Frezza_Woman.EtOH.min,Uncertainty.Frezza_Woman_Low.EtOH.min);
    Uncertainty.Frezza_Woman.EtOH.min_extra = min(Uncertainty.Frezza_Woman.EtOH.min_extra,Uncertainty.Frezza_Woman_High.EtOH.min);
    
    Uncertainty.Frezza_Men.EtOH.max_extra = max(Uncertainty.Frezza_Men.EtOH.max,Uncertainty.Frezza_Men_Low.EtOH.max);
    Uncertainty.Frezza_Men.EtOH.max_extra = max(Uncertainty.Frezza_Men.EtOH.max_extra,Uncertainty.Frezza_Men_High.EtOH.max);
    Uncertainty.Frezza_Men.EtOH.min_extra = min(Uncertainty.Frezza_Men.EtOH.min,Uncertainty.Frezza_Men_Low.EtOH.min);
    Uncertainty.Frezza_Men.EtOH.min_extra = min(Uncertainty.Frezza_Men.EtOH.min_extra,Uncertainty.Frezza_Men_High.EtOH.min);
    
    % remove temporary Frezza placeholders
    Uncertainty = rmfield(Uncertainty, "Frezza_Woman_High");
    Uncertainty = rmfield(Uncertainty, "Frezza_Woman_Low");

    Uncertainty = rmfield(Uncertainty, "Frezza_Men_High");
    Uncertainty = rmfield(Uncertainty, "Frezza_Men_Low");
    
    %% Save uncertainty file
    fileName = 'PPL_uncertainty_collected';
    fileName =  [FolderName,'/',fileName,'.mat'];
    save(fileName,'D','Uncertainty', 'bestParams')
    
    end