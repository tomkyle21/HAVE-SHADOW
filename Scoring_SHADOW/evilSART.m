% %% SART Scores by Configuration — Binned Vertical Spread (Median & Rounding)
% % - One figure per metric: Demand, Supply, Understanding
% % - One point per Pilot x Configuration (median of repeats)
% % - Rounding: Demand -> ceil; Supply & Understanding -> floor
% % - y = 1..7 (bin look with vertical spread within each integer band)
% % - x = configuration category
% % - Distinct marker per pilot; extra LR whitespace
% 
% clear; clc;
% 
% % ------------ Data ------------
% Name = ["MACH";"MACH";"Indy";"Chuck";"Tars";"Savage"; ...
%         "MACH";"Indy";"Chuck";"Savage"; ...
%         "MACH";"MACH";"Indy";"Tars";"Chuck";"Savage";"Pig"; ...
%         "Indy";"Tars";"MACH";"Indy";"Tars";"Chuck";"Savage";"Pig"];
% 
% Date = ["10-Sep";"10-Sep";"11-Sep";"12-Sep";"12-Sep";"12-Sep"; ...
%         "10-Sep";"11-Sep";"12-Sep";"12-Sep"; ...
%         "10-Sep";"10-Sep";"11-Sep";"11-Sep";"12-Sep";"12-Sep";"15-Sep"; ...
%         "9-Sep";"9-Sep";"10-Sep";"11-Sep";"11-Sep";"12-Sep";"12-Sep";"15-Sep"];
% 
% Configuration = ["AA";"AA";"AA";"AA";"AA";"AA"; ...
%                  "AH";"AH";"AH";"AH"; ...
%                  "HA";"HA";"HA";"HA";"HA";"HA";"HA"; ...
%                  "HH";"HH";"HH";"HH";"HH";"HH";"HH";"HH"];
% 
% Demand        = [4;5;3;2;3;3; 4;3;6;4; 4;5;3;4;6;5;4; 2;4;4;3;4;2;4;6];
% Supply        = [5;5;4;3;5;3; 5;4;4;3; 4;4;5;5;5;4;4; 4;4;4;5;4;4;4;4];
% Understanding = [2;6;4;6;6;6; 3;4;5;6; 3;5;4;6;1;6;4; 5;5;3;4;6;5;6;3];
% 
% T = table(Name, Date, Configuration, Demand, Supply, Understanding);
% T.Configuration = categorical(T.Configuration, {'HH','HA','AH','AA'}, 'Ordinal', true);
% 
% % ------------ Parameters ------------
% metrics = {'Demand','Supply','Understanding'};      % (1..7 scale per your note)
% configs = categories(T.Configuration);              % fixed order
% uniqueNames = unique(T.Name);
% 
% % Marker shapes & colors per pilot
% markerSet = {'o','s','d','^','v','p','h','x','+','<','>'}; % enough unique shapes
% colors = lines(numel(uniqueNames));
% 
% % Visual spacing & bin appearance
% xpad = 0.35;           % extra whitespace on left/right
% vSpread = 0.20;        % total vertical spread per pile (±vSpread/2 around integer)
% bandAlpha = 0.07;      % shading for alternating bins
% 
% % ------------ Helper: aggregate median per Pilot×Config and round ------------
% % returns a table Agg with one row per (Name,Configuration) and rounded columns
% Agg = groupmedround(T);
% 
% % ------------ Plot ------------
% for m = 1:numel(metrics)
%     metricName = metrics{m};
% 
%     % Current metric data
%     Yraw = Agg.(metricName);
%     Xcat = Agg.Configuration;
% 
%     % Build vertical-spread y positions by config and integer bin
%     Yplot = Yraw;  % start from integer values (after rounding)
%     for ci = 1:numel(configs)
%         inCfg = Xcat == configs{ci};
%         yCfg = Yraw(inCfg);
%         idxCfg = find(inCfg);
% 
%         % For each integer bin 1..7, distribute duplicates vertically
%         for ybin = 1:7
%             binIdxLocal = idxCfg(yCfg == ybin);
%             k = numel(binIdxLocal);
%             if k > 1
%                 % Evenly spread within [ybin - vSpread/2, ybin + vSpread/2]
%                 offsets = linspace(-vSpread/2, vSpread/2, k);
%                 Yplot(binIdxLocal) = ybin + offsets(:);
%             else
%                 % Keep exactly at the integer (nice bin look)
%                 % (If you prefer slight jitter even for singletons, uncomment:)
%                 % Yplot(binIdxLocal) = ybin + 0;
%             end
%         end
%     end
% 
%     % x numeric positions for categories
%     Xpos = double(Xcat);
% 
%     % Create figure
%     figure('Name', ['Scores by Config (Binned) - ' metricName], 'Color','w');
%     hold on; grid on; box on;
% 
%     % Draw alternating horizontal bands to emphasize bins 1..7
%     yl = [0.5, 7.5];
%     xl = [0.5 - xpad, numel(configs) + 0.5 + xpad];
%     for yb = 1:7
%         if mod(yb,2)==0
%             patch([xl(1) xl(2) xl(2) xl(1)], [yb-0.5 yb-0.5 yb+0.5 yb+0.5], ...
%                   [0 0 0], 'FaceAlpha', bandAlpha, 'EdgeColor', 'none');
%         end
%     end
% 
%     % Plot each pilot with unique marker+color
%     for n = 1:numel(uniqueNames)
%         nm = uniqueNames(n);
%         idx = Agg.Name == nm;
% 
%         plot(Xpos(idx), Yplot(idx), ...
%             'LineStyle', 'none', ...
%             'Marker',   markerSet{mod(n-1, numel(markerSet)) + 1}, ...
%             'MarkerSize', 9, ...
%             'MarkerFaceColor', colors(n,:), ...
%             'MarkerEdgeColor', 'k');
%     end
% 
%     % Axes & labels
%     set(gca, 'XTick', 1:numel(configs), 'XTickLabel', configs);
%     xlabel('Configuration');
%     ylabel(metricName, 'Interpreter','none');
%     title(['Pilot Scores (Median, Rounded) — ', metricName]);
% 
%     % x/y limits & ticks
%     xlim([0.5 - xpad, numel(configs) + 0.5 + xpad]);
%     ylim([0.5, 7.5]);
%     yticks(1:7);
% 
%     legend(uniqueNames, 'Location','bestoutside');
%     hold off;
% end
% 
% %% ---------- Local function: median & rounding aggregator ----------
% function Agg = groupmedround(T)
%     % one row per (Name,Configuration)
%     G = findgroups(T.Name, T.Configuration);
% 
%     % Median per group
%     medDemand        = splitapply(@median, T.Demand,        G);
%     medSupply        = splitapply(@median, T.Supply,        G);
%     medUnderstanding = splitapply(@median, T.Understanding, G);
% 
%     names  = splitapply(@(x) x(1), T.Name,          G);
%     cfgs   = splitapply(@(x) x(1), T.Configuration, G);
% 
%     % Rounding rules & clamp to [1,7]
%     Dem = max(1, min(7, ceil(medDemand)));          % round up
%     Sup = max(1, min(7, floor(medSupply)));         % round down
%     Und = max(1, min(7, floor(medUnderstanding)));  % round down
% 
%     Agg = table(names, cfgs, Dem, Sup, Und, ...
%         'VariableNames', {'Name','Configuration','Demand','Supply','Understanding'});
% 
%     % Preserve categorical order for Configuration
%     Agg.Configuration = categorical(Agg.Configuration, categories(T.Configuration), 'Ordinal', true);
% end

%% SART Scores by Configuration — Horizontal Spread, Config Bins, Clean Legend
% - One figure per metric: Demand, Supply, Understanding
% - One point per Pilot x Configuration (median of repeats)
% - Rounding: Demand -> ceil; Supply & Understanding -> floor (clamped 1..7)
% - Grey vertical bins per configuration (legend-safe)
% - Horizontal jitter to separate overlapping points within each config
% - Distinct marker shapes/colors per pilot

clear; clc;

% ------------ Data ------------
Name = ["MACH";"MACH";"Indy";"Chuck";"Tars";"Savage"; ...
        "MACH";"Indy";"Chuck";"Savage"; ...
        "MACH";"MACH";"Indy";"Tars";"Chuck";"Savage";"Pig"; ...
        "Indy";"Tars";"MACH";"Indy";"Tars";"Chuck";"Savage";"Pig"];

Date = ["10-Sep";"10-Sep";"11-Sep";"12-Sep";"12-Sep";"12-Sep"; ...
        "10-Sep";"11-Sep";"12-Sep";"12-Sep"; ...
        "10-Sep";"10-Sep";"11-Sep";"11-Sep";"12-Sep";"12-Sep";"15-Sep"; ...
        "9-Sep";"9-Sep";"10-Sep";"11-Sep";"11-Sep";"12-Sep";"12-Sep";"15-Sep"];

Configuration = ["AA";"AA";"AA";"AA";"AA";"AA"; ...
                 "AH";"AH";"AH";"AH"; ...
                 "HA";"HA";"HA";"HA";"HA";"HA";"HA"; ...
                 "HH";"HH";"HH";"HH";"HH";"HH";"HH";"HH"];

Demand        = [4;5;3;2;3;3; 4;3;6;4; 4;5;3;4;6;5;4; 2;4;4;3;4;2;4;6];
Supply        = [5;5;4;3;5;3; 5;4;4;3; 4;4;5;5;5;4;4; 4;4;4;5;4;4;4;4];
Understanding = [2;6;4;6;6;6; 3;4;5;6; 3;5;4;6;1;6;4; 5;5;3;4;6;5;6;3];

T = table(Name, Date, Configuration, Demand, Supply, Understanding);
T.Configuration = categorical(T.Configuration, {'HH','HA','AH','AA'}, 'Ordinal', true);

% ------------ Parameters ------------
metrics = {'Demand','Supply','Understanding'};      % 1..7 scales
configs = categories(T.Configuration);
uniqueNames = unique(T.Name);

% Distinct markers/colors per pilot
markerSet = {'o','s','d','^','v','p','h','x','+','<','>'}; % many shapes
colors = lines(numel(uniqueNames));

% Spacing & visuals
xpad = 0.35;          % extra whitespace left/right
jitterWidth = 0.24;   % total horizontal spread for overlapped points in a bin
bandAlpha = 0.07;     % shading for vertical config bins
markerSize = 9;

% ------------ Aggregate median & rounding ------------
Agg = groupmedround(T); % one row per (Name, Configuration)

% ------------ Plot ------------
for m = 1:numel(metrics)
    metricName = metrics{m};
    Xcat = Agg.Configuration;
    Yraw = Agg.(metricName);                         % integers after rounding (1..7)

    % Build horizontally jittered x-positions per (config, y-bin)
    Xbase = double(Xcat);
    Xplot = Xbase;
    for ci = 1:numel(configs)
        inCfg = find(Xbase == ci);
        if isempty(inCfg), continue; end
        yCfg = Yraw(inCfg);
        % For each integer score 1..7, spread duplicates horizontally
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
    figure('Name', ['Scores by Config (Horiz Spread) - ' metricName], 'Color','w');
    hold on; grid on; box on;

    % --- Grey vertical bins per configuration (legend-safe) ---
    xl = [0.5 - xpad, numel(configs) + 0.5 + xpad];
    yl = [0.5, 7.5];
    for ci = 1:numel(configs)
        if mod(ci,2)==0 % shade every other config
            xL = ci - 0.5; xR = ci + 0.5;
            patch([xL xR xR xL], [yl(1) yl(1) yl(2) yl(2)], ...
                  [0 0 0], 'FaceAlpha', bandAlpha, ...
                  'EdgeColor','none', 'HandleVisibility','off'); % hide from legend
        end
    end

    % --- Plot pilots (only these appear in legend) ---
    pilotHandles = gobjects(numel(uniqueNames),1);
    for n = 1:numel(uniqueNames)
        nm = uniqueNames(n);
        idx = Agg.Name == nm;
        pilotHandles(n) = plot(Xplot(idx), Yraw(idx), ...
            'LineStyle','none', ...
            'Marker',   markerSet{mod(n-1, numel(markerSet)) + 1}, ...
            'MarkerSize', markerSize, ...
            'MarkerFaceColor', colors(n,:), ...
            'MarkerEdgeColor', 'k');
    end

    % Axes & labels
    set(gca, 'XTick', 1:numel(configs), 'XTickLabel', configs);
    xlabel('Configuration');
    ylabel(metricName, 'Interpreter','none');
    title(['Pilot Scores (Median, Rounded) — ', metricName]);

    xlim([0.5 - xpad, numel(configs) + 0.5 + xpad]);
    ylim([0.5, 7.5]);
    yticks(1:7);

    % Legend: only pilot markers (no grey bins)
    legend(pilotHandles, cellstr(uniqueNames), 'Location','bestoutside');

    hold off;
end

%% ---------- Local function: median & rounding aggregator ----------
function Agg = groupmedround(T)
    % One row per (Name, Configuration), with rounding rules applied
    G = findgroups(T.Name, T.Configuration);

    names  = splitapply(@(x) x(1), T.Name,          G);
    cfgs   = splitapply(@(x) x(1), T.Configuration, G);

    medDemand        = splitapply(@median, T.Demand,        G);
    medSupply        = splitapply(@median, T.Supply,        G);
    medUnderstanding = splitapply(@median, T.Understanding, G);

    % Apply rounding rules & clamp to [1,7]
    Dem = max(1, min(7, ceil(medDemand)));          % round UP
    Sup = max(1, min(7, floor(medSupply)));         % round DOWN
    Und = max(1, min(7, floor(medUnderstanding)));  % round DOWN

    Agg = table(names, cfgs, Dem, Sup, Und, ...
        'VariableNames', {'Name','Configuration','Demand','Supply','Understanding'});

    % Preserve categorical order for Configuration
    Agg.Configuration = categorical(Agg.Configuration, categories(T.Configuration), 'Ordinal', true);
end