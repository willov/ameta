
clear all
clear mex
close all

modelName = 'AlcoholModel';

addpath('scripts')

saveFig = false;

%%
% Setup inital things - sort data, model compilation, folder initation
compileModel = true;
[m, estimationData, validationData, allData, resultsFolder] = Initialize(modelName, compileModel, false); % Compile model, and load and partition data

pNames = IQMparameters(IQMmodel([modelName, '.txt'])) ;

trigger = "min_cost"; %min_cost, latest
Results = load_parameters(trigger, resultsFolder);
params = Results.xbest;

pNames_opt = pNames(1:length(params)); 

%% Cost - to check that we have best param
costEst = obj_f(params, m, estimationData, false) ; 

%% Figure 1 

time_sim = 0:1:300 ;

figInput = figure("Name","InputSensitivity");
hold on
set(gcf, 'color' , 'w')
set(gcf, 'Units', 'centimeters');
set(gcf,'position', [ 0  0 21 25])
%% input
length_of_drink = 20;
volume = 0.33; % L 
conc   = 5.1; % % 
kcal_liquid_per_volume = 129 ; % kcal
kcal_solid = 0;
sex    = 1  ; % M/F
weight = 82.66 ;% kg
height = 1.78; % m

%% Height Male
nexttile
title('Height (m) - Male')
hold on

tmp_height = 1.4:0.05:2.1 ; % m
sex = 1 ;

for jj = 1:length(tmp_height)
    [ sim , y_sim] =  sim_with_custom_input(params, m , time_sim, length_of_drink,  volume, conc, kcal_liquid_per_volume , kcal_solid, sex, weight, tmp_height(jj) ) ;
      
    plot(sim.time, y_sim, 'LineWidth', 2, 'Color', [ 0 1-jj*0.05 1-jj*0.05] )
    hold on
    
    Height_list{jj,:} =  [ num2str(tmp_height(jj))  'm' ] ;
end

legend(Height_list ,'NumColumns',2, 'EdgeColor', 'None', 'FontSize', 10)
xlabel("time (min)")
ylabel("mg/dL")
ylim([0, 40])
xlim([0  300])
yline(20 ,'k' ,'LineWidth', 1.5  ,'HandleVisibility','off')

%% Height Female
nexttile
title('Height (m) - Female')
hold on

tmp_height = 1.4:0.05:2.1 ; % m
sex = 0 ;

for jj = 1:length(tmp_height)
    [ sim , y_sim] =  sim_with_custom_input(params, m , time_sim, length_of_drink,  volume, conc, kcal_liquid_per_volume , kcal_solid, sex, weight, tmp_height(jj) ) ;
      
    plot(sim.time, y_sim, 'LineWidth', 2, 'Color', [ 1-jj*0.05 0.5 0] )
    hold on
    
    Height_list{jj,:} =  [ num2str(tmp_height(jj))  'm' ] ;
end

legend(Height_list ,'NumColumns',2, 'EdgeColor', 'None', 'FontSize', 10)
xlabel("time (min)")
ylabel("mg/dL")
ylim([0, 40])
xlim([0  300])
yline(20 ,'k' ,'LineWidth', 1.5  ,'HandleVisibility','off')

%% Weight Male
nexttile
title('Weight (kg) - Male')
hold on

tmp_weight = 50:5:100 ;% kg
sex = 1 ;

for jj = 1:length(tmp_weight)
    [ sim , y_sim] =  sim_with_custom_input(params, m , time_sim, length_of_drink,  volume, conc, kcal_liquid_per_volume , kcal_solid, sex, tmp_weight(jj), height ) ;
      
    plot(sim.time, y_sim, 'LineWidth', 2, 'Color', [ 0 1-jj*0.05 1-jj*0.05] )
    hold on
    
    Weight_list{jj,:} =  [ num2str(tmp_weight(jj))  'kg' ] ;
end

legend(Weight_list,'NumColumns',2, 'EdgeColor', 'None', 'FontSize', 10)
xlabel("time (min)")
ylabel("mg/dL")
ylim([0, 40])
xlim([0  300])
yline(20 ,'k' ,'LineWidth', 1.5  ,'HandleVisibility','off')


%% Weight Female
nexttile
title('Weight (kg) - Female')
hold on

tmp_weight = 50:5:100 ;% kg
sex = 0 ;

for jj = 1:length(tmp_weight)
    [ sim , y_sim] =  sim_with_custom_input(params, m , time_sim, length_of_drink,  volume, conc, kcal_liquid_per_volume , kcal_solid, sex, tmp_weight(jj), height ) ;
      
    plot(sim.time, y_sim, 'LineWidth', 2, 'Color', [ 1-jj*0.05 0.5 0] )
    hold on
    
    Weight_list{jj,:} =  [ num2str(tmp_weight(jj))  'kg' ] ;
end

legend(Weight_list,'NumColumns',2, 'EdgeColor', 'None', 'FontSize', 10)
xlabel("time (min)")
ylabel("mg/dL")
ylim([0, 40])
xlim([0  300])
yline(20 ,'k' ,'LineWidth', 1.5  ,'HandleVisibility','off')

%% ADH
nexttile
title('V_{max} ADH')
hold on

length_of_drink = 20;
volume = 0.33; % L 
conc   = 5.1; % % 
kcal_liquid_per_volume = 129 ; % kcal
kcal_solid = 0;
sex    = 1  ; % M/F
weight = 82.66 ;% kg
height = 1.78 ; % m

idx = ismember(pNames_opt,'VmaxADH') ;

for jj = 1:11
    tmp_param = params;   
    itr = (0.5 + 0.1*(jj-1)) ;
    tmp_param(idx) = params(idx)*itr ;
    
    [ sim , y_sim] =  sim_with_custom_input(tmp_param, m , time_sim, length_of_drink,  volume, conc, kcal_liquid_per_volume , kcal_solid, sex, weight, height ) ;
      
    plot(sim.time, y_sim, 'LineWidth', 2, 'Color', [ 0 1-jj*0.05 1-jj*0.05] )
    hold on
     
    legend_list{jj} =  strcat(num2str(itr*100), '%');
end

legend(legend_list ,'NumColumns',2, 'EdgeColor', 'None', 'FontSize', 10)
xlabel("time (min)")
ylabel("mg/dL")
ylim([0, 40])
xlim([0  300])
yline(20 ,'k' ,'LineWidth', 1.5  ,'HandleVisibility','off')

%% CYP
nexttile
title('V_{max} CYP2E1')
hold on

length_of_drink = 20;
volume = 0.33; % L 
conc   = 5.1; % % 
kcal_liquid_per_volume = 129 ; % kcal
kcal_solid = 0;
sex    = 1  ; % M/F
weight = 82.66 ;% kg
height = 1.78 ; % m

idx = ismember(pNames_opt,'VmaxCYP2E1') ;

for jj = 1:11
    tmp_param = params;   
    itr = (0.5 + 0.1*(jj-1)) ;
    tmp_param(idx) = params(idx)*itr ;
    
    [ sim , y_sim] =  sim_with_custom_input(tmp_param, m , time_sim, length_of_drink,  volume, conc, kcal_liquid_per_volume , kcal_solid, sex, weight, height ) ;
      
    plot(sim.time, y_sim, 'LineWidth', 2, 'Color', [ 0 1-jj*0.05 1-jj*0.05] )
    hold on
    
    legend_list{jj} = strcat(num2str(itr*100), '%');
end

legend(legend_list,'NumColumns',2, 'EdgeColor', 'None', 'FontSize', 10)
xlabel("time (min)")
ylabel("mg/dL")
ylim([0, 40])
xlim([0  300])
yline(20 ,'k' ,'LineWidth', 1.5  ,'HandleVisibility','off')

%% Drink combinations

drinkInputs = parseData('../dataDrinkSeries.json');
fNames = fieldnames(drinkInputs);
titles = ["A) Effect of non-nonalcoholic drinks"; "B) Timing effect of non-alcoholic drinks"];

figTiming = figure("Name","TimingSensitivity");
set(gcf, 'color' , 'w')
set(gcf, 'Units', 'centimeters');
set(gcf,'position', [ 0  0 10.5 12.5])

plotsIDs = [{1:4}; {5:8}];
for ii = 1:2
    nexttile
    hold on
    title(titles(ii), 'interpreter','none' ,'FontWeight','normal','FontSize',12)
    Drink_list = {}; 

    for jj = 1:length(plotsIDs{ii,:})
    
        fName = fNames{plotsIDs{ii}(jj)};
        t_end = drinkInputs.(fName).xlim(end); 
        [sim] = simulate(params, m, {drinkInputs.(fName).inputs}, 0:0.01:t_end, "custom");
    
        y_sim = getObservable(sim, 'EtOH', 'custom');
        
        Drink_list{jj} = drinkInputs.(fName).legend;
    
        plot(sim.time, y_sim, 'Color', drinkInputs.(fName).Color, 'LineWidth', 2, 'LineStyle', drinkInputs.(fName).LineSyle)
    end
    
    xline(drinkInputs.(fNames{plotsIDs{ii}(2)}).inputs.t(3), 'LineWidth', 2)
    Drink_list{jj+1} = ''; 
    if ii == 1
        xline(drinkInputs.(fNames{plotsIDs{ii}(2)}).inputs.t(5), 'LineWidth', 2, 'LineStyle','--')
        xline(drinkInputs.(fNames{plotsIDs{ii}(2)}).inputs.t(7), 'LineWidth', 2)
        Drink_list{jj+2} = ''; Drink_list{jj+3} = '';
    end

    legend(Drink_list, 'EdgeColor', 'None', 'FontSize', 10)
    xlabel("time (min)")
    ylabel(drinkInputs.(fName).Unit)
    ylim(drinkInputs.(fName).ylim)
    xlim(drinkInputs.(fName).xlim)
end

if saveFig
    disp(strcat("Saving fig: ", 'Figures/', 'InputSensitivity', '.pdf'))
    exportgraphics(figInput, strcat('Figures/', 'InputSensitivity', '.pdf'),'Resolution',600)
    exportgraphics(figInput, strcat('Figures/', 'InputSensitivity', '.eps'), "BackgroundColor","none","ContentType","vector")

    disp(strcat("Saving fig: ", 'Figures/', 'TimingSensitivity', '.pdf'))
    exportgraphics(figTiming, strcat('Figures/', 'TimingSensitivity', '.pdf'),'Resolution',600)
    exportgraphics(figTiming, strcat('Figures/', 'TimingSensitivity', '.eps'), "BackgroundColor","none","ContentType","vector")
end
%%


function [ sim , y_sim ] = sim_with_custom_input(params, m , time_sim, length_of_drink,  volume, conc, kcal_liquid_per_volume , kcal_solid, sex, weight, height  )
temp_input = table( [-inf 0 length_of_drink]',...
     [repmat(conc , 3,1)],... % conc
     [0 volume/length_of_drink 0]',... % vol_drink_per_time
     [repmat(kcal_liquid_per_volume , 3,1)],... % kcal_liquid_per_volume
     [repmat(kcal_solid , 3,1)],... % kcal_solid
     [repmat(sex , 3,1)],... % sex
     [repmat(weight , 3,1)],... % weight
     [repmat(height , 3,1)],... % height 
'VariableNames',{'t', 'EtOH_conc','vol_drink_per_time', 'kcal_liquid_per_vol' ,'kcal_solid' , 'sex','weight' , 'height'  }    ) ;

experiment_in(1,:) = 'custom' ;

[sim] = simulate(params, m, { temp_input }, time_sim, experiment_in);

y_sim = getObservable(sim, 'EtOH', 'custom');

end
