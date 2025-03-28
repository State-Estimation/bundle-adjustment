% Author: Riccardo Giubilato, Padova (Italy) 2016
% mail:   riccardo.giubilato@gmail.com
% https://www.researchgate.net/profile/Riccardo_Giubilato
% -------------------------------------------------------
% Written and tested on Matlab 2016a

function [Points, Camera] = bundleAdj(Points, Camera, Obs, K, use_finite_diff)
% Using lsqnonlin Matlab function.
% Data structure:
% X=| x y z     x y z     x y z   ..   eul1 eul2 eul3 tx ty tz ... |
%    <point1>  <point2>  <point3> .. < camera ------------ > 
PARAMS{1}=size(Points,1);
PARAMS{2}=size(Camera,3);
PARAMS{3}=Obs;
PARAMS{4}=K;

% Initial conditions
% Stack world point coordinates
X0=reshape(Points',1,3*PARAMS{1});

% Indexes of nonzero coefficients of the Jacobian
% jcoeff:
%       pointIdx   camIdx
% Obs1  1          1
% Obs2  3          1
% ....  ....       ....
% Obsn  1313       11

jcoeff = [];
for i=1:size(Camera,3)
   % Fill with i-th camera parameters
   X0 = [X0, ...
         rotm2eul(Camera(1:3,1:3,i)), ...
         Camera(1:3,4,i)'];

   jcoeff = [jcoeff; [Obs{i}(:,3) i*ones(size(Obs{i},1),1)]];
end

% Jacobian pattern: nrows = num of observations = n elements of res vector
%                   ncols = num of parameters (3*npoints + 6*ncameras)
%                   nnonzero elements = 9 parameters per observation
% allocating sparse matrix for speed
% JacobianPattern = spalloc(size(jcoeff,1), ...
%                           size(X0,2), ...
%                           size(jcoeff,1)*9 ); 
jcoeff2sparse=zeros( size(jcoeff,1)*9, 2 );
for i=1:size(jcoeff,1)
    params = [(1:3)+3*(jcoeff(i,1)-1) ...
              3*PARAMS{1}+(1:6)+6*(jcoeff(i,2)-1)];
    for j=1:9
       jcoeff2sparse(9*(i-1)+j,1) = i; % row index for sparse
       jcoeff2sparse(9*(i-1)+j,2) = params(j);
    end
end                 
                               
JacobianPattern=sparse(jcoeff2sparse(:,1),...
                       jcoeff2sparse(:,2),...
                       ones(size(jcoeff2sparse,1),1)); 

if use_finite_diff
    
    options = optimoptions('lsqnonlin','Display','iter','UseParallel',true);
    options.JacobPattern = JacobianPattern;
    
else %use_levenberg
    options = optimoptions('lsqnonlin','Display','iter','UseParallel',true,...
                          'Algorithm','levenberg-marquardt');
end

X = lsqnonlin(@(X) res_comp(X,PARAMS), X0, [], [], options);

% Ricopio nuove soluzioni
Points = reshape(X(1:3*PARAMS{1}),[3 PARAMS{1}]);
Points = Points';
X(1:3*PARAMS{1}) = [];
for i=1:size(Camera,3)
   Camera(1:3,1:3,i) = eul2rotm(X(1:3)); 
   Camera(1:3,4,i)   = X(4:6)';
   X(1:6)            = [];
end

end

% Calcolo residui
function F = res_comp(X,PARAMS)

F = [];
Obs = PARAMS{3};
K   = PARAMS{4};

for i=1:PARAMS{2}
    for j=1:size(Obs{i},1)
                            % (u,v) of j-th observation in frame i-th
        F = [F reproj(Obs{i}(j,1:2), ...
                            X((1:3) + 3*(Obs{i}(j,3)-1) )',     ... 
                            [eul2rotm( X(3*PARAMS{1}+(1:3)+6*(i-1)) ) ...
                                       X(3*PARAMS{1}+(4:6)+6*(i-1))'], ...
                            K)];
    end
end

end
