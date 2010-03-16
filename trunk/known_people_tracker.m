function T = known_people_tracker(T, frame)
% This method performs the tracking for the object in the scene.
% Currently, it tracks both the bounding box of an object and its velocity

%% Initialize the tracker
% Get the current filter state.
K = T.tracker;

if ~isfield(T.tracker,'trackings')
    T.tracker.trackings = [];
end

%% Iterate on tracked objects
for tObj = 1:length(T.tracker.trackings)

    found = 0;

    %% Try to find a match from the measurements
    for rObj = 1:length(T.representer.all)
        if (strcmp(T.representer.all.name, T.tracker.trackings.name))
            found = 1;

            % Get the current measurement out of the representer.
            z_k = T.representer.all(rObj).BoundingBox';

            % Project the state forward m_{k|k-1}.
            m_kk1 = K.BBF * T.tracker.trackings(tObj).BBm_k1k1;

            % Partial state covariance update.
            %
            % For every Bounding Box the partial state covariance is a 4*4
            % matrix so we have to index our current 4*4 matrix.
            P_kk1 = K.BBQ + K.BBF * T.tracker.trackings(tObj).BBP_k1k1 * K.BBF';

            % Innovation is disparity in actual versus predicted measurement.
            innovation = z_k - K.BBH * m_kk1;

            % The new state covariance.
            S_k = K.BBH * P_kk1 * K.BBH' + K.BBR;

            % The Kalman gain.
            K_k = P_kk1 * K.BBH' * inv(S_k);

            % The new state prediction.
            m_kk = m_kk1 + K_k * innovation;

            % And the new state covariance.
            P_kk = P_kk1 - K_k * K.BBH * P_kk1;

            % Innovation covariance.
            K.BBinnovation = 0.2 * sqrt(innovation' * innovation) + (0.8) ...
                * K.BBinnovation;

            % And store the current filter state for next iteration.
            T.tracker.trackings(tObj).BBm_k1k1 = m_kk;
            T.tracker.trackings(tObj).BBP_k1k1 = P_kk;

            % Remove the entry from the representer information
            T.representer.all = [T.representer.all(1:rObj - 1) T.representer.all(rObj + 1:end)];
            break;

        end
    end

    %% A match wasn't found, Try estimating using velocity
    if (~found)
    end
end



%% Add the remaining not added represented information
if isfield(T.representer,'all')
    for rObj = 1:length(T.representer.all)
        tracking.BBm_k1k1 = representer.all(rObj).BoundingBox';
        tracking.BBP_k1k1 = eye(4);
        tracking.Velocity = T.representer.all(rObj).Velocity;
        tracking.name = T.representer.all(rObj).name;
        T.tracker.trackings = [T.tracker.trackings tracking];
    end
end