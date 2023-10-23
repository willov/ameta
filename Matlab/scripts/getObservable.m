function [y_sim] = getObservable(sim, var, experiment)
    var_idx = ismember(sim.variables, "y"+var); % Assumes the variablename is prepended with y
    y_sim = sim.variablevalues(:, var_idx);
    
    if experiment ~= "Javors_Combined"
        if contains(var, "BrAC") || contains(var, "PEth")
            y_sim = y_sim - y_sim(1);
        elseif contains(var, "Gastric")
            y_sim = (y_sim - y_sim(1))*100;
        end
    end
end
