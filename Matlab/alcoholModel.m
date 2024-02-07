function [] = alcoholModel(estimateOnAllData, doOptimize, doPI, doMCMC, doPPL)
%Optimize per default
if nargin < 1, estimateOnAllData=false; end
if nargin < 2, doOptimize = false; end
if nargin < 3, doPI = false; end
if nargin < 4, doMCMC = false; end
if nargin < 5, doPPL = false; end

clear mex
close all
modelName = 'AlcoholModel';

addpath('scripts')

% Setup inital things - sort data, model compilation, folder initation
compileModel = true;
[m, estimationData, validationData, allData, resultsFolder] = Initialize(modelName, compileModel, estimateOnAllData); % Compile model, and load and partition data

if exist('parfor_done.tmp','file')
    delete 'parfor_done.tmp';
end

rng('shuffle');

%% optimization
if doOptimize
    modelNames = {modelName, 'AlcoholModel_FoodH2', 'AlcoholModel_FoodH3', 'AlcoholModel_FoodH4'};
    maxTime = 250;
    nStarts = 50;

    nRestarts = nStarts*length(modelNames);
    seeds = randi([1,1e7],1,nRestarts);

    for i=1:nRestarts
        modelName_opt = modelNames{mod(i,length(modelNames))+1};
        optimize(seeds(i), modelName_opt, estimateOnAllData, maxTime);
    end
end

%% Do parameter identifiability
if doPI
    maxTime = 500;

    nRestarts = 50;
    seeds = randi([1,1e7],1,nRestarts);

    parfor i=1:nRestarts
        disp(seeds(i))
        optimizePI(seeds(i), modelName, estimateOnAllData, maxTime);
    end
end

%% MCMC sampling
if doMCMC
    nIter = 1e5;
    MCMCfileName = runMCMC(modelName, estimateOnAllData, nIter);
end

%% PPL bounds
if doPPL
    maxTime = 500;
    nRestarts = 10;
    seeds = randi([1,1e7],1,nRestarts);

    parfor i=1:nRestarts
        optimizePPL(seeds(i), modelName, estimateOnAllData, maxTime);
    end
end
%% Test the optimal solution:

trigger = "min_cost"; %min_cost, latest
Results = load_parameters(trigger, resultsFolder);
params = Results.xbest;

if any(params < 0)
    params = exp(params);
end

printcost = true;
costEst = obj_f(params, m, estimationData, printcost);
fprintf("\nEstimation cost: %.3f\n", costEst)
dgfEst = getDgf(estimationData);
limitEst = chi2inv(0.95, dgfEst);
fprintf("Dgf: %i, Limit: %.2f, pass: %d\n\n", dgfEst, limitEst, costEst<=limitEst)

if ~isempty(validationData)
    costVal = obj_f(params, m, validationData, printcost);
    fprintf("\nValidation cost: %.3f\n", costVal)
    dgfVal = getDgf(validationData);
    limit = chi2inv(0.95, dgfVal);
    fprintf("Dgf: %i, Limit: %.2f, pass: %d\n\n", dgfVal, limit, costVal<=limit)
end

%% Plot figures
savefig = false;

if ~exist(['Results_PPL/', resultsFolder, '/PPL_parameters_collected.dat'],'file')
    CollectPPL(['Results_PPL/', resultsFolder], m, estimationData, limitEst);
end

if ~exist(['Results_PPL/', resultsFolder, '/PPL_uncertainty_collected.mat'],'file')
    PPLFileName = 'PPL_parameters_collected.dat';
    CollectUncertainty(['Results_PPL/', resultsFolder], PPLFileName, allData,m,getDgf(allData));
end

if doMCMC
    CI = load(MCMCfileName);
    plotSortedFigures(CI.bestParams, m, allData, savefig, CI.Uncertainty)
elseif exist(['Results_PPL/', resultsFolder, '/PPL_uncertainty_collected.mat'],'file')
    CI = load(['Results_PPL/', resultsFolder, '/PPL_uncertainty_collected.mat']);
    plotSortedFigures(CI.bestParams, m, allData, savefig, CI.Uncertainty)
else
    plotSortedFigures(params, m, allData, savefig)
end

%% plot figure 6 - food hypothesis
modelNames = [modelName; "AlcoholModel_FoodH2"; "AlcoholModel_FoodH3"; "AlcoholModel_FoodH4"];
titels = ["H1"; "H2"; "H3"; "H4"];
D_Food.Jones_Food = estimationData.Jones_Food;
for i=1:length(modelNames)
    modelName_h = char(modelNames(i));
    [m, ~, ~, ~] = Initialize(modelName_h);

    resultsFolder = ['Estimation/' modelName_h];
    trigger = "min_cost"; %min_cost, latest
    Results = load_parameters(trigger, resultsFolder);
    params = Results.xbest;

    if any(params < 0)
        params = exp(params);
    end

    saveFig = false;
    plotFigure6(params, m, D_Food, saveFig, titels(i))
end

% plot figure 7 - Long term drinking
modelName = 'AlcoholModel';
[m, ~, ~, ~] = Initialize(modelName);
D_longTerm = parseData('../data_figure7.json');

resultsFolder = ['Estimation/' modelName];
trigger = "min_cost"; %min_cost, latest
Results = load_parameters(trigger, resultsFolder);
params = Results.xbest;

if any(params < 0)
    params = exp(params);
end

saveFig = false;
plotFigure7(params, m, D_longTerm, saveFig)

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%       functions       %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [] = plotSortedFigures(p, m, D, saveFig, uncertainty)
set(0, 'DefaultFigureRenderer', 'painters');

if nargin < 5
    uncertainty = [];
end
% plots - experiment; variable; subplot index
estimation1 = ["Okabe_Water", "Okabe_Orange", "Okabe_Orange_Syrup", "Okabe_Milk", "Okabe_Milk_Water", "Okabe_Whiskey", "Okabe_UG200", "Okabe_UG600";
    "GastricVolume", "GastricVolume", "GastricVolume", "GastricVolume", "GastricVolume", "GastricVolume","GastricVolume", "GastricVolume";
    1, 2, 3, 6, 5, 7, 8, 9;
    "A) Water (0 kcal)", "B) Orange (220 kcal)", "C) Orange + syrup (329 kcal)", "E) Milk (329 kcal)", "D) Diluted milk (220 kcal)", "F) Diluted whiskey", "G) Glucose solution (200 kcal)", "H) Glucose solution (200 kcal)";
    "Gastric volume", "Gastric volume", "Gastric volume", "Gastric volume", "Gastric volume", "Gastric volume","Gastric volume", "Gastric volume";
    ];

estimation2 = ["Mitchell_Beer", "Mitchell_Wine", "Mitchell_Spirit", "Jones_Fasting", "Kechagias_Fasting", "Javors_High", "Jones_Food", "Kechagias_Breakfast";
    "EtOH", "EtOH", "EtOH", "EtOH", "EtOH", "BrAC", "EtOH", "EtOH";
    1, 2, 3, 4, 5, 6, 7, 8;
    "A) Beer BAC", "B) Wine BAC", "C) Spirit BAC", "D) Fasting BAC", "E) Fasting BAC", "F) High dose BrAC", "G) Food BAC", "H) Food BAC";
    "Plasma EtOH", "Plasma EtOH", "Plasma EtOH", "Plasma EtOH", "Plasma EtOH", "Breath EtOH", "Plasma EtOH", "Plasma EtOH"
    ];

estimation3 = ["Sarkola";
    "Acetate";
    1 ;
    "B) Acetate";
    "Plasma Acetate"
    ];

estimation4 = [ "Javors_High", "Javors_Combined";
    "PEth", "PEth";
    1, 2 ;
    "C) High dose PEth","D) Long term PEth";
    "Plasma PEth", "Plasma PEth";
    ];

validation  = ["Okabe_Water2", "Okabe_Glucose","Okabe_UG400", "Sarkola", "Javors_Low", "Javors_Low", "Frezza_Woman", "Frezza_Men";
    "GastricVolume", "GastricVolume", "GastricVolume", "EtOH", "BrAC", "PEth", "EtOH", "EtOH";
    1, 2, 3, 4, 5, 6, 7, 8;
    "A) Water", "B) Glucose solution (67 kcal)","C) Glucose solution (200 kcal)", "D) Fasting BAC", "E) Low dose BrAC", "F) Low dose PEth", "G) Woman food BAC", "H) Men food BAC";
    "Gastric volume", "Gastric volume", "Gastric volume", "Plasma EtOH", "Breath EtOH", "Plasma PEth", "Plasma EtOH", "Plasma EtOH";
    ];

figsettings = {estimation1; estimation2; estimation3; estimation4; validation};
fignames = ["estimation Gastric", "estimation EtOH", "Acetate", "estimation EtOH derivates", "validation"];

Markersize = 6;
MarkerAlpha = 0.5;

for fignum = 1:length(fignames)
    fig = figure("Name", fignames(fignum));
    figsetting = figsettings{fignum};
    set(gcf,'color','w')

    if fignum == 3
        set(gcf, 'Units', 'centimeters');
        set(gcf,'position', [ 0  0 10 10])
        set(gca,'FontSize' , 10) ;
        figcol = 1;
        figrow = ceil(max(str2double(figsetting(3,:)))/3);

    elseif  fignum == 4
        set(gcf, 'Units', 'centimeters');
        set(gcf,'position', [ 0  0 21 7])
        set(gca,'FontSize' , 10) ;
        figcol = 3;
        figrow = ceil(max(str2double(figsetting(3,:)))/3);

    else
        set(gcf, 'Units', 'centimeters');
        set(gcf,'position', [ 0  0 21 25])
        set(gca,'FontSize' , 10) ;
        figcol = 3;
        figrow = ceil(max(str2double(figsetting(3,:)))/3);

    end

    for col = 1:length(figsetting(1,:))
        experiment_cell = figsetting(1,col);

        if any(strcmp(figsetting(1,:), experiment_cell))

            t = [];
            experiment = experiment_cell{:};

            % get the variable
            var = figsetting(2,col);

            t = unique([t, D.(experiment).(var).Time(:).']);

            % Simulate the experiment
            if experiment == "Javors_Combined"
                experiments = ["Javors_Low"; "Javors_High"];
                sim = simulate(p, m, {D.(experiments(1)).inputs, D.(experiments(2)).inputs}, 0:0.01:t(end), experiments);
                sim.time = sim.time([1 3:end]);
                sim.variablevalues = sim.variablevalues([1 3:end],:);
            else
                sim = simulate(p, m, {D.(experiment).inputs}, 0:0.01:t(end), experiment);
            end
            y_sim = getObservable(sim, var, experiment);

            d = D.(experiment).(var);
            idx_tmax = find(sim.time<=max(d.Time), 1, 'last');

            % plot
            subplotID = str2double(figsetting(3,col));
            subplot(figrow,figcol, subplotID)
            hold on

            % plot data points id they exist
            if contains('Points', fieldnames(d))
                for i=1:size(d.Points,2)
                    if ~isempty(d.Points(:,i))
                        plot(d.Time(i), d.Points(:,i), 'x', 'Color', 'blue','MarkerSize', Markersize-2)
                    end
                end
            end
            line_width = 1 ;

            % Javors Combined is a special case
            if experiment == "Javors_Combined"

                if ~isempty(uncertainty)
                    ciTime = uncertainty.(experiment).(var).time;
                    ci = ciplot(uncertainty.(experiment).(var).min(ciTime<=375), uncertainty.(experiment).(var).max(ciTime<=375), ciTime(ciTime<=375),'k');
                    ci.EdgeColor='none';
                    ci.FaceColor = [204, 204, 204]/255;
                end
                plot(sim.time(sim.time<=375), y_sim(sim.time<=375), 'LineWidth', line_width, 'Color', 'k')
                h = errorbar(d.Time(D.Javors_Combined.PEth.Time<=375), d.Mean(D.Javors_Combined.PEth.Time<=375), d.SEM(D.Javors_Combined.PEth.Time<=375), 'sb', 'MarkerFaceColor', 'auto', 'MarkerSize', Markersize);
                set([h.Bar, h.Line], 'ColorType', 'truecoloralpha', 'ColorData', [h.Line.ColorData(1:3); 255*MarkerAlpha])
                title(figsetting(4,col) , 'interpreter','none' ,'FontWeight','normal','FontSize',12)
                ax = gca;
                ax.TitleHorizontalAlignment = 'left';

                xlabel("time (min)")
                ylabel(strrep(sprintf('%s (%s)', figsetting(5,col), d.Unit), "Delta", "\Delta"))

                ylim(d.ylim)
                xlim(d.xlim(1,:))

                subplotID = subplotID + 1;
                subplot(figrow,figcol, subplotID)
                hold on
                if ~isempty(uncertainty)
                    ci = ciplot(uncertainty.(experiment).(var).min(ciTime>=375), uncertainty.(experiment).(var).max(ciTime>=375), ciTime(ciTime>=375)./(60*24),'k');
                    ci.EdgeColor='none';
                    ci.FaceColor = [204, 204, 204]/255;
                end
                plot(sim.time(sim.time>=375)./(60*24), y_sim(sim.time>=375), 'LineWidth', line_width, 'Color', 'k')
                h = errorbar(d.Time(D.Javors_Combined.PEth.Time>=375)./(60*24), d.Mean(D.Javors_Combined.PEth.Time>=375), d.SEM(D.Javors_Combined.PEth.Time>=375), 'sb', 'MarkerFaceColor', 'auto', 'MarkerSize', Markersize);
                set([h.Bar, h.Line], 'ColorType', 'truecoloralpha', 'ColorData', [h.Line.ColorData(1:3); 255*MarkerAlpha])
                ylim(d.ylim)
                xlim(d.xlim(2,:))

                le = legend({'Model uncertainty' , '\theta_{best} simulation'  });
                set(le,'Box','off')

            elseif experiment == "Frezza_Woman" || experiment == "Frezza_Men"
                if ~isempty(uncertainty)
                    ci = ciplot(uncertainty.(experiment).(var).min_extra, uncertainty.(experiment).(var).max_extra, uncertainty.(experiment).(var).time,'k');
                    ci.EdgeColor='none';
                    ci.FaceColor = [224, 224, 224]/255;
                    ci = ciplot(uncertainty.(experiment).(var).min, uncertainty.(experiment).(var).max, uncertainty.(experiment).(var).time,'k');
                    ci.EdgeColor='none';
                    ci.FaceColor = [204, 204, 204]/255;
                end
                plot(sim.time, y_sim(1:idx_tmax), 'LineWidth', line_width, 'Color', 'k')
                if fignames(fignum) == "validation"
                    h = errorbar(d.Time, d.Mean, d.SEM, 'sb', 'MarkerFaceColor', 'w', 'MarkerSize', Markersize);
                    set([h.Bar, h.Line], 'ColorType', 'truecoloralpha', 'ColorData', [h.Line.ColorData(1:3); 255*MarkerAlpha])
                else
                    h = errorbar(d.Time, d.Mean, d.SEM, 'sb', 'MarkerFaceColor', 'auto', 'MarkerSize', Markersize);
                    set([h.Bar, h.Line], 'ColorType', 'truecoloralpha', 'ColorData', [h.Line.ColorData(1:3); 255*MarkerAlpha])
                end

                if fignum ~= 4 && subplotID == 1
                    le = legend({'Model uncertainty' , '\theta_{best} simulation'});
                    set(le,'Box','off')
                end

                ylim(d.ylim)
                xlim(d.xlim)
            else

                if ~isempty(uncertainty)
                    ci = ciplot(uncertainty.(experiment).(var).min, uncertainty.(experiment).(var).max, uncertainty.(experiment).(var).time,'k');
                    ci.EdgeColor='none';
                    ci.FaceColor = [204, 204, 204]/255;
                end
                plot(sim.time, y_sim(1:idx_tmax), 'LineWidth', line_width, 'Color', 'k')
                if fignames(fignum) == "validation"
                    h = errorbar(d.Time, d.Mean, d.SEM, 'sb', 'MarkerFaceColor', 'w', 'MarkerSize', Markersize);
                    set([h.Bar, h.Line], 'ColorType', 'truecoloralpha', 'ColorData', [h.Line.ColorData(1:3); 255*MarkerAlpha])
                else
                    h = errorbar(d.Time, d.Mean, d.SEM, 'sb', 'MarkerFaceColor', 'auto', 'MarkerSize', Markersize);
                    set([h.Bar, h.Line], 'ColorType', 'truecoloralpha', 'ColorData', [h.Line.ColorData(1:3); 255*MarkerAlpha])
                end

                if fignum ~= 4 && subplotID == 1
                    le = legend({'Model uncertainty' , '\theta_{best} simulation'});
                    set(le,'Box','off')
                end

                ylim(d.ylim)
                xlim(d.xlim)
            end

            title(figsetting(4,col), 'interpreter','none' ,'FontWeight','normal','FontSize',12)

            ax = gca;
            ax.TitleHorizontalAlignment = 'left';

            xlabel("time (min)")
            ylabel(strrep(sprintf('%s (%s)', figsetting(5,col), d.Unit), "Delta", "\Delta"))

        end
    end
    if saveFig
        disp(strcat("Saving fig: ", 'Figures/', fignames(fignum), '.png'))
        exportgraphics(fig, strcat('Figures/', fignames(fignum), '.png'),'Resolution',600)
        exportgraphics(fig, strcat('Figures/', fignames(fignum), '.eps'), 'ContentType','vector')
    end

end
end

function [h]= ciplot(lower,upper,x,colour)

% ciplot(lower,upper)
% ciplot(lower,upper,x)
% ciplot(lower,upper,x,colour)
%
% Plots a shaded region on a graph between specified lower and upper confidence intervals (L and U).
% l and u must be vectors of the same length.
% Uses the 'fill' function, not 'area'. Therefore multiple shaded plots
% can be overlayed without a problem. Make them transparent for total visibility.
% x data can be specified, otherwise plots against index values.
% colour can be specified (eg 'k'). Defaults to blue.

% Raymond Reynolds 24/11/06

if length(lower)~=length(upper)
    error('lower and upper vectors must be same length')
end

if nargin<4
    colour='b';
end

if nargin<3
    x=1:length(lower);
end

% convert to row vectors so fliplr can work
if find(size(x)==(max(size(x))))<2
    x=x'; end
if find(size(lower)==(max(size(lower))))<2
    lower=lower'; end
if find(size(upper)==(max(size(upper))))<2
    upper=upper'; end

h=fill([x fliplr(x)],[upper fliplr(lower)],colour);
end

function [] = plotFigure6(p, m, D, saveFig, fig_title)

t = unique(D.Jones_Food.EtOH.Time(:).');
d = D.Jones_Food.EtOH;

sim = simulate(p, m, {D.Jones_Food.inputs}, 0:0.01:t(end), 'Jones_Food');
y_sim = getObservable(sim, 'EtOH', 'Jones_Food');

fig = figure();
hold on
plot(sim.time, y_sim, 'LineWidth', 2, 'Color', 'k', 'HandleVisibility','off')
h = errorbar(d.Time, d.Mean, d.SEM, 'sb', 'MarkerFaceColor', 'auto', 'MarkerSize', 6);
set([h.Bar, h.Line], 'ColorType', 'truecoloralpha', 'ColorData', [h.Line.ColorData(1:3); 255*0.5])

title(fig_title)
xlabel("time (min)")
ylabel("mg/dL")
ylim([0, 25])
xlim(d.xlim)

% save fig
if saveFig
    disp(strcat("Saving fig: ", 'Figures/', fig_title, '.png'))
    exportgraphics(fig, strcat('Figures/', fig_title, '.png'),'Resolution',600)
    exportgraphics(fig, strcat('Figures/', fig_title, '.eps') , "BackgroundColor","none","ContentType","vector")
end
end

function [] = plotFigure7(p, m, D, saveFig)

figname = "Long Term";
figcol = 2;
figrow = 2;
plotID = 1;

fig = figure("Name",figname);
experiments = fieldnames(D);

longterm_colors = [71, 26, 82;
    71, 26, 82;
    148, 72, 152;
    148, 72, 152;
    163, 88, 159;
    163, 88, 159;
    175, 104, 167;
    175, 104, 167;
    218, 173, 207;
    218, 173, 207]/255;
titles = ["Female drinking pattern", "Female PEth levels", "Male drinking pattern", "Male PEth levels"];

for idxExperiment = 1:length(experiments)
    experiment = experiments{idxExperiment};
    if contains(experiment, "women") && figcol==2
        plotID = 1;
    end

    for var = string(fieldnames(D.(experiment)))'

        if ~contains(var, ["meta", "input"])
            t = [];
            t = unique([t, D.(experiment).(var).Time(:).']);

            % Simulate the experiment
            sim = simulate(p, m, {D.(experiment).inputs}, 0:1:t(end), experiment);
            y_sim = getObservable(sim, var, experiment);

            d = D.(experiment).(var);

            % plot
            if var == "EtOH"
                % plotID = 1;
                sim.variablevalues = sim.variablevalues(sim.time<=1440,:);
                sim.time = sim.time(sim.time<=1440);
                y_sim = getObservable(sim, var, experiment);
                axisVal = [0, 1, 0, 30];
            elseif var == "PEth"
                % plotID = 2;
                y_sim = y_sim./703./2; %Conversion: PEth (µmol/l) × 703 = ng/ml and only half of the right type
                axisVal = [0, 90, 0, 0.25];
            end

            subplot(figrow,figcol,plotID)
            hold on

            if isfield(d, 'Mean')
                errorbar(d.Time/(24*60), d.Mean, d.SEM, 'color','k', 'linewidth',2.5)
            end

            plot(sim.time./(24*60), y_sim, 'LineWidth', 2, 'color', longterm_colors(idxExperiment,:))
            title(titles(plotID), 'Interpreter', 'none')
            xlabel("Days")
            ylabel(strrep(sprintf('Plasma %s (%s)', var, d.Unit), "u", "\mu"))
            axis(axisVal)
            plotID = plotID + 1;
        end

    end
end
subplot(2,2,1)
experiments_w = experiments(contains(experiments,'LT_women'));
experiments_w=strrep(experiments_w, 'LT_women_bmi','BMI ');
experiments_w=strrep(experiments_w, '_','.');
legend(experiments_w,'Box','off');

% save fig
if saveFig
    disp(strcat("Saving fig: ", 'Figures/', figname, '.png'))
    exportgraphics(fig, strcat('Figures/', figname, '.png'),'Resolution',600)
    exportgraphics(fig, strcat('Figures/', figname, '.eps'), "BackgroundColor","none","ContentType","vector")
end
end
