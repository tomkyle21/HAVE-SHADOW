function out = local_pull_col(R, T, col)
    % returns NaN if T missing, col missing, or no match
    n = height(R);
    out = nan(n,1);
    if isempty(T) || ~ismember(col, T.Properties.VariableNames), return; end
    KR = strcat(R.Scenario, "|", R.Configuration, "|", R.Lead_Pilot);
    KT = strcat(T.Scenario, "|", T.Configuration, "|", T.Lead_Pilot);
    [tf, loc] = ismember(KR, KT);
    out(tf) = T.(col)(loc(tf));
end

% function v = local_pull_col(Rin, Tin, colname)
%     % Left-join Tin(colname) onto Rin by (Scenario,Configuration,Lead_Pilot)
%     keys3 = {'Scenario','Configuration','Lead_Pilot'};
%     if isempty(Tin) || ~ismember(colname, Tin.Properties.VariableNames)
%         v = nan(height(Rin),1);
%         return;
%     end
%     R = local_norm_keys(Rin, keys3);
%     T = local_norm_keys(Tin, keys3);
% 
%     % Keep only necessary columns in T to avoid name clashes
%     keep = [keys3, {colname}];
%     keep = intersect(keep, T.Properties.VariableNames, 'stable');
%     T = T(:, keep);
% 
%     J = outerjoin(R(:,keys3), T, 'Keys', keys3, 'MergeKeys', true, 'Type','left');
%     if ismember(colname, J.Properties.VariableNames)
%         v = J.(colname);
%         if ~isnumeric(v)
%             v = str2double(string(v));
%         end
%     else
%         v = nan(height(Rin),1);
%     end
% end