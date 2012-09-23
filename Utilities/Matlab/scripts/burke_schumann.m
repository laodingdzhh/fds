%-----------------------
% C Weinschenk
% Verification of Mixture Fraction (Species,Temp,Pres)
% Fuel: Methane
% 9/2012
%-----------------------

clear all
close all

addpath('../../Verification/Species/')

%-----------------------
% Read in FDS Data File
%-----------------------

if ~exist('Burke_Schumann_devc.csv')
    display(['Error: File ../../Verification/Species/Burke_Schumann_devc.csv does not exist. Skipping case.'])
    return
end
Burke_Schumann_Data=importdata('Burke_Schumann_devc.csv');
burke(:,:)=Burke_Schumann_Data.data; % data

for i=1:15
    temperature(:,i) = burke(:,11*i-9)+273.15; % temperature [K]
    rho(:,i) = burke(:,11*i-8);                % density [kg/m^3]  
    h(:,i) = burke(:,11*i-7);                  % specific enthalpy [kJ/kg]
    hrrpuv(:,i)=burke(:,11*i-6);               % heat release rate per unit volume [kW]
    pressure(:,i) = burke(:,11*i-5)+101325;    % abolute pressure [Pa]
    mix_frac(:,i) = burke(:,11*i-4);           % mixture fraction
    o2(:,i) = burke(:,11*i-3);                 % mass fraction o2
    ch4(:,i) = burke(:,11*i-2);                % mass fraction ch4
    h2o(:,i) = burke(:,11*i-1);                % mass fraction h2o
    co2(:,i) = burke(:,11*i);                  % mass fraction co2
    n2(:,i) = burke(:,11*i+1);                 % mass fraction n2
end

n2_o2_ratio = n2(1,1)/o2(1,1);                 % initial o2/n2 ratio

for i=1:length(mix_frac)
    ox(:,i) = o2(:,i) + n2_o2_ratio*o2(:,i);   % O2 plus N2 that started with O2
    prod(:,i) = h2o(:,i) + co2(:,i) + (n2(:,i)-n2_o2_ratio*o2(:,i)); % CO2 + H2O + N2 in products
end

%-----------------------
% Calculate Expected Species and Temperature Profiles
%-----------------------

volume = 0.001;                   % volume of each "reactor" [m^3]
temp_0 = temperature(1,1);        % initial temperature [K]
density = rho(1,5);               % stoichiometric density [kg/m^3]
R = 8.3145;                       % gas constnat [J/mol K]
mass = density * volume;          % mass [kg]

%-------------
% vector key
% (1) = nitrogen
% (2) = methane
% (3) = oxygen
% (4) = carbon dioxide
% (5) = water vapor
%-------------

y_MW = [28.0134; 16.042460; 31.9988; 44.0095; 18.015280];         % molecular weight [g/mol]
y_hf = [0.0; -74873; 0.0; 0.0; 0.0];                              % heat of formation all zero except fuel [J/mol]
yf0 = [n2(1,5); ch4(1,5); o2(1,5); co2(1,5); h2o(1,5)];           % intial mass fractions @ stoichiometric
N0 = (1000*volume*density*yf0)./(y_MW);                           % initial moles @ stoichiometric  
yff = [n2(end,5); ch4(end,5); o2(end,5); co2(end,5); h2o(end,5)]; % final mass fractions
Nf = (1000*volume*density*yff)./(y_MW);                           % final moles

hc = -y_hf(2)/y_MW(2)*1000;  % heat of combustion [J/kg]
cp = 1000;                   % specific heat [J/kg/K] set constant for all species

mean_mw_f = sum(y_MW.*(Nf./sum(Nf))); % mole average molecular weight
Rf = sum(R./mean_mw_f)*1000;          % ideal gas constant [J/kg/K]
k = (1-(Rf/cp))^(-1);
%k=1.3;

%-----------------------
% Calculate State Relationships
%-----------------------
z_st = yf0(2);
f = mix_frac(1,:);

for i =1:length(f)
    if f(i) > z_st && f(i) <= 1
        Yf(i)     = (f(i)-z_st)/(1-z_st);
        Yo2(i)    = 0;
        Yp(i)     = (1-f(i))/(1-z_st);
        T_calc(i) = f(i)*(-(z_st/(1-z_st))*(hc/cp))+temp_0+(z_st)/((1-z_st)*cp)*hc;
    elseif f(i) >= 0 && f(i) < z_st
        Yf(i)     = 0;
        Yo2(i)    = 1 - f(i)/z_st;
        Yp(i)     = f(i)/z_st;
        T_calc(i) = f(i)*((hc)/(cp))+temp_0;
    else
        Yf(i)     = 0;
        Yo2(i)    = 0;
        Yp(i)     = 1;
        T_calc(i) = yf0(2)*(hc/cp)+temp_0;
    end
end

T_calc_norm = (T_calc-temp_0)./(T_calc(5)-temp_0);                          % normalized expected temperature
TF_fds = (temperature(end,:)).*(pressure(1,:)./pressure(end,:)).^((k-1)/k); % corrected temperature due to constant volume
FDS_temp_norm = (TF_fds-temp_0)./(T_calc(5)-temp_0);                        % normalized FDS temperature

%------------------------------------------------
% Write FDS and Expected Data to CSV Files
%------------------------------------------------

for i=1:length(mix_frac)
    burke_expected(i,1) = mix_frac(1,i);
    burke_expected(i,2) = T_calc_norm(i);
    burke_expected(i,3) = Yf(i);
    burke_expected(i,4) = Yo2(i);
    burke_expected(i,5) = Yp(i);
end

header1 = {'Mixture_Fraction','Temperature','Fuel','Ox','Prod'};
filename1 = '../../Verification/Species/Burke_Schumann_Expected.csv';
fid = fopen(filename1,'wt');
fprintf(fid,'%s, %s, %s, %s, %s\n',header1{:});
for j=1:length(mix_frac)
    fprintf(fid,'%f, %f, %f, %f, %f\n',burke_expected(j,:));
end
fclose(fid);

for i=1:length(mix_frac)
    burke_FDS(i,1) = mix_frac(1,i);
    burke_FDS(i,2) = FDS_temp_norm(i);
    burke_FDS(i,3) = ch4(end,i);
    burke_FDS(i,4) = ox(end,i);
    burke_FDS(i,5) = prod(end,i);
end

header1 = {'Mixture_Fraction','FDS_Temperature','FDS_Fuel','FDS_Ox','FDS_Prod'};
filename1 = '../../Verification/Species/Burke_Schumann_FDS.csv';
fid = fopen(filename1,'wt');
fprintf(fid,'%s, %s, %s, %s, %s\n',header1{:});
for j=1:length(mix_frac)
    fprintf(fid,'%f, %f, %f, %f, %f\n',burke_FDS(j,:));
end
fclose(fid);