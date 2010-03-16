function T = filter_blobs7(T, frame)

%  If we detect atleast a blob that is determined or not

if (length(T.detectorK) || length(T.detectorUK))
   
   % For each representer from the last frame
   for nRep = 1 : length(T.representer.all)
       
       found = 0;
       to_delete = [];
       
       %  For each determined recognizer
       for nRec = 1 : length(T.detectorK)
           
           % If the face was recognized by the detector we don't need to
           % use prediction
           if (strcmp(T.detectorK(nRec).name, T.representer.all(nRep).name));
               
               found = 1
               
               % We update the parameters into representer
               representer = T.detectorK(nRec);
               new_velocity = T.detectorK(nRec).Centroid - T.representer.all(nRep).Centroid;
               representer.Velocity = [];
               representer.Velocity = [representer.Centroid representer.Velocity...
                   representer.BoundingBox(3) representer.BoundingBox(4)];
               
               % Delete the recognized blob
%                T.detectorK(nRec) = [];
%                nRec = nRec - 1;
                to_delete = [to_delete nRec];
           
           end
           
                      
       end
       T.detectorK(to_delete) = [];
       
       % If the representer was NOT found
       if ~found
       
           ind = find(strcmp(T.representer.all(nRep).name,T.names)==1);
           
           new_centroid = [T.tracker(ind).m_k1k1(1:2)];
           
           % If there are unassigned blobs
           if (length(T.detectorUK)>=1)
                
               best_blob = calculate_best_blob(T.representer.all(nRep), T.detectorUK);
           
                if (best_blob ~= -1)
               
                    representer = T.detectorUK(best_blob);
                    representer.name = T.representer(nRep).name;
                    new_velocity = T.detectorUK(best_blob) - T.representer.all(nRep);
                    representer.Velocity = [representer.Centroid representer.Velocity ...
                        representer.BoundingBox(3) representer.BoundingBox(4)];
               
                    T.representer.all(nRep) = representer;
                    
                    % Delete this Unknow blob
                    T.detectorUK(best_blob) = [];
                
                else
                    
                    % We delete the representer for this blob
                    T.representer.all(nRep) = [];
                    T.tracker(nRep) = [];
                    
                end
                
           else
               
               % We delete the representer for this blob
               T.representer.all(nRec) = [];
               T.tracker(nRep) = [];
               
           end          
           
       end
       
   end
   
   for nRecRest = 1 : length(T.detectorK)
       
       representer = T.detectorK(nRecRest)
       representer.Velocity = [T.detectorK(nRecRest).Centroid 1 1 ...
           T.detectorK(nRecRest).BoundingBox(3:4)];
       
       T.representer.all = [T.representer.all representer];
       
   end
   
end
    
    
    
    
    
    
    
    
end
