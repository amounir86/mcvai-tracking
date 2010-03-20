function T = multiple_kalman_step(T, frame)
% This method performs the tracking for the object in the scene.
% Currently, it tracks both the bounding box of an object and its velocity

%% Initialize the tracker
% Get the current filter state.
K = T.tracker;

% Initialize the tracked Bounding Boxes
BBm_k1k1 = [];
BBP_k1k1 = [];

% - Number of missing measurement for a certain BB
% - We track it to provide an estimation for the location of the BB even if
% the detector failed. We tolerate the failing of the detector to a certain
% level, afterwards, we discard this measurement and start from scratch
% with the detector results.
MissMCount = [];

% This variable carries the maximum toleration that the tracker can
% tolerate for a failing of the detector to provide reasonable
% measurements.
MaxTrackerToleration = 10;

% Initialize the measured Bounding box
BB = [];

% Set the tracked bounding box and the missed measurements.
if isfield(K, 'BBm_k1k1')
    BBm_k1k1 = K.BBm_k1k1;
    BBP_k1k1 = K.BBP_k1k1;
    MissMCount = K.MissMCount;
end

% Set the measured bounding boxes
if isfield(T.representer, 'BoundingBox')
    BB = T.representer.BoundingBox;
end

%% Update the tracked objects
% This nasty way of looping is because we are resizing the tracking
% object's array inside the loop and as the Matlab runs an interpreter this
% isn't noticed and index out of bound exception is being thrown.
tBB = 0;
while 1
    
    tBB = tBB + 1;

    if tBB > size(BBm_k1k1, 2)
        break;
    end
    
    foundMatch = 0; % To make sure a match was found from measurements

    for mBB = 1:size(BB, 1)
        %% Case 1: A Match was found from the measurements
        if (doMatch(BBm_k1k1(:, tBB), BB(mBB, :)'))
            foundMatch = 1;

            % Get the current measurement out of the representer.
            z_k = BB(mBB, :)';

            % Project the state forward m_{k|k-1}.
            m_kk1 = K.BBF * BBm_k1k1(:, tBB);

            % Partial state covariance update.
            %
            % For every Bounding Box the partial state covariance is a 4*4
            % matrix so we have to index our current 4*4 matrix.
            P_kk1 = K.BBQ + K.BBF * BBP_k1k1(:, (tBB-1)*4+1:tBB*4) * K.BBF';

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
            BBm_k1k1(:, tBB) = m_kk;
            BBP_k1k1(:, (tBB-1)*4+1:tBB*4) = P_kk;
            
            % Update the missing measurements count variable
            MissMCount(tBB) = 1;
            
            % Remove this entry from the measurements array
            BB = [BB(1:mBB-1, :) BB(mBB+1:end, :)];

            break;
        end
    end
    %% Case 2: No match found from the measurements
    % Estimate the new location (NOT SURE ABOUT THE IMPLEMENTATION)
    if ~foundMatch

        % Track but to a certain limit
        % If exceeded the limit
        if MissMCount(tBB) >= MaxTrackerToleration
            % Remove the entries from the tracking object
            BBm_k1k1 = [BBm_k1k1(:, 1:tBB-1) BBm_k1k1(:, tBB+1:end)];
            BBP_k1k1 = [BBP_k1k1(:, 1:(tBB-1)*4) BBP_k1k1(:, tBB*4+1:end)];
            MissMCount = [MissMCount(1:tBB-1) MissMCount(tBB+1:end)];
            tBB = tBB - 1;
            continue;
        end

        % Get the current measurement out of the representer.
        z_k = BBm_k1k1(:, tBB);

        % Project the state forward m_{k|k-1}.
        m_kk1 = K.BBF * BBm_k1k1(:, tBB);

        % Partial state covariance update.
        P_kk1 = K.BBQ + K.BBF * BBP_k1k1(:, (tBB-1)*4+1:tBB*4) * K.BBF';

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
        BBm_k1k1(:, tBB) = m_kk;
        BBP_k1k1(:, (tBB-1)*4+1:tBB*4) = P_kk;

        % Update the missing measurements count variable
        MissMCount(tBB) = MissMCount(tBB) + 1;
    end
end

%% Start tracking the newly measured objects
for mBB = 1:size(BB, 1)
    BBm_k1k1 = [BBm_k1k1 BB(mBB, :)'];
    BBP_k1k1 = [BBP_k1k1 eye(4)];
    MissMCount = [MissMCount 1];
end

%% Reassign the tracker
% Make sure we stuff the filter state back in.
K.BBm_k1k1 = BBm_k1k1;
K.BBP_k1k1 = BBP_k1k1;
K.MissMCount = MissMCount;
T.tracker = K;

return

%% Do match function
function match = doMatch(BB1, BB2)
% This function checks if the first Bounding Box and the second Bounding
% Box match. It gets the center of every Bounding Box and makes sure it is
% smaller than a certain threshold

maxEuclidean = 10; % The max euclidean dist. between the center of the 2 BBs

center1 = [BB1(1)+BB1(3)/2 BB1(2)+BB1(4)/2];
center2 = [BB2(1)+BB2(3)/2 BB2(2)+BB2(4)/2];
euclideanDist = sqrt((center1(1) - center2(1))^2 + (center1(2) - center2(2))^2);

% Make sure the distance is reasonable
if (euclideanDist < maxEuclidean)
    match = 1;
else
    match = 0;
end

return