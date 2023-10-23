function [lb, ub] = get_bounds(num_opt, params)

lb = ones(num_opt,1)*1e-5;
ub = ones(num_opt,1)*1e5;

%ids
id_kmADH = find(strcmp('KmADH', params));
id_kmCYP2E1 = find(strcmp('KmCYP2E1', params));

KmADH    = [ 0.2 2.0 ]*4.61;
KmCYP2E1 = [ 8   10  ]*4.61;

lb([id_kmADH, id_kmCYP2E1]) = [KmADH(1), KmCYP2E1(1)]; % updating last two params, as they have stricter bounds,
ub([id_kmADH, id_kmCYP2E1]) = [KmADH(2), KmCYP2E1(2)];

ub(end-1:end) = 347; %Javros PetH ic
lb(end-1:end) = 12;  %Javros PetH ic
end