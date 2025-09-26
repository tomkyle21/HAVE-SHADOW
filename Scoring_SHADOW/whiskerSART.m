%% SART Scores by Configuration — Pilot Markers + Boxplots (Thicker Median)
% - One figure per metric: Demand, Supply, Understanding
% - One point per Pilot x Configuration (median of repeats, rounded)
% - Pilot markers horizontally spread to avoid overlap
% - Grey vertical bands for config bins
% - Box-and-whisker plot overlaid at each configuration
% - Thicker blue median line in boxplots

clear; clc;

% ------------ Data ------------
Name = ["MACH";"MACH";"Indy";"Chuck";"Tars";"Savage"; ...
        "MACH";"Indy";"Chuck";"Savage"; ...
        "MACH";"MACH";"Indy";"Tars";"Chuck";"Savage";"Pig"; ...
        "Indy";"Tars";"MACH";"Indy";"Tars";"Chuck";"Savage";"Pig"];
Configuration = ["AA";"AA";"AA";"AA";"AA";"AA"; ...
                 "AH";"AH";"AH";"AH"; ...
                 "HA";"HA";"HA";"HA";"HA";"HA";"HA"; ...
                 "HH";"HH";"HH";"HH";"HH";"HH";"HH";"HH"];
Demand        = [4;5;3;2;3;3; 4;3;6;4; 4;5;3;4;6;5;4; 2;4;4;3;4;2;4;6];
Supply        = [5;5;4;3;5;3; 5;4;4;3; 4;4;5;5;5;4;4; 4;4;4;5;4;4;4;4];
Understanding = [2;6;4;6;6;6; 3;4;5;6; 3;5;4;6;1;6;4; 5;5;3;4;6;5;6;3];

T = table(Name, Configuration, Demand, Supply, Understanding);
T.Configuration = categorical(T.Configuration, {'HH','HA','AH','AA'}, 'Ordinal', true);

% ------------ Parameters ------------
metrics = {'Demand','Supply','Understanding'};
configs = categories(T.Configuration);
uniqueNames = unique(T.Name);

% Markers
markerSet = {'o','s','d','^','v','p','h','x','+','<','>'};
colors = lines(numel(uniqueNames));

% Visuals
xpad = 0.35;
jitterWidth = 0.12;   % tighter horizontal spread
bandAlpha = 0.07;
markerSize = 9;

% ------------ Aggregate (median + rounding) ------------
Agg = groupmedround(T);

% ------------ Plot ------------
for m = 1:numel(metrics)
    metricName = metrics{m};
    Yraw = Agg.(metricName);
    Xcat = Agg.Configuration;
    Xbase = double(Xcat);
    Xplot = Xbase;

    % Horizontal jitter for overlap within each config & score
    for ci = 1:numel(configs)
        inCfg = find(Xbase == ci);
        if isempty(inCfg), continue; end
        yCfg = Yraw(inCfg);
        for yb = 1:7
            same = inCfg(yCfg == yb);
            k = numel(same);
            if k > 1
                offsets = linspace(-jitterWidth/2, jitterWidth/2, k);
                Xplot(same) = Xbase(same) + offsets(:);
            else
                Xplot(same) = Xbase(same);
            end
        end
    end

    % Create figure
    figure('Name', ['Scores by Config + Boxplot - ' metricName], 'Color','w');
    hold on; grid on; box on;

    % --- Grey vertical bins ---
    xl = [0.5 - xpad, numel(configs) + 0.5 + xpad];
    yl = [0.5, 7.5];
    for ci = 1:numel(configs)
        if mod(ci,2)==0
            xL = ci - 0.5; xR = ci + 0.5;
            patch([xL xR xR xL], [yl(1) yl(1) yl(2) yl(2)], ...
                  [0 0 0], 'FaceAlpha', bandAlpha, ...
                  'EdgeColor','none', 'HandleVisibility','off');
        end
    end

    % --- Boxplots per config ---
    boxVals = [];
    boxGroups = [];
    for ci = 1:numel(configs)
        idx = Xbase == ci;
        vals = Yraw(idx);
        boxVals = [boxVals; vals];
        boxGroups = [boxGroups; repmat(ci, numel(vals),1)];
    end
    % Draw boxplots (behind pilot markers)
    boxplot(boxVals, boxGroups, 'Colors',[0.3 0.3 0.3], 'Symbol','', ...
        'Widths',0.4, 'Positions',1:numel(configs), 'Whisker',1.5);
    set(findobj(gca,'Tag','Box'),'LineWidth',1.2);
    set(findobj(gca,'Tag','Median'),'Color','b','LineWidth',2.5); % thicker median line

    % --- Plot pilots ---
    pilotHandles = gobjects(numel(uniqueNames),1);
    for n = 1:numel(uniqueNames)
        nm = uniqueNames(n);
        idx = Agg.Name == nm;
        pilotHandles(n) = plot(Xplot(idx), Yraw(idx), ...
            'LineStyle','none', ...
            'Marker', markerSet{mod(n-1, numel(markerSet)) + 1}, ...
            'MarkerSize', markerSize, ...
            'MarkerFaceColor', colors(n,:), ...
            'MarkerEdgeColor','k');
    end

    % Axes & labels
    set(gca, 'XTick', 1:numel(configs), 'XTickLabel', configs);
    xlabel('Configuration');
    ylabel(metricName, 'Interpreter','none');
    title(['Pilot Scores + Boxplot (Median, Rounded) — ', metricName]);
    xlim([0.5 - xpad, numel(configs) + 0.5 + xpad]);
    ylim([0.5, 7.5]); yticks(1:7);

    legend(pilotHandles, cellstr(uniqueNames), 'Location','bestoutside');
    hold off;
end

%% ---------- Local function: median & rounding aggregator ----------
function Agg = groupmedround(T)
    G = findgroups(T.Name, T.Configuration);

    names  = splitapply(@(x) x(1), T.Name, G);
    cfgs   = splitapply(@(x) x(1), T.Configuration, G);

    medDemand        = splitapply(@median, T.Demand, G);
    medSupply        = splitapply(@median, T.Supply, G);
    medUnderstanding = splitapply(@median, T.Understanding, G);

    % Apply rounding rules & clamp to [1,7]
    Dem = max(1, min(7, ceil(medDemand)));
    Sup = max(1, min(7, floor(medSupply)));
    Und = max(1, min(7, floor(medUnderstanding)));

    Agg = table(names, cfgs, Dem, Sup, Und, ...
        'VariableNames', {'Name','Configuration','Demand','Supply','Understanding'});
    Agg.Configuration = categorical(Agg.Configuration, categories(T.Configuration), 'Ordinal', true);
end