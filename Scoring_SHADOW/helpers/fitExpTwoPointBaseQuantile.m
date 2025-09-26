function [b, tau, stats] = fitExpTwoPointBaseQuantile( ...
    allDataC, allDataD, intsC, intsD, varTemplate, ...
    q1, s1, q2, s2, basePct, useLog)
% Fit exponential score: score = 1 + exp(-(z - z_b)/tau), z = raw or log1p(raw)
% Baseline z_b is the basePct percentile (e.g., 0.05) across ALL scenarios/pilots/configs.
%
% Inputs
%   allDataC, allDataD : struct of sheets -> tables
%   intsC, intsD       : list of CM indices to scan (e.g., 1:5, 1:8)
%   varTemplate        : e.g., 'CM%d_MOP_Time_to_Intercept_s'
%   q1, s1             : upper anchor: quantile (0..1) -> score in (1,2)
%   q2, s2             : lower anchor: quantile (0..1) -> score in (1,2)
%   basePct            : baseline quantile (e.g., 0.05)
%   useLog             : true => z = log1p(x), false => z = x
%
% Outputs
%   b      : baseline in z-space (z_b)
%   tau    : exponential tau
%   stats  : struct with z_b, z1, z2, raw percentiles, etc.
%
% Notes
% - Assumes "smaller is better": higher score for smaller times.
% - Clamps edge cases so you don't divide by zero or pass invalid anchors.

    % -------- collect ALL raw values across scenarios --------
    xAll = [];

    % C
    sheets = fieldnames(allDataC);
    for i = 1:numel(sheets)
        T = allDataC.(sheets{i});
        for k = intsC(:).'
            v = sprintf(varTemplate, k);
            if ismember(v, T.Properties.VariableNames)
                xAll = [xAll; toNum(T.(v))]; %#ok<AGROW>
            end
        end
    end

    % D
    sheets = fieldnames(allDataD);
    for i = 1:numel(sheets)
        T = allDataD.(sheets{i});
        for k = intsD(:).'
            v = sprintf(varTemplate, k);
            if ismember(v, T.Properties.VariableNames)
                xAll = [xAll; toNum(T.(v))]; %#ok<AGROW>
            end
        end
    end

    xAll = xAll(:);
    xAll = xAll(isfinite(xAll));  % drop NaN/Inf

    if isempty(xAll)
        % Fallback: neutral
        b   = 0;
        tau = 1;
        stats = struct('z_b',0,'z1',0,'z2',1,'q1',q1,'q2',q2,'s1',s1,'s2',s2, ...
                       'basePct',basePct,'useLog',useLog,'n',0);
        warning('fitExpTwoPointBaseQuantile: no data found; returning defaults.');
        return;
    end

    % Transform to z-space
    if useLog
        zAll = log1p(max(xAll,0));
    else
        zAll = xAll;
    end

    % -------- baseline at small percentile (not absolute min) --------
    z_b = prctile(zAll, max(0,min(100, basePct*100)));

    % -------- anchors at q1, q2 --------
    z1  = prctile(zAll, max(0,min(100, q1*100)));
    z2  = prctile(zAll, max(0,min(100, q2*100)));

    % Ensure anchors are ≥ baseline (if not, nudge them up)
    z1 = max(z1, z_b);
    z2 = max(z2, z_b + eps);

    % Ensure s1,s2 are in (1,2) strictly
    s1 = min(max(s1, 1+1e-6), 2-1e-6);
    s2 = min(max(s2, 1+1e-6), 2-1e-6);

    % Solve for tau using:
    %   s-1 = exp(-(z - z_b)/tau)  =>  ln(s-1) = -(z - z_b)/tau
    L1 = log(s1 - 1);
    L2 = log(s2 - 1);

    denom = (L1 - L2);
    if abs(denom) < 1e-12
        % Degenerate anchors; fall back to robust spread
        zSpread = max(1e-6, prctile(zAll,90) - prctile(zAll,10));
        tau = zSpread / 2;                        % arbitrary but stable
    else
        tau = (z2 - z1) / denom;
    end

    % Guardrails
    tau = max(tau, 1e-6);
    b   = z_b;

    stats = struct('z_b',z_b,'z1',z1,'z2',z2, ...
                   'q1',q1,'q2',q2,'s1',s1,'s2',s2, ...
                   'basePct',basePct,'useLog',useLog, ...
                   'n',numel(xAll));
end

function v = toNum(x)
    if isnumeric(x) || islogical(x)
        v = double(x(:));
    else
        v = str2double(string(x(:)));
    end
end