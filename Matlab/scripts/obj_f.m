function [cost, PPL_obj] = obj_f(p, m, D, printCosts, PPL_exp, PPL_var, PPL_t)
    if nargin<4
        printCosts=0;
    end
    if nargin<7
      PPL_exp = '';
      PPL_var = '';
      PPL_t = nan;
    end

    PPL_obj = nan;
    cost = 0;
    
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
            sim = simulate(p, m, {D.(experiment).inputs}, t, experiment);
        end
    
        if isempty(sim) %simulation crashed
            cost = 1e20;
        else
            % Calculate the cost for each variable
            for var_cell = fieldnames(D.(experiment))'
                var = var_cell{:};
                if ~ismember(var, ["meta", "info", "input", "inputs"])
                    var = strrep(var_cell{:},' ','_'); % IQM cannot work with spaces in the names.
                    d = D.(experiment).(var);
    
                    y_sim = getObservable(sim, var, experiment);
    
                    t_idx = ismember(sim.time, d.Time);
                    y_sim = y_sim(t_idx);
    
                    cost = cost + sum(((y_sim-d.Mean)./d.SEM).^2);
                    if printCosts
                        fprintf(strcat(experiment," ", var, ' cost is: %.4f'),sum(((y_sim-d.Mean)./d.SEM).^2)); fprintf(newline);
                    end
                    if strcmp(experiment, PPL_exp) && strcmp(var, PPL_var) && any(ismember(sim.time(t_idx), PPL_t))
                        PPL_obj = y_sim(ismember(sim.time(t_idx), PPL_t));
                    end
                end
            end
            adhoc = calculateAdhoc(sim);
            cost = cost + adhoc;
        end
    end
end
