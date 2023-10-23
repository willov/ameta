function [sim] = simulate(p, model, inputs, times, experiment_in)

if size(p,1) > 1
    p = p';
end

ic_PEth_L = p(end-1);
ic_PEth_H = p(end);

% Read input parameters
input_names = ["EtOH_conc","vol_drink_per_time","kcal_liquid_per_vol","sex","weight","height"];

Ki_cyp2e1_deg_ethanol = 1e-05;
cf_units_per_mmole = 1.0;
cyp2e1_thalf = 2592.0;

%% Simulate steady state (not used in this example)
ic_SS = IQMinitialconditions(model);
ic = ic_SS;

% Handle special cases for the Javors experiment
simsCombined =  {[], []};        

stateNames = IQMstates(model);
Kcal_Solid_pos = strcmp(stateNames, "Kcal_Solid");
pNames = IQMparameters(model);

try
    for i=1:size(experiment_in,1)
        experiment = experiment_in(i,:);

        if contains(experiment, 'Javors')
            PEth_bound_scale = p(strcmp(pNames,"kPEth_bind")) / p(strcmp(pNames,"kPEth_release")) + 1;
            if strcmp(experiment, "Javors_Low")
                ic(strcmp(stateNames, 'PEth')) = ic_PEth_L;
                ic(strcmp(stateNames, 'PEth_Bound')) = ic_PEth_L*PEth_bound_scale;
            elseif strcmp(experiment, "Javors_High")
                ic(strcmp(stateNames, 'PEth')) = ic_PEth_H;
                ic(strcmp(stateNames, 'PEth_Bound')) = ic_PEth_H*PEth_bound_scale;
            end
        end
        
        %% Simulate all timesteps within the inputs
        n_stimulations = length(inputs{i}.t);
        for idx = 2:n_stimulations % we skip the first one since this is steady state
            if idx<n_stimulations
                t = unique([inputs{i}.t(idx:idx+1)', times(times>=inputs{i}.t(idx) & times<=inputs{i}.t(idx+1))]);
            else % if the last input point is shorter than the time in data, continue until the end in data
                t = unique([inputs{i}.t(idx), times(times>=inputs{i}.t(end))]);
            end
            t = unique([t, t(1):1:t(end)]); % simulations fails sometimes if there is to big timesteps
            
            input = inputs{i}(idx, input_names);
            kcal_input = inputs{i}{idx, "kcal_solid"};
            % if eating a meal, update ic with current kcal and remaining kcal
            if any(Kcal_Solid_pos) && kcal_input > 0
                kcal_solid_remain = max(ic(Kcal_Solid_pos),0);
                ic(ismember(stateNames, {'max_Kcal_Solid', 'Kcal_Solid'})) = kcal_input + kcal_solid_remain;
                ic(ismember(stateNames, 'time_elapsed')) = 0;
            end
            
            if contains(func2str(model), 'Koenig')
                sims(idx) = model(t, ic, [p(1:end-2), input{1,:}, Ki_cyp2e1_deg_ethanol, cf_units_per_mmole, cyp2e1_thalf]);
            else
                sims(idx) = model(t, ic, [p(1:end-2), input{1,:}]);
            end
            ic = sims(idx).statevalues(end,:);
        end

        sim = catSims(sims(2:end));    % Collapse sims to a single sim

        if size(experiment_in,1)>1
            simsCombined{i} = sim;
        end
    end
    % If the experiment was Javors_Combined
    if i==2
        sim.time = simsCombined{1}.time;
        sim.states = simsCombined{1}.states;
        sim.variables = simsCombined{1}.variables;
        sim.variablevalues = (16*simsCombined{1}.variablevalues + 11*simsCombined{2}.variablevalues)/(16+11);
        sim.reactions = simsCombined{1}.reactions;
    end

catch ERR
    sim = [];
    if ~contains(ERR.message, 'CVODE Error:')
        if ~isempty(ERR.identifier)
            fprintf(2,'The identifier was: %s%s',ERR.identifier,newline);
        end
        fprintf(2,'There was an error! The message was: %s%s',ERR.message, newline);
    end
end
end