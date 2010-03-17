function T = eagles_tracker(fname, gamma, tau, radius, names)
% This tracker is based on Kalman filters.
% It uses .... for segmentation
% It uses .... for detection
% It uses .... for representation
% Finally, the Kalman filter tracks position, size and velocity

%% People to track

% names_to_track = nargin - 4;
% names = [];
% 
% if (names_to_track == 0)
%     names = 1;
% else
%     for i = 1 : names_to_track
% 
%         name = eval(['name' num2str(i)]);
%         
%         switch name
%             case 'monica' 
%                 names = [names 1];
%             case 'ahmed' 
%                 names = [names 2];
%             case 'lluis' 
%                 names = [names 3];
%             otherwise
%                 names = [1];
%         end
% 
%     end
% end
%    
% names = sort(names);

%% Segmenter
% Initialize background model parameters
Segmenter.gamma   = gamma;
Segmenter.tau     = tau;
Segmenter.radius  = radius;
%Segmenter.segment = @background_subtractor_selectivity;
Segmenter.backgroundBool = 1;
Segmenter.psi = 0;
Segmenter.color = [];
Segmenter.reconstruct = [];
Segmenter.segment = @background_subtractor_eigenbackground;

%% Classifiers
[ eigenfaces, classifiers ] = getClassifiers();

%% Detector
% Recognizer.recognize = @find_blob;
% Recognizer.recognize = @detect_faces;
 Recognizer.recognize = @detect_recognize_faces;
 T.detectorUK = [];
 T.detectorK = [];


%% Represnter
Representer.represent = @filter_blobs7;
Representer.all = [];
Representer.found_blobs = 0;

%% Tracker

% The tracker module.
Tracker.H          = eye(6);        % System model
Tracker.Q          = 0.5 * eye(6);  % System noise
traker_state       = eye(6);        % Measurement model
traker_state(1,3)  = 1;
traker_state(2,4)  = 1;
Tracker.F          = traker_state;
Tracker.R          = 5 * eye(6);  % Measurement noise
Tracker.innovation = 0;
Tracker.track      = @multiple_kalman_step2;


%% Visualizer
% A custom visualizer for the Kalman state.
Visualizer.imageFinal = [];
Visualizer.visualize = @visualize_kalman;
Visualizer.paused    = false;

%% Initialize
% Set up the global tracking system.
T.segmenter   = Segmenter;
T.recognizer  = Recognizer;
T.representer = Representer;
T.tracker     = Tracker;
T.visualizer  = Visualizer;
T.names       = names;
T.eigenfaces  = eigenfaces;
T.classifiers = classifiers;

%% Execute
% And run the tracker on the video.
run_tracker(fname, T);
return
