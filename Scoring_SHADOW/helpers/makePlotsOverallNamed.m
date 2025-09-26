function makePlotsOverallNamed(T, scenarioLabel, scoreVar, titleSuffix, useLift, k_lift)
% Scatter + box/whisker per Configuration within a Scenario for any overall score column.
% T must include: Scenario, Configuration, Lead_Pilot, and the column named by scoreVar.

    if nargin < 5 || isempty(useLift), useLift = false; end   % overall products can exceed 2 → plot raw
    if nargin < 6 || isempty(k_lift),  k_lift  = 5;    end

    if isempty(T) || height(T)==0
        warning('No rows for %s – %s', string(scenarioLabel), scoreVar);
        return;
    end

    % Filter to this scenario
    T = T(string(T.Scenario)==string(scenarioLabel), :);
    if isempty(T), return; end

    % Ensure score column exists
    if ~ismember(scoreVar, T.Properties.VariableNames)
        warning('Score var %s not in table for scenario %s', scoreVar, string(scenarioLabel));
        return;
    end

    % Fixed config order → map to numeric indices 1..4
    cfgOrder = {'HH','HA','AH','AA'};
    xcats = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    xnum  = double(xcats);  % 1..4 for HH..AA, NaN for undefined rows

    % y data and valid mask
    y = toNum(T.(scoreVar));
    valid = ~isnan(y) & ~isnan(xnum);
    T = T(valid,:); y = y(valid); xcats = xcats(valid); xnum = xnum(valid);
    if isempty(T)
        warning('All values NaN/undefined for %s – %s', string(scenarioLabel), scoreVar);
        return;
    end

    % Optional lift (only within [1,2]; preserves >2)
    if useLift
        y = liftPreserveGT2_(y, k_lift);
    end

    % Present groups and their positions (e.g., ug = [1 2 4] if AH missing)
    ug = unique(xnum(:)');              % numeric positions of groups present
    % Prepare vectors for boxplot (present groups only)
    keep = ismember(xnum, ug);
    y_bp = y(keep);
    x_bp = xnum(keep);

    % Figure
    figure('Name', sprintf('%s – %s', string(scenarioLabel), titleSuffix), 'Color','w'); hold on;

    % ----- Box & whisker at the correct positions (ug) -----
    try
        boxplot(y_bp, x_bp, ...
            'Symbol','', 'Positions', ug, ...
            'Colors',[0.25 0.25 0.25], 'Whisker',1.5, ...
            'PlotStyle','traditional', 'Widths',0.5);
        set(findobj(gca,'Tag','Box'),'LineWidth',1.0);
        set(findobj(gca,'Tag','Median'),'LineWidth',1.2);
    catch ME
        warning('boxplot failed (%s); continuing with scatter only.', ME.message);
    end

    % ----- Scatter with pilot-specific symbology (aligned to xnum) -----
    pilots  = unique(string(T.Lead_Pilot),'stable');
    markers = {'o','s','^','d','v','>','<','p','h','x','+'};
    cols    = lines(max(numel(pilots),7));
    rng(1); jit = (rand(height(T),1) - 0.5) * 0.25;

    legObjs = gobjects(0); legLabs = strings(0,1);
    for p = 1:numel(pilots)
        m = string(T.Lead_Pilot)==pilots(p);
        if ~any(m), continue; end
        col = cols(mod(p-1,size(cols,1))+1, :);
        mk  = markers{mod(p-1,numel(markers))+1};
        scatter(xnum(m)+jit(m), y(m), 38, col, 'filled', ...
                'Marker', mk, 'MarkerFaceAlpha', 0.75, ...
                'MarkerEdgeColor', 'k', 'LineWidth', 0.25);
        % legend proxy
        legObjs(end+1) = plot(nan,nan,'o','MarkerFaceColor',col,'MarkerEdgeColor','k','Marker',mk); %#ok<AGROW>
        legLabs(end+1) = pilots(p); %#ok<AGROW>
    end

    % Axes & labels: always show 1..4 positions (HH,HA,AH,AA)
    grid on;
    xlim([0.5 numel(cfgOrder)+0.5]);
    xticks(1:numel(cfgOrder)); xticklabels(cfgOrder);
    ylabel(titleSuffix);
    title(sprintf('%s – %s', string(scenarioLabel), titleSuffix));

    if ~isempty(legObjs)
        lg = legend(legObjs, legLabs, 'Location','bestoutside'); set(lg,'Interpreter','none');
    end
    hold off;
end

% ---- helpers (local to this file) ----
function y2 = liftPreserveGT2_(y, k)
    y  = max(y, 1);
    z  = min(max(y - 1, 0), 1);
    z2 = log1p(k * z) ./ log1p(k);
    y2 = 1 + z2 + max(y - 2, 0);
end

function v = toNum(x)
    if isnumeric(x) || islogical(x)
        v = double(x(:));
    else
        v = str2double(string(x(:)));
    end
end

% function makePlotsOverallNamed(T, scenarioLabel, scoreVar, titleSuffix)
% % Scatter (pilot-coded) + box/whisker per Configuration, within a Scenario.
% % T must include: Scenario, Configuration, Lead_Pilot, and scoreVar (numeric).
% 
%     if isempty(T) || height(T)==0
%         warning('No rows for %s – %s', scenarioLabel, scoreVar); return;
%     end
% 
%     % Filter scenario
%     T = T(T.Scenario==scenarioLabel, :);
%     if isempty(T), return; end
% 
%     % Ensure score exists
%     if ~ismember(scoreVar, T.Properties.VariableNames)
%         warning('Score var %s not in table for scenario %s', scoreVar, scenarioLabel);
%         return;
%     end
% 
%     % Config categorical (fixed order), but we'll PLOT on numeric positions
%     cfgOrder = {'HH','HA','AH','AA'};
%     T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
%     T = T(~isundefined(T.Configuration), :);
%     if isempty(T), return; end
% 
%     % Numeric x for both boxplot and scatter
%     xnum = double(T.Configuration);
%     y    = T.(scoreVar);
%     K    = numel(cfgOrder);
% 
%     % Figure
%     figure('Name', sprintf('%s – %s', scenarioLabel, titleSuffix), 'Color','w'); hold on;
% 
%     % ---------- Box & whisker (numeric groups) ----------
%     % Hide outliers in box layer so scatter shows points instead
%     try
%         boxplot(y, xnum, ...
%             'Symbol','', ...                 % don't draw outlier markers
%             'Positions', 1:K, ...
%             'Colors', [0.25 0.25 0.25], ...
%             'Whisker', 1.5, ...
%             'PlotStyle','traditional', ...
%             'Widths', 0.5);
%         % Beautify box lines
%         h = findobj(gca,'Tag','Box'); set(h,'LineWidth',1.0);
%         h = findobj(gca,'Tag','Median'); set(h,'LineWidth',1.2);
%     catch
%         warning('boxplot failed; continuing with scatter only.');
%     end
% 
%     % ---------- Scatter with pilot-specific symbology ----------
%     pilots = unique(string(T.Lead_Pilot),'stable');
%     nP = numel(pilots);
% 
%     markers = {'o','s','^','d','v','>','<','p','h','x','+'};
%     nM = numel(markers);
%     cols = lines(max(nP,7));
% 
%     rng(1);
%     jit = (rand(height(T),1) - 0.5) * 0.25;   % small jitter
% 
%     legObjs = gobjects(0);
%     legLabs = strings(0,1);
% 
%     for p = 1:nP
%         mask = string(T.Lead_Pilot)==pilots(p);
%         if ~any(mask), continue; end
%         xj  = xnum(mask) + jit(mask);
%         col = cols(mod(p-1,size(cols,1))+1, :);
%         mk  = markers{mod(p-1,nM)+1};
% 
%         h = scatter(xj, y(mask), 38, col, 'filled', ...
%                     'Marker', mk, 'MarkerFaceAlpha', 0.75, ...
%                     'MarkerEdgeColor', 'k', 'LineWidth', 0.25);
%         legObjs(end+1) = h; %#ok<AGROW>
%         legLabs(end+1) = pilots(p); %#ok<AGROW>
%     end
% 
%     % Axes & labels
%     grid on;
%     xlim([0.5 K+0.5]);
%     xticks(1:K); xticklabels(cfgOrder);
%     ylabel(titleSuffix);
%     title(sprintf('%s – %s', scenarioLabel, titleSuffix));
% 
%     % Legend
%     if ~isempty(legObjs)
%         lg = legend(legObjs, legLabs, 'Location','bestoutside');
%         set(lg,'Interpreter','none');
%     end
% 
%     hold off;
% end