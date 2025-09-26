%% ===== Helper plotting function (same y-axis ranges across pilots) =====
function makePlots(T, scenarioLabel)
    % T must have columns:
    %   Lead_Pilot (string/categorical), Configuration (string/categorical),
    %   Total_Altitude_Deviation_Count (double),
    %   Integrated_Altitude_Deviation_ft_s (double)

    if isempty(T)
        warning('No rows for scenario %s', scenarioLabel);
        return;
    end

    % Ensure configuration is categorical with fixed order (HH, HA, AH, AA)
    cfgOrder = {'HH','HA','AH','AA'};
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration), :);
    if isempty(T)
        warning('%s: All rows had undefined Configuration after coercion.', scenarioLabel);
        return;
    end

    % Simple color map for pilots
    pilots = unique(string(T.Lead_Pilot), 'stable');
    nP = numel(pilots);
    cmap = lines(max(nP, 7));

    % === Global axis ranges ===
    yCountMin = min(T.Total_Altitude_Deviation_Count, [], 'omitnan');
    yCountMax = max(T.Total_Altitude_Deviation_Count, [], 'omitnan');
    yIntegMin = min(T.Integrated_Altitude_Deviation_ft_s, [], 'omitnan');
    yIntegMax = max(T.Integrated_Altitude_Deviation_ft_s, [], 'omitnan');

    % Add a little padding (10%) for aesthetics
    yCountRange = [0, yCountMax * 1.1];
    yIntegRange = [0, yIntegMax * 1.1];

    %% (1) Per-pilot figure: left = Total Count, right = Integrated (raw)
    figure('Name', sprintf('%s – Per Pilot', scenarioLabel), 'Color', 'w');
    K = numel(cfgOrder);
    xcats = 1:K;  % numeric positions for categories

    for p = 1:nP
        tp = T(string(T.Lead_Pilot) == pilots(p), :);

        % Means per config
        meanCount = nan(1, K);
        meanInteg = nan(1, K);
        for k = 1:K
            mask = tp.Configuration == cfgOrder{k};
            meanCount(k) = mean(tp.Total_Altitude_Deviation_Count(mask), 'omitnan');
            meanInteg(k) = mean(tp.Integrated_Altitude_Deviation_ft_s(mask), 'omitnan');
        end

        % Left subplot: Total Count
        subplot(nP,2,2*p-1);
        bar(xcats, meanCount, 'FaceColor', [0.6 0.8 1], 'EdgeColor', 'none'); hold on;
        xnum = double(categorical(tp.Configuration, cfgOrder, 'Ordinal', true));
        rng(1); jit = (rand(size(xnum)) - 0.5) * 0.25;
        scatter(xnum + jit, tp.Total_Altitude_Deviation_Count, 32, cmap(p,:), 'filled', ...
                'MarkerFaceAlpha', 0.65, 'MarkerEdgeColor', 'k', 'LineWidth', 0.25);
        hold off; grid on;
        xlim([0.5 K+0.5]); ylim(yCountRange);
        xticks(xcats); xticklabels(cfgOrder);
        ylabel('Total Count'); title(sprintf('%s – Pilot %s (Count)', scenarioLabel, pilots(p)));

        % Right subplot: Integrated (raw ft·s)
        subplot(nP,2,2*p);
        bar(xcats, meanInteg, 'FaceColor', [0.8 0.6 1], 'EdgeColor', 'none'); hold on;
        scatter(xnum + jit, tp.Integrated_Altitude_Deviation_ft_s, 32, cmap(p,:), 'filled', ...
                'MarkerFaceAlpha', 0.65, 'MarkerEdgeColor', 'k', 'LineWidth', 0.25);
        hold off; grid on;
        xlim([0.5 K+0.5]); ylim(yIntegRange);
        xticks(xcats); xticklabels(cfgOrder);
        ylabel('Integrated Deviation (ft·s)'); title(sprintf('%s – Pilot %s (Integrated)', scenarioLabel, pilots(p)));
    end

    %% (2) All-pilots averages per config (bars only)
    figure('Name', sprintf('%s – All Pilots Averages', scenarioLabel), 'Color', 'w');

    meanCountAll = nan(1, K);
    meanIntegAll = nan(1, K);
    for k = 1:K
        mask = T.Configuration == cfgOrder{k};
        meanCountAll(k) = mean(T.Total_Altitude_Deviation_Count(mask), 'omitnan');
        meanIntegAll(k) = mean(T.Integrated_Altitude_Deviation_ft_s(mask), 'omitnan');
    end

    subplot(1, 2, 1);
    bar(xcats, meanCountAll, 'FaceColor', [0.4 0.7 0.9], 'EdgeColor', 'none');
    grid on; xlim([0.5 K+0.5]); ylim(yCountRange);
    xticks(xcats); xticklabels(cfgOrder);
    ylabel('Average Total Count'); title([scenarioLabel ' – All Pilots (Count)']);

    subplot(1, 2, 2);
    bar(xcats, meanIntegAll, 'FaceColor', [0.7 0.4 0.9], 'EdgeColor', 'none');
    grid on; xlim([0.5 K+0.5]); ylim(yIntegRange);
    xticks(xcats); xticklabels(cfgOrder);
    ylabel('Average Integrated Deviation (ft·s)'); title([scenarioLabel ' – All Pilots (Integrated)']);
end