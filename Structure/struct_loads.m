% TODO:
% - Some values are hardcoded, organize data.mat.
% - Assumptions on fuselage and wings specs are made a little bit
%   everywhere. Check that when more precise values are available.
% - Pass x_cs and y_cs as arguments, and define default values.
% - Maybe save data as a cell of tables ?

function struct_loads
% STRUCT_LOADS  Structural loads.
%
% This function computes the structural loads exerting on the wings and
% fuselage cross sections, for all the critical points of the flight
% envelope.
%
% This function implements the methodology and formulae that can be
% found at:
% Aircraft Structures>lesson 6>slides 26 to 39.
%
% Save:
%   FuselageLoads: table
%   WingsLoads: table

%% Imports

% Directory where the present file lies.
file_dir = fileparts(mfilename("fullpath"));

% Constants and aircraft data.
C = load(fullfile(file_dir, "../constants.mat"));
D = load(fullfile(file_dir, "../data.mat"));

% Utilities.
addpath(genpath(fullfile(file_dir, "../Utils")));

%% Main solve

% Function global variables.
x_cs = [5, 6, 7];    % X-coord. of desired fuselage cross sections [m].
y_cs = [5, 6, 7];    % Y-coord. of desired wing     cross sections [m].
AL   = D.AeroLoads;  % Extract the AeroLoads table, just for conciseness.

% TODO: add sanity checks on x_cs and y_cs values.

% Fuselage specs.
%
% Geometry.
L_fus = 4;  % Rear fuselage length [m].
a = 1.3;    % Ellipse major axis [m].
b = 1.1;    % Ellipse minor axis [m].
x_start = D.Comp{"Wings", "COG"}(1);  % X-coord of rear fuselage start [m].
x_end   = x_start + L_fus;            % X-coord of rear fuselage end [m].
x_sectrans = x_end - 2;               % X_coord where ellipse become circle [m].
surface = integral(@fuselage_perimeter, x_start, x_end, 'ArrayValued', true);  % Surface of the rear fuselage [m²].
% Mechanical properties.
W_fus = 0.5 * D.Plane.MTOW * C.g * 0.064;  % Rear fuselage weight [N]. (See slide 28.)
w_end = fuselage_linweight(x_end);         % Aft fuselage linear weight [N/m].

% Wings specs.

% The return value consists of two tables that contains the MNT in the
% selected fuselage and wing cross sections, for al the CP.
FuselageLoads = table( ...
	'Size', [height(AL) * numel(x_cs), 8], ...
	'VariableNames', {'x',      'n',      'EAS',    'Ty',     'Tz',     'My',     'Mz',     'Mx'}, ...
	'VariableTypes', {'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'});
WingsLoads = table( ...
	'Size', [height(AL) * numel(y_cs), 8], ...
	'VariableNames', {'y',      'n',      'EAS',    'Ty',     'Tz',     'My',     'Mz',     'Mx'}, ...
	'VariableTypes', {'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'});

% Determine MNT in the selected fuselage and wing cross sections.
% TODO: invert the loop nesting.
nrow = 1;
for x = x_cs
	for idx = 1:height(AL)
		al = AL(idx, :);
		FuselageLoads(nrow, :) = fuselage_loads(al, x);
		nrow = nrow + 1;
	end
end

disp(FuselageLoads);

%% Fuselage loads

	function loads = fuselage_loads(al, x)
		% FUSELAGE_LOADS  Loads on a fuselage cross section.

		% Angle of incidence of the plane [°].
		aoi = al.aoa - D.Wing.aoi;
		% Fuselage linear weight at cross section [N/m].
		w_x = fuselage_linweight(x);
		% Length from cross section to aft [m].
		L_rear = x_end - x;
		% Distance from HT to cross section.
		L_HT2cs = D.Comp{"Horizontal tail", "COG"}(1) - x;

		% Select the components that lies after the cross-section.
		comp = D.Comp(D.Comp.COG(:, 1) > x, :);
		% Retrieve their weights [N] and lever arms [m].
		larms   = comp.COG(:, 1) - x;
		weights = - comp.Mass * C.g;

		% Self weight of the fuselage is a trapezoïdal linear load.
		% We decompose it into a triangular linear load q1 and a constant
		% linear load q2.
		%
		% Equivalent loads Q1 and Q2 [N].
		Q1 = - w_end * L_rear;
		Q2 = -(w_x - w_end) * L_rear;
		% Equivalent lever arms [m].
		L1 = 1/3 * L_rear;
		L2 = 1/2 * L_rear;

		% Vertical dynamic equilibrium.
		F = al.n * (sum(weights) + Q1 + Q2);
		% Y-moments equilibrium.
		M = al.n * cosd(aoi) * (sum(weights.*larms) + Q1*L1 + Q2*L2);

		% TODO: double check signs.
		Ty = -al.F_fin;
		Tz = (F + al.P) * cosd(aoi);
		My = M + al.P * L_HT2cs * cosd(aoi);
		Mz = al.F_fin * L_HT2cs;
		Mx = -al.M_fus;  % See aero_loads.m: we don't take M_tail into account.

		loads = table(x, al.n, al.EAS, Ty, Tz, My, Mz, Mx);

	end

	function perim = fuselage_perimeter(x)
		% FUSELAGE_PERIMETER  Perimeter of the fuselage along X-axis.
		%
		% Argument:
		%   x (double) -- X coordinate [m].
		% Return:
		%   perim (double) -- Perimeter [m].
		%
		% TODO: wait for precise fuselage geometrical specs.

		if x <= x_sectrans
			% Perimeter of an ellipe [m].
			perim = 2*pi * sqrt((a/2)^2 + (b/2)^2 / 2);
		else
			% Circle diameter [m].  TODO: add taper from ellipse to aft.
			d = 0.9;
			% Perimeter of a circle [m].
			perim = pi * d;
		end
	end

	function w = fuselage_linweight(x)
		% FUSELAGE_LINWEIGHT  Linear weight of the fuselage along X-axis.
		%
		% Argument:
		%   x (double) -- X coordinate [m].
		% Return:
		%   w (double) -- Weight per unit length [N/m].
		%
		% TODO: wait for precise fuselage specs.

		% Perimeter of the rear fuselage at x [m].
		perim = fuselage_perimeter(x);

		w = W_fus * perim / surface;
	end

%% Wings loads

% 	function wings_loads(n, y)
% 		% WINGS_LOADS  Loads on a wing cross section.
% 
% 		W_Wing = 1/2 * mass_wing * C.g;
% 		x_pos_Wing = pos(1);
% 		z_pos_Wing = z_pos(1);
% 		y_pos_Wing = y_bar_w;
% 
% 		W_fuel = 1/2 * W_fuel_w * C.g;
% 		x_pos_fuel = pos(1);
% 		z_pos_fuel = z_pos(1);
% 		y_pos_fuel = y_bar_w;
% 
% 		W_hyd = 1/2*W_hyd_w*C.g;
% 		x_pos_hyd = pos(1);
% 		z_pos_hyd = z_pos(1);
% 		y_pos_hyd = y_bar_w;
% 
% 		for i = 1:length(V_points)
% 			SW_x(i) = (n_points(i)*(W_Wing + W_fuel + W_hyd) - result_L_w(i)/2)*sin(result_alpha(i)) + D_w(i)*cos(result_alpha(i));
% 			SW_y(i) = 0;
% 			SW_z(i) = (-n_points(i)*(W_Wing + W_fuel + W_hyd) + result_L_w(i)/2)*cos(result_alpha(i)) + D_w(i)*sin(result_alpha(i));
% 
% 			BM_x(i) = (-n_points(i)*(W_Wing*y_pos_Wing + W_fuel*y_pos_fuel + W_hyd*y_pos_hyd) - result_L_w(i)/2*y_pos_Wing)*cos(result_alpha(i)) + D_w(i)*y_pos_hyd*sin(result_alpha(i));
% 			BM_y(i) = (-n_points(i)*(W_Wing*x_pos_Wing + W_fuel*x_pos_fuel + W_hyd*x_pos_hyd) - result_L_w(i)/2*x_pos_Wing + D_w(i)/2*x_pos_Wing)*cos(result_alpha(i)) + (-n_points(i)*(W_Wing*z_pos_Wing + W_fuel*z_pos_fuel + W_hyd*z_pos_hyd) - result_L_w(i)/2*z_pos_Wing - D_w(i)/2*z_pos_Wing)*sin(result_alpha(i));
% 			BM_z(i) = (-n_points(i)*(W_Wing*y_pos_Wing + W_fuel*y_pos_fuel + W_hyd*y_pos_hyd) - result_L_w(i)/2*y_pos_Wing)*sin(result_alpha(i)) - D_w(i)*y_pos_hyd*cos(result_alpha(i));
% 		end
% 	end
end
