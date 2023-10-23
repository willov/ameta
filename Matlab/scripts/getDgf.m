function [dgf] = getDgf(D)
dgf = 0;
for experiment_cell = fieldnames(D)'
    experiment = experiment_cell{:};
    dgf_exp = 0;
    for var_cell = fieldnames(D.(experiment))'
        var = var_cell{:};
        if ~ismember(var, ["meta", "info", "input", "inputs"])
            dgf = dgf + sum(~isinf(D.(experiment).(var).SEM)); 
            dgf_exp = dgf_exp + sum(~isinf(D.(experiment).(var).SEM)); 
        end
    end
end
end