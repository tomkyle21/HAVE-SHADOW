%% SART CDFs by Configuration
% Creates separate CDF plots for Demand, Supply, Understanding, and SART,
% with one line per configuration (HH, HA, AH, AA).

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

TestPoint = repmat("C", numel(Name), 1);

Configuration = ["AA";"AA";"AA";"AA";"AA";"AA"; ...
                 "AH";"AH";"AH";"AH"; ...
                 "HA";"HA";"HA";"HA";"HA";"HA";"HA"; ...
                 "HH";"HH";"HH";"HH";"HH";"HH";"HH";"HH"];

Demand        = [4;5;3;2;3;3; 4;3;6;4; 4;5;3;4;6;5;4; 2;4;4;3;4;2;4;6];
Supply        = [5;5;4;3;5;3; 5;4;4;3; 4;4;5;5;5;4;4; 4;4;4;5;4;4;4;4];
Understanding = [2;6;4;6;6;6; 3;4;5;6; 3;5;4;6;1;6;4; 5;5;3;4;6;5;6;3];
SART          = [7;11;8;9;11;9; 8;8;9;9; 7;9;9;11;6;10;8; 9;9;7;9;10;9;10;7];

T = table(Name, Date, TestPoint, Configuration, Demand, Supply, Understanding, SART);

% Categorical configurations with consistent order
T.Configuration = categorical(T.Configuration, {'HH','HA','AH','AA'}, 'Ordinal', true);

% ------------ Plot settings ------------
metrics = {'Demand','Supply','Understanding','SART'};
configs = categories(T.Configuration);  % {'HH','HA','AH','AA'}

% Line styles to help distinguish if colors are similar
styles = {'-','--','-.',':'};  % will cycle if fewer than configs
lw = 2;

for m = 1:numel(metrics)
    metricName = metrics{m};
    figure('Name', ['CDF - ' metricName], 'Color', 'w');
    hold on; grid on; box on;
    plotted = false;
    for c = 1:numel(configs)
        cfg = configs{c};
        vals = T.(metricName)(T.Configuration == cfg);
        [Fx, Xx] = safe_ecdf(vals);  % handle no Stats TB fallback
        plot(Xx, Fx, 'LineWidth', lw, 'LineStyle', styles{mod(c-1,numel(styles))+1});
        plotted = true;
    end
    if plotted
        xlabel(metricName, 'Interpreter','none');
        ylabel('F(x)');
        title(['Empirical CDF — ' metricName]);
        legend(configs, 'Location','southeast');
        xlim([min(T.(metricName))-0.5, max(T.(metricName))+0.5]);
        ylim([0 1]);
    end
    hold off;
end

%% ---------- Helper: ECDF with fallback ----------
function [F, X] = safe_ecdf(x)
% Uses Statistics & Machine Learning Toolbox ecdf if available,
% otherwise computes a simple step CDF.
    x = x(:);
    x = x(~isnan(x));
    if isempty(x)
        F = [0;1]; X = [0;0]; return;
    end
    if exist('ecdf','file') == 2
        [F, X] = ecdf(x);
    else
        % Simple empirical CDF
        X = sort(x);
        n = numel(X);
        F = (1:n)'/n;
        % Prepend a zero at start to get the classic step look when plotting with stairs
        % But for compatibility with 'plot', return as is; caller uses plot(X,F).
    end
end

% %% SART CDFs by Configuration (Step Style)
% % Creates separate CDF plots for Demand, Supply, Understanding, and SART,
% % with one line per configuration (HH, HA, AH, AA).
% % Step style = flat line between points, vertical line for jumps.
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
% SART          = [7;11;8;9;11;9; 8;8;9;9; 7;9;9;11;6;10;8; 9;9;7;9;10;9;10;7];
% 
% T = table(Name, Date, Configuration, Demand, Supply, Understanding, SART);
% 
% % Configurations as categorical with fixed order
% T.Configuration = categorical(T.Configuration, {'HH','HA','AH','AA'}, 'Ordinal', true);
% 
% % ------------ Plot settings ------------
% metrics = {'Demand','Supply','Understanding','SART'};
% configs = categories(T.Configuration);  % {'HH','HA','AH','AA'}
% styles = {'-','--','-.',':'};  % line styles
% lw = 2;
% 
% for m = 1:numel(metrics)
%     metricName = metrics{m};
%     figure('Name', ['CDF - ' metricName], 'Color', 'w');
%     hold on; grid on; box on;
% 
%     for c = 1:numel(configs)
%         cfg = configs{c};
%         vals = sort(T.(metricName)(T.Configuration == cfg));
%         n = numel(vals);
% 
%         % Build step function manually
%         xStep = [min(vals); reshape([vals vals]',[],1)]; % duplicate each value
%         yStep = [0; reshape([((1:n)-1)/n; (1:n)/n],[],1)];
% 
%         % Plot step line
%         plot(xStep, yStep, 'LineWidth', lw, 'LineStyle', styles{mod(c-1,numel(styles))+1});
%     end
% 
%     xlabel(metricName, 'Interpreter','none');
%     ylabel('F(x)');
%     title(['Empirical CDF (Step) — ' metricName]);
%     legend(configs, 'Location','southeast');
%     xlim([min(T.(metricName))-0.5, max(T.(metricName))+0.5]);
%     ylim([0 1]);
% 
%     hold off;
% end