function [simOutput] = simulate_outputs(p, m, D)
    simOutput = [];
    
    if any(p<0)
        p = exp(p);
    end

    for experiment_cell = fieldnames(D)'
        t = [];
        experiment = experiment_cell{:};
    
        if experiment == "Javors_Combined"
            % Collect all time points for the given experiment
            for var_cell = fieldnames(D.(experiment))'
                var = var_cell{:};
                if ~ismember(var, ["meta", "info", "input", "inputs"])
                    t = unique([t, D.(experiment).(var).Time(:).']);
                end
            end
            experiments = ["Javors_Low"; "Javors_High"];
            sim = simulate(p, m, {D.(experiments(1)).inputs, D.(experiments(2)).inputs}, t, experiments);
        else
            % Collect all time points for the given experiment
            for var_cell = fieldnames(D.(experiment))'
                var = var_cell{:};
                if ~ismember(var, ["meta", "info", "input", "inputs"])
                    t = unique([t, D.(experiment).(var).Time(:).']);
                end
            end
            % Simulate the experiment
            t_highres = unique([t, t(1):1:t(end)]);
            sim = simulate(p, m, {D.(experiment).inputs}, t_highres, experiment);
        end
    
        % Format variable output
        for var_cell = fieldnames(D.(experiment))'
            try
                var = var_cell{:};
                if ~ismember(var, ["meta", "info", "input", "inputs"])
                    var = strrep(var_cell{:},' ','_'); % IQM cannot work with spaces in the names.
    
                    y_sim = getObservable(sim, var, experiment);
    
                    simOutput.(experiment).(var) = y_sim;
                    simOutput.(experiment).time = sim.time;
                end
            catch err
                simOutput.(experiment).(var) = NaN.*t_highres';
                simOutput.(experiment).time = t_highres;
            end
        end
    end
end
