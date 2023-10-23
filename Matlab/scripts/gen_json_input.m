function [json_string] = gen_json_input(model, p, tdrink, prettyPrint)
if nargin <4
    prettyPrint = false;
end
pNames = IQMparameters(model);

input = struct();
for i = find(strcmp(pNames, 'EtOH_conc')):find(strcmp(pNames, 'height'))
    if strcmp(pNames{i}, 'vol_drink_per_time')
        t = [-inf 0 tdrink];
        f = [0 p(i) 0];
    elseif strcmp(pNames{i}, 'EtOH_conc')
        t = {-inf};
        f = {p(i)*100};
    else
        t = {-inf};
        f = {p(i)};
    end
    input.(pNames{i}).t = t;
    input.(pNames{i}).f = f;
end

json_string = jsonencode(input, 'PrettyPrint', prettyPrint, 'ConvertInfAndNaN', false);
json_string = strrep(json_string, "'[","[");
json_string = strrep(json_string, "']","]");
json_string = '"input" :'+json_string+',';

end