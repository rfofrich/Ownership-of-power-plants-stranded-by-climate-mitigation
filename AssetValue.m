%Asset value
%
%Created Aug 14 2024
%by Robert Fofrich Navarro
%
%Calculates corporate asset value and assigns values to power plant parent company
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for ii  = 1% sets fuel %1 COAL,2 GAS, 3 OIL, 4 Combined
clearvars -except ii; close all

section = 9;%section 7 must be set to ii = 4
%1 = aggregawtion of 'Plants' matrix containing plant info
%2 = Figure - carbon prices closure rates
%3 = Asset and stranded asset calculations
%4 = Figure - Annual Stranded Assets
%5 = Figure - pie charts
%6 = HHI calculations
%7 = IGNORE SECTION!!! (Figure, maps)
%8 = IGNORE SECTION!!!
%9 = Figure, stranded asset, annual emissions, annual revenue
%10 = Figure ,lorenze curve (replace section 6 with this code)
%11 = sensitivity test 
%12 = Emissions per stranded assets
%13 = reduction in cf as cost increase
%14 = plot stranded assets comparisons
TJ_to_BTu = 1/(9.478*1e8);
Kg_CO2_to_t_C02 = 1/1000;
BTu_perKWh_to_BTu_perMWh = 1000;

max_marker_size = 3000;
min_marker_size = 200; 

FUEL = ii;

PowerPlantFuel = ["Coal", "Gas", "Oil"];
saveyear = 0;%saves decommission year; any other number loads decommission year
saveresults = 1;
randomsave = 1;%set to 1 to save MC randomization; zero value  loads MC randomization - section 11 only

%works with section 6
COUNTRY = 1; %1 United States, 3 china, 4 europe, 9 india


if FUEL <4
    CombineFuelTypeResults = 0;
elseif FUEL >3
    CombineFuelTypeResults = 1;
end

current_year = 2024;
cutoffyear = 2035;%follows the index for carbontaxyear vector
CarbonPrice = 2000;%$/tCO2
CarbonTaxYear = current_year:2100;%sets the year for which the carbon tax is at its maximum

[ Dateindx] = find(CarbonTaxYear == cutoffyear);

StartYear = 1900;
EndYear = current_year;
Year = StartYear:EndYear;

RetailtoWholesaleConversionFactor = 1;%assumption

%Median PowerPlant Costs and Life from IPCC AR5 WGIII
%(https://www.ipcc.ch/site/assets/uploads/2018/02/ipcc_wg3_ar5_annex-iii.pdf)
%Power plant life
 
interest_rate_construction = .05; % interest rate over the construction loan (set as 5%)
DiscountRate = .1; %rate used by IEA 2020 report, 7% is in a highly regulated market, and 10% is in an environment with high risks

mean_Life_coal = 40;
Variable_OM_coal = 3.4;% $/MWh
Fixed_OM_coal = 23*1000;% $/MW
Construction_period_coal = 6; 
Capital_costs_coal = 2200*1000;% $/MW
Fuel_costs_coal = 4.1/3.6; % $/MWh
alpha_coal = DiscountRate/(1-(1+DiscountRate).^-mean_Life_coal);% percent
eta_coal = .39;% percent
Investment_costs_coal = (Capital_costs_coal/mean_Life_coal)*sum((1+interest_rate_construction)*(1+(0/(1+DiscountRate).^mean_Life_coal)));

mean_Life_gas = 30;
Variable_OM_gas = 3.2;% $/MWh
Fixed_OM_gas = 7*1000;% $/MW
Construction_period_gas = 4; 
Capital_costs_gas = 1100*1000;% $/MW
Fuel_costs_gas = 8.9*3.6; % $/MWh
alpha_gas = DiscountRate/(1-(1+DiscountRate).^-mean_Life_gas);% percent
eta_gas = .55;% percent
Investment_costs_gas = (Capital_costs_gas/mean_Life_gas)*sum((1+interest_rate_construction)*(1+(0/(1+DiscountRate).^mean_Life_gas)));

%Power plant ranges
LifeTimeRange = 20:5:60; 
CapacityFactorRange = .25:.05:.75;
AnnualHours = 8760;

%plus/minus age
Age_span = 20;% Power plant age range

%plus/minus CF
CF_span = .25;% Power plant capacity factor range
if FUEL == 1
    years = 2021:(current_year + mean_Life_coal);
elseif FUEL == 2
    years = 2021:(current_year + mean_Life_gas);
end

OnshoreWind_price1981 = .31;
OnshoreWind_price2020 = .05;

OffshoreWind_price2000 = .12;
OffshoreWind_price2020 = .12;

SolarPV_price2010 = .38;
SolarPV_price2020 = .07;

ThermalSolar_price2010 = .35;
ThermalSolar_price2020 = .18;
 
AverageRenewablePriceHistorical = (OnshoreWind_price1981 + OffshoreWind_price2000 + SolarPV_price2010 + ThermalSolar_price2010)/4;
AverageRenewablePriceModern = (OnshoreWind_price2020 + OffshoreWind_price2020 + SolarPV_price2020 + ThermalSolar_price2020)/4;


if section == 1%aggregates power plant companies 
    Country = readcell('../Data/Countries.xlsx');
    O_M_costs = readcell('../Data/O_M_costs_of_new_power_ US_by_technology 2020.xlsx');
    Wholesale_Electricity_Costs_strings = readcell('../Data/PriceOfElectricity_Worldbank.xlsx');
    Wholesale_Electricity_Costs = xlsread('../Data/PriceOfElectricity_Worldbank.xlsx');
    Wholesale_Electricity_Costs = Wholesale_Electricity_Costs(2:end,7)*1000./100;%retrieves data and converts it from cents/KWh and to U.S. dollars/MWh

    PowerPlantParentCompany = {};
    PowerPlantCompanyOwnerStakePercentage = [];


    for i = 2:length(Wholesale_Electricity_Costs_strings)
        Wholesale_Electricity_Costs_Country_strings{i-1,1} = upper(Wholesale_Electricity_Costs_strings{i,1});%converts lower case strings to upper case for strcmpi to work
    end
    
    for gentype = FUEL
            clear Plants

            if FUEL == 1
                power_company_info = readcell(['../Data/New_power_data/Global-' PowerPlantFuel{gentype} '-Plant-Tracker-April-2024-Supplement-Proposals-outside-of-China.xlsx'], 'Sheet', 'Parent_company');
                power_operating_info = readcell(['../Data/New_power_data/Global-' PowerPlantFuel{gentype} '-Plant-Tracker-April-2024-Supplement-Proposals-outside-of-China.xlsx'], 'Sheet', 'Units');
                power_operating_info = power_operating_info(2:end,1:12);
            elseif FUEL == 2
                power_company_info = readcell('../Data/New_power_data/Global-Oil-and-Gas-Plant-Tracker-GOGPT-February-2024-v4.xlsx', 'Sheet', 'Parent_company');
                power_operating_info = readcell('../Data/New_power_data/Global-Oil-and-Gas-Plant-Tracker-GOGPT-February-2024-v4.xlsx', 'Sheet', 'Units');
                power_operating_info = power_operating_info(2:end,1:12);
            end

            NamePlate = [];
            Plant_age = [];
            Capacity_factor = [];
            Annual_CO2 = [];
            Countries = [];
            Operating_status = [];
            Start_year = [];
            Planned_decommission = [];
            Heat_rate = [];
            Emission_factor =[];

            [numRows, numCols] = size(power_company_info);

            for row = 1:numRows
                for col = 1:numCols
                    cellValue = power_company_info{row, col};
                    
                    % Ensure the cell value is a string
                    if ischar(cellValue) || isstring(cellValue)
                        cellValue = string(cellValue);
            
                        % Skip blank cells
                        if isempty(cellValue) || all(isspace(cellValue))
                            continue;
                        end
                        
                        % Extract the string part
                        if contains(cellValue, '[')
                            stringPart = extractBefore(cellValue, '[');
                        else
                            stringPart = cellValue;
                        end
                        stringPart = strtrim(stringPart);
                        
                        % Check if there is a value part
                        if contains(cellValue, '[') && contains(cellValue, ']')
                            % Extract the numeric value part
                            try
                                valueStr = extractBetween(cellValue, '[', ']');
                                valueStr = strrep(valueStr{1}, '%', '');
                                value = str2double(valueStr);
                                if isnan(value)
                                    error('Failed to convert value to numeric');
                                end
                            catch
                                % Handle errors in value extraction
                                disp(['Error extracting value from: ' cellValue]);
                                value = NaN; % Or assign a default value
                            end
                        else
                            % remove if ownership value isn't present
                            value = 0;
                        end
    
                        % Section ensures only operating and plants under construction are counted
                        % if strcmpi(power_operating_info{row, 3}, 'operating') || strcmpi(power_operating_info{row, 3}, 'construction')
                            PowerPlantParentCompany{end+1} = stringPart;
                            PowerPlantCompanyOwnerStakePercentage(end+1) = value;
                            NamePlate(end+1) = power_operating_info{row,2};
                            Start_year(end+1) = power_operating_info{row,4};
                            Plant_age(end+1) = power_operating_info{row,6};
                            Capacity_factor(end+1) = power_operating_info{row,7};
                            Annual_CO2(end+1) = power_operating_info{row,8};
                            Countries{end+1} = power_operating_info{row, 1};
                            Operating_status{end+1} = power_operating_info{row, 3};
                            Planned_decommission(end+1) = power_operating_info{row,5};
                            if FUEL == 1
                                Heat_rate(end+1) = (power_operating_info{row,11}*BTu_perKWh_to_BTu_perMWh);% converts from BTU/kWh to BTU/MWh
                                Emission_factor(end+1) = power_operating_info{row,12};% kg CO2/TJ
                            elseif FUEL == 2
                                Emission_factor(end+1) = power_operating_info{row,11};% tCO2 eq/MWh
                            end
                        % end
                    end
                end
            end

            PowerPlantParentCompanys = standardizeCompanyNames(cellstr(PowerPlantParentCompany));
            PowerPlantParentCompany = PowerPlantParentCompanys;

            Plant_age = current_year - Start_year;
            Plant_age(isnan(Plant_age) | Plant_age < 0) = 0; % Assumes underconstruction plants are immediately built to start counting these emissions towards stranded assets

            Plants = [NamePlate', Plant_age', Capacity_factor', Annual_CO2', PowerPlantCompanyOwnerStakePercentage'];
            Plants_string = [string(PowerPlantParentCompany'), string(Countries'),string(Operating_status')];

            % Plants_2 = [];
            % Plants_string_2 = strings(0, 3);
            % Planned_decommission_2 = [];
            % for power_plant = 1:length(Plants)
            %     if strcmpi(Plants_string{power_plant, 3}, 'operating') || strcmpi(Plants_string{power_plant, 3}, 'construction')
            %         Plants_2(end+1, :) = Plants(power_plant, :);
            %         Plants_string_2(end+1, :) = Plants_string(power_plant, :);
            %         Planned_decommission_2(end+1) =Planned_decommission(power_plant);
            %     end
            % end
            % 
            % Plants = Plants_2;
            % Plants_string = Plants_string_2;
            % Planned_decommission = Planned_decommission_2;

            for power_plant = 1:length(Plants)
                if strcmpi(Plants_string{power_plant, 3}, 'operating') || strcmpi(Plants_string{power_plant, 3}, 'construction')
                    Plants(power_plant, :) = Plants(power_plant, :);
                    if FUEL == 1
                        Heat_rate(power_plant) = Heat_rate(power_plant);
                    end
                    Emission_factor(power_plant) = Emission_factor(power_plant);
                    % Plants_string{power_plant, :} = Plants_string{power_plant, :};
                else
                    % Set the plant data to NaN if it's neither 'operating' nor 'construction'
                    Plants(power_plant, :) = nan;
                    Planned_decommission(power_plant) = nan;
                    if FUEL == 1
                        Heat_rate(power_plant) = nan;
                    end
                    Emission_factor(power_plant) = nan;
                    % Plants_string{power_plant, :} = {''};
                end
            end


            CapitalCosts_strings = readcell('../Data/Capital_costs_Data_Power_sectors.xlsx');
            CapitalCosts = xlsread('../Data/Capital_costs_Data_Power_sectors.xlsx');


            if gentype == 1

                CapitalCosts = CapitalCosts(4,4:end);
          
                MIN = round(nanmean(CapitalCosts)-nanmean(CapitalCosts)*.2);
                MAX = round(nanmean(CapitalCosts)+nanmean(CapitalCosts)*.2);
                 for powerplant = 1:length(Plants)
                    if Plants(powerplant,2) <=15
                        Plants(powerplant,6) = randi([MIN MAX])*1000;%$/MW
                    elseif Plants(powerplant,2) > 15
                        Plants(powerplant,6) = 0;
                    end
                end
               
                WholeSaleCostofElectricity = nan(length(Plants_string),40);%sets wholesale price of electricity
                for powerplant = 1:length(Plants_string)
                    PowerPlant_country = Plants_string{powerplant, 2};
                    for country = 1:length(Wholesale_Electricity_Costs_Country_strings)
                        Electricity_cost_country = Wholesale_Electricity_Costs_Country_strings{country, 1};
                        if strcmpi(PowerPlant_country, Electricity_cost_country)
                            WholeSaleCostofElectricity(powerplant,1:40) = [Wholesale_Electricity_Costs_strings{country, 11}];%Wholesale electricity $ cost per MWh (last column is averaged across years and converted to MWh from KWh)
                        end
                    end
                end

                for powerplant = 1:length(Plants_string)
                    if isnan(WholeSaleCostofElectricity(powerplant,1))
                        WholeSaleCostofElectricity(powerplant,1:40) = Wholesale_Electricity_Costs(end,1);%Wholesale electricity $ cost per MWh
                    end
                end

               
                save('../Data/WholeSaleCostofElectricityCoal','WholeSaleCostofElectricity');
                FuelCosts = readmatrix(['../Data/CoalCosts2.xlsx']);%$ Cost of per unit fuel
                Fuel_strings = readcell('../Data/CoalCosts2.xlsx');
                Fuel_strings = Fuel_strings(:,1:2);
    


                for i = 2:length(FuelCosts)
                    for j = 4:76
                        if isnan(FuelCosts(i,j)) && ~isnan(FuelCosts(i,j-1))
                            FuelCosts(i,j) = FuelCosts(i,j-1);
                        end
                    end
                end


                oprcounter = 1;

                for i = 2:length(Fuel_strings)
                    FuelCost_strings{oprcounter,1} = upper(Fuel_strings{i,1});
                    oprcounter = oprcounter + 1;
                end

                F_Costs = nan(length(Plants_string),40);
                for powerplant = 1:length(Plants_string)
                    for country = 1:length(FuelCost_strings)
                        if strcmpi(Plants_string{powerplant,2},FuelCost_strings{country,1})
                           F_Costs(powerplant,1:40) = FuelCosts(country,22:61);%Costs of fuel per short ton 
                        end
                    end
                end

                for powerplant = 1:length(Plants_string)
                    if isnan(F_Costs(powerplant,1))
                        F_Costs(powerplant,1:40) = FuelCosts(2,22:61);
                    end
                end


                for powerplant = 1:length(Plants)
                    Plants(powerplant,7) = 8.14;%conversion factor for short ton to MWh
                end


                for powerplant = 1:length(Plants)
                    Plants(powerplant,8) = 40.79*1000;%O&M fixed costs per year $/MW
                end

                colorschemecategory = zeros(length(Plants),1);
                for region = 1:5
                    if region == 1%OECD
                        CountryNames = {'Albania', 'Australia', 'Austria', 'Belgium', 'Bosnia-Herzegovina', 'Bulgaria', 'Canada',...
                            'Croatia', 'Cyprus', 'Czech Republic', 'Denmark', 'Estonia', 'Finland', 'France', 'Germany', 'Greece', 'Guam', 'Hungary',...
                            'Iceland', 'Ireland', 'Italy', 'Latvia', 'Lithuania', 'Luxembourg', 'Malta', 'Montenegro', 'Netherlands', 'New Zealand',...
                            'Norway', 'Poland', 'Portugal', 'Puerto Rico', 'Romania', 'Serbia', 'Slovakia', 'Slovenia', 'Spain', 'Sweden', 'Switzerland', ...
                            'North Macedonia', 'Türkiye', 'United Kingdom', 'United States','ENGLAND & WALES','Scotland','Ireland'};
                        CountryNames = upper(CountryNames)';
                        for powerplant = 1:length(Plants)
                            for Names = 1:length(CountryNames)
                                if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                    Plants(powerplant,12) = region;
                                    colorschemecategory(powerplant) = 4;
                                    if strcmpi(Plants_string{powerplant,2},'UNITED KINGDOM') || strcmpi(Plants_string{powerplant,2},'ENGLAND & WALES')...
                                            || strcmpi(Plants_string{powerplant,2},'SCOTLAND') || strcmpi(Plants_string{powerplant,2},'IRELAND')
                                        colorschemecategory(powerplant) = 4;
                                    elseif strcmpi(Plants_string{powerplant,2},'United States') 
                                        colorschemecategory(powerplant) = 1;
%                                     elseif strcmpi(Plants_string{powerplant,2},'JAPAN') 
%                                         colorschemecategory(powerplant) = 2;
                                    elseif strcmpi(Plants_string{powerplant,2},'AUSTRALIA') || strcmpi(Plants_string{powerplant,2},'NEW ZEALAND')...
                                            || strcmpi(Plants_string{powerplant,2},'CANADA') 
                                        colorschemecategory(powerplant) = 8;
                                    end
                                end
                            end
                        end
                    elseif region == 2%REF
                        CountryNames = {'Armenia', 'Azerbaijan', 'Belarus', 'Georgia', 'Kazakhstan', 'Kyrgyzstan', 'Moldova', 'Russia', ...
                            'Tajikistan', 'Turkmenistan', 'Ukraine', 'Uzbekistan'};
                        CountryNames = upper(CountryNames)';
                        for powerplant = 1:length(Plants)
                            for Names = 1:length(CountryNames)
                                if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                    Plants(powerplant,12) = region;
                                    colorschemecategory(powerplant) = 7;
                                end
                            end
                        end
                    elseif region == 3%Asia
                        CountryNames = {'Afghanistan', 'Bangladesh', 'Bhutan', 'Brunei', 'Cambodia', 'China', 'North Korea', 'Fiji', 'French Polynesia','India' ...
                            'Indonesia', 'Laos', 'Malaysia', 'Maldives', 'Micronesia', 'Mongolia', 'Myanmar', 'Nepal',' New Caledonia', 'Pakistan', 'Papua New Guinea',...
                            'Philippines', 'South Korea', 'Samoa', 'Singapore','JAPAN', 'Solomon Islands', 'Sri Lanka', 'Taiwan', 'Thailand', 'Timor-Leste', 'Vanuatu', 'Vietnam'};
                        CountryNames = upper(CountryNames)';
                        for powerplant = 1:length(Plants)
                            for Names = 1:length(CountryNames)
                                if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                    Plants(powerplant,12) = region;
                                    colorschemecategory(powerplant) = 6;
                                    if strcmpi(Plants_string{powerplant,2},'CHINA')
                                        colorschemecategory(powerplant) = 3;
                                    elseif strcmpi(Plants_string{powerplant,2},'INDIA')
                                        colorschemecategory(powerplant) = 9;    
                                    end
                                end
                            end
                        end
                    elseif region == 4%MAF
                        CountryNames = {'Algeria', 'Angola','Bahrain', 'Benin', 'Botswana', 'Burkina Faso', 'Burundi', 'Cameroon', 'Cape Verde', 'Central African Republic',...
                            'Chad', 'Comoros', 'Congo', 'Cote dIvoire', 'Congo', 'Djibouti', 'Egypt', 'Equatorial Guinea', 'Eritrea', 'Ethiopia', ...
                            'Gabon', 'Gambia', 'Ghana', 'Guinea', 'Guinea-Bissau', 'Iran', 'Iraq', 'Israel', 'Jordan', 'Kenya', 'Kuwait', 'Lebanon', 'Lesotho', 'Liberia', ...
                            'Libya', 'Madagascar', 'Malawi', 'Mali', 'Mauritania', 'Mauritius', 'Mayotte', 'Morocco', 'Mozambique', 'Namibia', 'Niger', 'Nigeria', 'Palestine', ...
                            'Oman', 'Qatar', 'Rwanda', 'Reunion', 'Saudi Arabia', 'Senegal', 'Sierra Leone', 'Somalia', 'South Africa', 'South Sudan', 'Sudan', 'Swaziland',...
                            'Syria', 'Togo', 'Tunisia', 'Uganda', 'United Arab Emirates', 'Tanzania', 'Western Sahara', 'Yemen', 'Zambia', 'Zimbabwe'};
                        CountryNames = upper(CountryNames)';
                        for powerplant = 1:length(Plants)
                            for Names = 1:length(CountryNames)
                                if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                    Plants(powerplant,12) = region;
                                    colorschemecategory(powerplant) = 5;
                                end
                            end
                        end  
                    elseif region == 5%LAM
                        CountryNames = {'Argentina', 'Aruba', 'Bahamas', 'Barbados', 'Belize', 'Bolivia', 'Brazil', 'Chile', 'Colombia', 'Costa Rica', 'Cuba', 'Dominican Republic',...
                            'Ecuador', 'El Salvador', 'French Guiana', 'Grenada', 'Guadeloupe', 'Guatemala', 'Guyana', 'Haiti', 'Honduras', 'Jamaica', 'Martinique', 'Mexico', 'Nicaragua',...
                            'Panama', 'Paraguay', 'Peru', 'Suriname', 'Trinidad and Tobago', 'United States Virgin Islands', 'Uruguay', 'Venezuela'};
                        CountryNames = upper(CountryNames)';
                        for powerplant = 1:length(Plants)
                            for Names = 1:length(CountryNames)
                                if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                    Plants(powerplant,12) = region;
                                    colorschemecategory(powerplant) = 2;
                                end
                            end
                        end  
                    end
                end
                        
                            
                               
                colorschemecategoryCoal = colorschemecategory;
                save('../Data/Results/CoalColors','colorschemecategoryCoal');

                if saveresults == 1
                    save('../Data/Results/Coal_Plants','Plants','Planned_decommission', 'Emission_factor', 'Heat_rate');
                    save('../Data/Results/Coal_Plants_strings','Plants_string');
                    save('../Data/Results/CoalCostbyCountry','F_Costs');
                end

            elseif gentype == 2
                CapitalCosts = CapitalCosts(7,4:end);
          
                MIN = round(nanmean(CapitalCosts)-nanmean(CapitalCosts)*.2);
                MAX = round(nanmean(CapitalCosts)+nanmean(CapitalCosts)*.2);
                 for powerplant = 1:length(Plants)
                    if Plants(powerplant,2) <=15
                        Plants(powerplant,6) = randi([MIN MAX])*1000;%$/MW
                    elseif Plants(powerplant,2) > 15
                        Plants(powerplant,6) = 0;
                    end
                end

                WholeSaleCostofElectricity = nan(length(Plants_string),40);%sets wholesale price of electricity
                for powerplant = 1:length(Plants_string)
                    PowerPlant_country = Plants_string{powerplant, 2};
                    for country = 2:length(Wholesale_Electricity_Costs_Country_strings)
                        Electricity_cost_country = Wholesale_Electricity_Costs_Country_strings{country, 1};
                        if strcmpi(PowerPlant_country, Electricity_cost_country)
                            WholeSaleCostofElectricity(powerplant,1:40) = [Wholesale_Electricity_Costs_strings{country, 11}];%Wholesale electricity $ cost per MWh (last column is averaged across years and converted to MWh from KWh)
                        end
                    end
                end
                
                for powerplant = 1:length(Plants_string)
                    if isnan(WholeSaleCostofElectricity(powerplant,1))
                        WholeSaleCostofElectricity(powerplant,1:40) = Wholesale_Electricity_Costs(end,1);%Wholesale electricity $ cost per MWh
                    end
                end
                save('../Data/WholeSaleCostofElectricityGas','WholeSaleCostofElectricity');

                FuelCosts = xlsread('../Data/NaturalGasCosts.xlsx');
                Fuel_strings = readcell('../Data/NaturalGasCosts.xlsx');    

                F_Costs = nan(length(Plants_string),40);
                for powerplant = 1:length(Plants_string)
                    for country = 1:length(Fuel_strings)
                        if strcmpi(Plants_string{powerplant,2},Fuel_strings{country,1})
                           F_Costs(powerplant,1:40) = FuelCosts(country,1);%Costs of fuel per short ton 
                        else
                            F_Costs(powerplant,1:40) = FuelCosts(end,1);%Costs of fuel per short ton 
                        end
                    end
                end

                oprcounter = 1;
                
                for i = 1:length(Fuel_strings)-3
                    FuelCost_strings{oprcounter,1} = upper(Fuel_strings{i,1});
                    oprcounter = oprcounter + 1;
                end


                for powerplant = 1:length(Plants)
                    Plants(powerplant,8) = 14.17*1000;%O&M fixed costs per year $/MW
                end

                Plants(Plants == 0) = FuelCosts(length(FuelCost_strings),1);%price per MWh

                for powerplant = 1:length(Plants)
                    Plants(powerplant,7) = 1;%conversion factor for gas  to MWh
                end

                for powerplant = 1:length(Plants)
                    Plants(powerplant,10) = 20*1000;%O&M fixed costs per year $/MW
                end
                
                % for powerplant = 1:length(Plants)
                %      Plants(powerplant,11) = Plants(powerplant,1) * mean_GasCF * AnnualHours * Plants(powerplant,3); %tons CO2 
                % end
                 
                
                colorschemecategory = zeros(length(Plants),1);
                for region = 1:5
                    if region == 1%OECD
                        CountryNames = {'Albania', 'Australia', 'Austria', 'Belgium', 'Bosnia-Herzegovina', 'Bulgaria', 'Canada',...
                            'Croatia', 'Cyprus', 'Czech Republic', 'Denmark', 'Estonia', 'Finland', 'France', 'Germany', 'Greece', 'Guam', 'Hungary',...
                            'Iceland', 'Ireland', 'Italy', 'Latvia', 'Lithuania', 'Luxembourg', 'Malta', 'Montenegro', 'Netherlands', 'New Zealand',...
                            'Norway', 'Poland', 'Portugal', 'Puerto Rico', 'Romania', 'Serbia', 'Slovakia', 'Slovenia', 'Spain', 'Sweden', 'Switzerland', ...
                            'North Macedonia', 'Türkiye', 'United Kingdom', 'United States','ENGLAND & WALES','Scotland','Ireland'};
                        CountryNames = upper(CountryNames)';
                        for powerplant = 1:length(Plants)
                            for Names = 1:length(CountryNames)
                                if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                    Plants(powerplant,12) = region;
                                    colorschemecategory(powerplant) = 4;
                                    if strcmpi(Plants_string{powerplant,2},'UNITED KINGDOM') || strcmpi(Plants_string{powerplant,2},'ENGLAND & WALES')...
                                            || strcmpi(Plants_string{powerplant,2},'SCOTLAND') || strcmpi(Plants_string{powerplant,2},'IRELAND')
                                        colorschemecategory(powerplant) = 4;
                                    elseif strcmpi(Plants_string{powerplant,2},'United States') 
                                        colorschemecategory(powerplant) = 1;
%                                     elseif strcmpi(Plants_string{powerplant,2},'JAPAN') 
%                                         colorschemecategory(powerplant) = 2;
                                    elseif strcmpi(Plants_string{powerplant,2},'AUSTRALIA') || strcmpi(Plants_string{powerplant,2},'NEW ZEALAND')...
                                            || strcmpi(Plants_string{powerplant,2},'CANADA') 
                                        colorschemecategory(powerplant) = 8;
                                    end
                                end
                            end
                        end
                    elseif region == 2%REF
                        CountryNames = {'Armenia', 'Azerbaijan', 'Belarus', 'Georgia', 'Kazakhstan', 'Kyrgyzstan', 'Moldova', 'Russia', ...
                            'Tajikistan', 'Turkmenistan', 'Ukraine', 'Uzbekistan'};
                        CountryNames = upper(CountryNames)';
                        for powerplant = 1:length(Plants)
                            for Names = 1:length(CountryNames)
                                if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                    Plants(powerplant,12) = region;
                                    colorschemecategory(powerplant) = 7;
                                end
                            end
                        end
                    elseif region == 3%Asia
                        CountryNames = {'Afghanistan', 'Bangladesh', 'Bhutan', 'Brunei', 'Cambodia', 'China', 'North Korea', 'Fiji', 'French Polynesia','India' ...
                            'Indonesia', 'Laos', 'Malaysia', 'Maldives', 'Micronesia', 'Mongolia', 'Myanmar', 'Nepal',' New Caledonia', 'Pakistan', 'Papua New Guinea',...
                            'Philippines', 'South Korea', 'Samoa', 'Singapore','JAPAN', 'Solomon Islands', 'Sri Lanka', 'Taiwan', 'Thailand', 'Timor-Leste', 'Vanuatu', 'Vietnam'};
                        CountryNames = upper(CountryNames)';
                        for powerplant = 1:length(Plants)
                            for Names = 1:length(CountryNames)
                                if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                    Plants(powerplant,12) = region;
                                    colorschemecategory(powerplant) = 6;
                                    if strcmpi(Plants_string{powerplant,2},'CHINA')
                                        colorschemecategory(powerplant) = 3;
                                    elseif strcmpi(Plants_string{powerplant,2},'INDIA')
                                        colorschemecategory(powerplant) = 9;    
                                    end
                                end
                            end
                        end
                    elseif region == 4%MAF
                        CountryNames = {'Algeria', 'Angola','Bahrain', 'Benin', 'Botswana', 'Burkina Faso', 'Burundi', 'Cameroon', 'Cape Verde', 'Central African Republic',...
                            'Chad', 'Comoros', 'Congo', 'Cote dIvoire', 'Congo', 'Djibouti', 'Egypt', 'Equatorial Guinea', 'Eritrea', 'Ethiopia', ...
                            'Gabon', 'Gambia', 'Ghana', 'Guinea', 'Guinea-Bissau', 'Iran', 'Iraq', 'Israel', 'Jordan', 'Kenya', 'Kuwait', 'Lebanon', 'Lesotho', 'Liberia', ...
                            'Libya', 'Madagascar', 'Malawi', 'Mali', 'Mauritania', 'Mauritius', 'Mayotte', 'Morocco', 'Mozambique', 'Namibia', 'Niger', 'Nigeria', 'Palestine', ...
                            'Oman', 'Qatar', 'Rwanda', 'Reunion', 'Saudi Arabia', 'Senegal', 'Sierra Leone', 'Somalia', 'South Africa', 'South Sudan', 'Sudan', 'Swaziland',...
                            'Syria', 'Togo', 'Tunisia', 'Uganda', 'United Arab Emirates', 'Tanzania', 'Western Sahara', 'Yemen', 'Zambia', 'Zimbabwe'};
                        CountryNames = upper(CountryNames)';
                        for powerplant = 1:length(Plants)
                            for Names = 1:length(CountryNames)
                                if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                    Plants(powerplant,12) = region;
                                    colorschemecategory(powerplant) = 5;
                                end
                            end
                        end  
                    elseif region == 5%LAM
                        CountryNames = {'Argentina', 'Aruba', 'Bahamas', 'Barbados', 'Belize', 'Bolivia', 'Brazil', 'Chile', 'Colombia', 'Costa Rica', 'Cuba', 'Dominican Republic',...
                            'Ecuador', 'El Salvador', 'French Guiana', 'Grenada', 'Guadeloupe', 'Guatemala', 'Guyana', 'Haiti', 'Honduras', 'Jamaica', 'Martinique', 'Mexico', 'Nicaragua',...
                            'Panama', 'Paraguay', 'Peru', 'Suriname', 'Trinidad and Tobago', 'United States Virgin Islands', 'Uruguay', 'Venezuela'};
                        CountryNames = upper(CountryNames)';
                        for powerplant = 1:length(Plants)
                            for Names = 1:length(CountryNames)
                                if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                    Plants(powerplant,12) = region;
                                    colorschemecategory(powerplant) = 2;
                                end
                            end
                        end  
                    end
                end
                                                       
              
                colorschemecategoryGas = colorschemecategory;
                save('../Data/Results/GasColors','colorschemecategoryGas');
                if saveresults == 1
                    save('../Data/Results/Gas_Plants','Plants','Planned_decommission', 'Emission_factor');
                    save('../Data/Results/Gas_Plants_strings','Plants_string');
                end
                save('../Data/Results/GasCostbyCountry','F_Costs');
            
            
            elseif gentype == 3
                CapitalCosts = CapitalCosts(10,4:end);
          
                MIN = round(nanmean(CapitalCosts)-nanmean(CapitalCosts)*.2);
                MAX = round(nanmean(CapitalCosts)+nanmean(CapitalCosts)*.2);
                 for powerplant = 1:length(Plants)
                    if Plants(powerplant,2) <=15
                        Plants(powerplant,6) = randi([MIN MAX])*1000;%$/MW
                    elseif Plants(powerplant,2) > 15
                        Plants(powerplant,6) = 0;
                    end
                end
                
                for powerplant = 2:length(CapitalCosts_strings)
                    if strcmpi(CapitalCosts_strings{powerplant,2},'Oil')
                        CapitalCosts_location{powerplant-1,:} = CapitalCosts_strings{powerplant,1};
                        FuelSpecific_CapitalCosts(powerplant-1,:) = CapitalCosts(powerplant-1,1);%in $/kw
                    end
                end

                MIN = round(nanmean(FuelSpecific_CapitalCosts)-nanmean(FuelSpecific_CapitalCosts)*.2);
                MAX = round(nanmean(FuelSpecific_CapitalCosts)+nanmean(FuelSpecific_CapitalCosts)*.2);
                for powerplant = 1:length(Plants)
                    if Plants(powerplant,2) <=15
                        Plants(powerplant,6) = randi([MIN MAX])*1000;%$/MW
                    elseif Plants(powerplant,2) > 15
                        Plants(powerplant,6) = 0;
                    end
                end

                WholeSaleCostofElectricity = nan(length(Plants_string),40);%sets wholesale price of electricity
                for powerplant = 1:length(Plants_string)
                    PowerPlant_country = Plants_string{powerplant, 2};
                    for country = 1:length(Wholesale_Electricity_Costs_Country_strings)
                        Electricity_cost_country = Wholesale_Electricity_Costs_Country_strings{country, 1};
                        if strcmpi(PowerPlant_country, Electricity_cost_country)
                            WholeSaleCostofElectricity(powerplant,1:40) = [Wholesale_Electricity_Costs_strings{country, 11}];%Wholesale electricity $ cost per MWh (last column is averaged across years and converted to MWh from KWh)
                        end
                    end
                end
                
                for powerplant = 1:length(Plants_string)
                    if isnan(WholeSaleCostofElectricity(powerplant,1))
                        WholeSaleCostofElectricity(powerplant,1:40) = Wholesale_Electricity_Costs(end,1);%Wholesale electricity $ cost per MWh
                    end
                end
                save('../Data/WholeSaleCostofElectricityOil','WholeSaleCostofElectricity');
                F_Costs = 47.45; 
%                 for powerplant = 1:length(Plants)
%                     Plants(powerplant,8) = 47.45;%price per barrel
%                 end

                for powerplant = 1:length(Plants)
                    Plants(powerplant,7) = 6004/3600;%conversion factor for barrel to MWh
                end

                for powerplant = 1:length(Plants)
                    Plants(powerplant,8) = 27.74*1000;%O&M fixed costs per year $/MW
                end
                
                 % for powerplant = 1:length(Plants)
                 %     Plants(powerplant,11) = Plants(powerplant,1) * mean_OilCF * AnnualHours * Plants(powerplant,3); %tons CO2 
                 % end
                 
                colorschemecategory = zeros(length(Plants),1);
                for region = 1:5
                    if region == 1%OECD
                        CountryNames = {'Albania', 'Australia', 'Austria', 'Belgium', 'Bosnia-Herzegovina', 'Bulgaria', 'Canada',...
                            'Croatia', 'Cyprus', 'Czech Republic', 'Denmark', 'Estonia', 'Finland', 'France', 'Germany', 'Greece', 'Guam', 'Hungary',...
                            'Iceland', 'Ireland', 'Italy', 'Latvia', 'Lithuania', 'Luxembourg', 'Malta', 'Montenegro', 'Netherlands', 'New Zealand',...
                            'Norway', 'Poland', 'Portugal', 'Puerto Rico', 'Romania', 'Serbia', 'Slovakia', 'Slovenia', 'Spain', 'Sweden', 'Switzerland', ...
                            'North Macedonia', 'Türkiye', 'United Kingdom', 'United States','ENGLAND & WALES','Scotland','Ireland'};
                        CountryNames = upper(CountryNames)';
                        for powerplant = 1:length(Plants)
                            for Names = 1:length(CountryNames)
                                if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                    Plants(powerplant,12) = region;
                                    colorschemecategory(powerplant) = 4;
                                    if strcmpi(Plants_string{powerplant,2},'UNITED KINGDOM') || strcmpi(Plants_string{powerplant,2},'ENGLAND & WALES')...
                                            || strcmpi(Plants_string{powerplant,2},'SCOTLAND') || strcmpi(Plants_string{powerplant,2},'IRELAND')
                                        colorschemecategory(powerplant) = 4;
                                    elseif strcmpi(Plants_string{powerplant,2},'United States') 
                                        colorschemecategory(powerplant) = 1;
%                                     elseif strcmpi(Plants_string{powerplant,2},'JAPAN') 
%                                         colorschemecategory(powerplant) = 2;
                                    elseif strcmpi(Plants_string{powerplant,2},'AUSTRALIA') || strcmpi(Plants_string{powerplant,2},'NEW ZEALAND')...
                                            || strcmpi(Plants_string{powerplant,2},'CANADA') 
                                        colorschemecategory(powerplant) = 8;
                                    end
                                end
                            end
                        end
                    elseif region == 2%REF
                        CountryNames = {'Armenia', 'Azerbaijan', 'Belarus', 'Georgia', 'Kazakhstan', 'Kyrgyzstan', 'Moldova', 'Russia', ...
                            'Tajikistan', 'Turkmenistan', 'Ukraine', 'Uzbekistan'};
                        CountryNames = upper(CountryNames)';
                        for powerplant = 1:length(Plants)
                            for Names = 1:length(CountryNames)
                                if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                    Plants(powerplant,12) = region;
                                    colorschemecategory(powerplant) = 7;
                                end
                            end
                        end
                    elseif region == 3%Asia
                        CountryNames = {'Afghanistan', 'Bangladesh', 'Bhutan', 'Brunei', 'Cambodia', 'China', 'North Korea', 'Fiji', 'French Polynesia','India' ...
                            'Indonesia', 'Laos', 'Malaysia', 'Maldives', 'Micronesia', 'Mongolia', 'Myanmar', 'Nepal',' New Caledonia', 'Pakistan', 'Papua New Guinea',...
                            'Philippines', 'South Korea', 'Samoa', 'Singapore','JAPAN', 'Solomon Islands', 'Sri Lanka', 'Taiwan', 'Thailand', 'Timor-Leste', 'Vanuatu', 'Vietnam'};
                        CountryNames = upper(CountryNames)';
                        for powerplant = 1:length(Plants)
                            for Names = 1:length(CountryNames)
                                if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                    Plants(powerplant,12) = region;
                                    colorschemecategory(powerplant) = 6;
                                    if strcmpi(Plants_string{powerplant,2},'CHINA')
                                        colorschemecategory(powerplant) = 3;
                                    elseif strcmpi(Plants_string{powerplant,2},'INDIA')
                                        colorschemecategory(powerplant) = 9;    
                                    end
                                end
                            end
                        end
                    elseif region == 4%MAF
                        CountryNames = {'Algeria', 'Angola','Bahrain', 'Benin', 'Botswana', 'Burkina Faso', 'Burundi', 'Cameroon', 'Cape Verde', 'Central African Republic',...
                            'Chad', 'Comoros', 'Congo', 'Cote dIvoire', 'Congo', 'Djibouti', 'Egypt', 'Equatorial Guinea', 'Eritrea', 'Ethiopia', ...
                            'Gabon', 'Gambia', 'Ghana', 'Guinea', 'Guinea-Bissau', 'Iran', 'Iraq', 'Israel', 'Jordan', 'Kenya', 'Kuwait', 'Lebanon', 'Lesotho', 'Liberia', ...
                            'Libya', 'Madagascar', 'Malawi', 'Mali', 'Mauritania', 'Mauritius', 'Mayotte', 'Morocco', 'Mozambique', 'Namibia', 'Niger', 'Nigeria', 'Palestine', ...
                            'Oman', 'Qatar', 'Rwanda', 'Reunion', 'Saudi Arabia', 'Senegal', 'Sierra Leone', 'Somalia', 'South Africa', 'South Sudan', 'Sudan', 'Swaziland',...
                            'Syria', 'Togo', 'Tunisia', 'Uganda', 'United Arab Emirates', 'Tanzania', 'Western Sahara', 'Yemen', 'Zambia', 'Zimbabwe'};
                        CountryNames = upper(CountryNames)';
                        for powerplant = 1:length(Plants)
                            for Names = 1:length(CountryNames)
                                if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                    Plants(powerplant,12) = region;
                                    colorschemecategory(powerplant) = 5;
                                end
                            end
                        end  
                    elseif region == 5%LAM
                        CountryNames = {'Argentina', 'Aruba', 'Bahamas', 'Barbados', 'Belize', 'Bolivia', 'Brazil', 'Chile', 'Colombia', 'Costa Rica', 'Cuba', 'Dominican Republic',...
                            'Ecuador', 'El Salvador', 'French Guiana', 'Grenada', 'Guadeloupe', 'Guatemala', 'Guyana', 'Haiti', 'Honduras', 'Jamaica', 'Martinique', 'Mexico', 'Nicaragua',...
                            'Panama', 'Paraguay', 'Peru', 'Suriname', 'Trinidad and Tobago', 'United States Virgin Islands', 'Uruguay', 'Venezuela'};
                        CountryNames = upper(CountryNames)';
                        for powerplant = 1:length(Plants)
                            for Names = 1:length(CountryNames)
                                if strcmpi(Plants_string{powerplant,2},CountryNames{Names,1})
                                    Plants(powerplant,12) = region;
                                    colorschemecategory(powerplant) = 2;
                                end
                            end
                        end  
                    end
                end
                        
                            
               colorschemecategoryOil = colorschemecategory;
                save('../Data/Results/OilColors','colorschemecategoryOil');

                if saveresults == 1
                    save('../Data/Results/Oil_Plants','Plants','Planned_decommission');
                    save('../Data/Results/Oil_Plants_strings','Plants_string');
                end
%                 save('../Data/Results/OilCostbyCountry','F_Costs');
            end
    end%gentype
    
   

















elseif section == 2
 for gentype = FUEL
     CarbonTax19 = xlsread('../Data/CarbonTax1_9.xlsx','standard');
     CarbonTax26 = xlsread('../Data/CarbonTax2_6.xlsx','standard');
     if gentype == 1
        load('../Data/Results/Coal_Plants');
        load('../Data/Results/Coal_Plants_strings');
        load('../Data/Results/CoalCostbyCountry')
        load('../Data/WholeSaleCostofElectricityCoal');
        OM_annual_increase = [];
        
        FuelCosts = F_Costs;
        CarbonPrice = 10:100:10000;
        mean_Life = mean_Life_coal;
        
        PowerPlantProfits_CarbonTax = nan(length(Plants),mean_Life,length(CarbonPrice));
        
        PowerPlantProfits_CarbonTax = nan(length(Plants),mean_Life,length(CarbonPrice));
        PowerPlantProfits = nan(length(Plants),mean_Life);
        
        TotalCapacity = sum(Plants(:,1));
        CapacityWeighted = Plants(:,1)./TotalCapacity;
        
        
        LifeLeft = mean_Life - Plants(:,2);
    
        if saveyear == 1
                for generator = 1:length(Plants)
                    if isnan(Planned_decommission(generator))
                        if LifeLeft(generator,1) <=0 
                            yearsleft = randi(5);
                            DecommissionYear(generator,1) = current_year + yearsleft;
                            LifeLeft(generator,1) = yearsleft;
                        elseif LifeLeft(generator,1) > 0
                            DecommissionYear(generator,1) = current_year + LifeLeft(generator,1);
                            LifeLeft(generator,1) = LifeLeft(generator,1);
                        end
                    elseif ~isnan(Planned_decommission(generator))
                           LifeLeft(generator,1) = Planned_decommission(generator) - current_year;

                        if LifeLeft(generator,1) <=0 
                            yearsleft = randi(5);
                            DecommissionYear(generator,1) = current_year + yearsleft;
                            LifeLeft(generator,1) = yearsleft;

                        elseif LifeLeft(generator,1) > 0
                            DecommissionYear(generator,1) = current_year + LifeLeft(generator,1);
                            LifeLeft(generator,1) = LifeLeft(generator,1);
                        end
                    end
                end
                DecommissionYear(28522:28525) = 0; % not iterating through the final power plants due to nans, these are decomissioned anyways
                save(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''],'DecommissionYear','LifeLeft');
            elseif saveyear ~=1
                load(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''])
            end

        LifeLeft(isnan(LifeLeft))=0;
        DecommissionYear(DecommissionYear==0)=nan;

            for generator = 1:length(Plants)
                OM_costs(generator) = Fixed_OM_coal*Plants(generator,1) + Variable_OM_coal*Plants(generator,1).*Plants(generator,3).*AnnualHours;
            end

            for generator = 1:length(Plants)
                Cost_of_Fuel(generator) = Fuel_costs_coal*((Plants(generator,1).*Plants(generator,3).*AnnualHours)/eta_coal);
            end
    
            for generator = 1:length(Plants)
                Costs(generator) = (alpha_coal*Investment_costs_coal+OM_costs(generator)+Cost_of_Fuel(generator));
            end

            Costs(Costs == Inf)=nan;
            Costs(Costs == 0)=nan;

        
            for generator = 1:length(Plants)
                PowerPlantRevenue(generator,1) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,1)*RetailtoWholesaleConversionFactor);
            end

            for generator = 1:length(Plants)
                PowerPlantProfits(generator,1:LifeLeft(generator,1)) = PowerPlantRevenue(generator) - Costs(generator);
            
                PowerPlant_StringInformation(generator,1) = Plants_string(generator,1);%corporate owner of the plant
                PowerPlant_StringInformation(generator,2) = Plants_string(generator,2);%national location of the plant
                PowerPlant_StringInformation(generator,3) = Plants_string(generator,3);%Operating status
            end

            for generator = 1:length(Plants)%%add in carbon tax portion
                for tax = 1:4%1 - global carbon tax 1.9, 2 - region specific 1.9, 3 - global carbon tax 2.6, 4 - region specific 2.6
                    for yr = 1:mean_Life
                        if tax == 1
                            PowerPlantProfits_CarbonTax(generator,1:LifeLeft(generator,1),tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax19(yr+4,7)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator)/947800000)*(Emission_factor(generator)/1e6) ; %starts carbon tax at the year 2024
                        elseif tax == 2
                            PowerPlantProfits_CarbonTax(generator,1:LifeLeft(generator,1),tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax19(yr+4,Plants(generator,12)+1)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator)/947800000)*(Emission_factor(generator)/1e6) ; %starts carbon tax at the year 2024
                        elseif tax == 3
                            PowerPlantProfits_CarbonTax(generator,1:LifeLeft(generator,1),tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax26(yr+4,7)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator)/947800000)*(Emission_factor(generator)/1e6) ; %starts carbon tax at the year 2024
                        elseif tax == 4
                            PowerPlantProfits_CarbonTax(generator,1:LifeLeft(generator,1),tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax26(yr+4,Plants(generator,12)+1)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator)/947800000)*(Emission_factor(generator)/1e6) ; %starts carbon tax at the year 2024
                        end
                    end
                end
            end


        % PowerPlantProfits(PowerPlantProfits<0)  = 0;

        PresentAssetValue = zeros(size(PowerPlantProfits));
        for generator = 1:length(Plants)
            for yr = 1:mean_Life
               PresentAssetValue(generator,yr) =  (PresentAssetValue(generator,yr)./(1 + DiscountRate).^yr);%.*CapacityWeighted(generator);
            end
        end 


        % for generator = 1:length(Plants)%%add in carbon tax portion
        %     for yr = 1:mean_Life
        %         for tax = 1:length(CarbonPrice)
        %             PowerPlantProfits_CarbonTax(generator,yr,tax) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,yr))...%gains
        %             -(Plants(generator,1).*Plants(generator,3).*AnnualHours.*((FuelCosts(1,yr))./Plants(generator,7))+Plants(generator,4)*CarbonPrice(tax)*((CarbonTaxYear(yr)-current_year)/(2100-current_year)).^2) ...%costs  
        %             - Plants(generator,8)*Plants(generator,1)-OM_annual_increase(generator)*yr - Plants(generator,6)*Plants(generator,1).*DiscountRate;
        %         end
        %     end
        % end


        PresentAssetValue_Carbontax = zeros(size(PowerPlantProfits_CarbonTax));
        for generator = 1:length(Plants)
            for yr = 1:mean_Life
                for tax = 1:length(CarbonPrice)
                    PresentAssetValue_Carbontax(generator,yr,tax) =  PowerPlantProfits_CarbonTax(generator,yr,tax)./(1 + DiscountRate).^yr;
                end
            end
        end 

        PresentAssetValue_Carbontax(PresentAssetValue_Carbontax <= 0) = nan;

        PresentAssetValue_Weighted = nan(size(PresentAssetValue_Carbontax));
        for generator = 1:length(Plants)
            for yr = 1:mean_Life
               for tax = 1:length(CarbonPrice)
                  PresentAssetValue_Weighted(generator,yr,tax) = PresentAssetValue_Carbontax(generator,yr,tax);%.*CapacityWeighted(generator);
               end
            end
        end

        PresentAssetValue_Weighted = squeeze(nansum(PresentAssetValue_Weighted,1));
        PresentAssetValue_Weighted(PresentAssetValue_Weighted == 0) = nan;

        year = current_year:(current_year + mean_Life);
        barColorMap = flip(autumn(length(CarbonPrice)));

        figure()
        for i = 1:length(CarbonPrice)
            plot(year(1:40),PresentAssetValue_Weighted(1:40,i),'LineWidth',3,'Color',barColorMap(i,:));
            hold on
        end
        plot(year(1:40),PresentAssetValue_Weighted(1:40,16),'k--','LineWidth',3);%RCP 2.6
        hold on
        plot(year(1:40),PresentAssetValue_Weighted(1:40,43),'k','LineWidth',3);%RCP 1.9
        hold off
        xlim([2025 2050])
        colormap(autumn)
        colorbar
        caxis([nanmin(CarbonPrice) nanmax(CarbonPrice)])
        ax = gca;
        % exportgraphics(ax,['../Plots/Figure - price decline/coal.eps'],'ContentType','vector');    

        save('../Data/Results/OM_Costs_Coal.mat','OM_annual_increase');

        
     elseif gentype == 2
        load('../Data/Results/Gas_Plants');
        load('../Data/Results/Gas_Plants_strings');
        load('../Data/Results/GasCostbyCountry')
        load('../Data/WholeSaleCostofElectricityGas');
        mean_Life = mean_Life_gas;
        
        OM_annual_increase = [];
        
        FuelCosts = F_Costs;
        CarbonPrice = 10:100:10000;
        
        PowerPlantProfits_CarbonTax = nan(length(Plants),mean_Life,length(CarbonPrice));
        
        PowerPlantProfits_CarbonTax = nan(length(Plants),mean_Life,length(CarbonPrice));
        PowerPlantProfits = nan(length(Plants),mean_Life);
        
        TotalCapacity = sum(Plants(:,1));
        CapacityWeighted = Plants(:,1)./TotalCapacity;
        
        
        LifeLeft = mean_Life - Plants(:,2);
    
        if saveyear == 1
                for generator = 1:length(Plants)
                    if isnan(Planned_decommission(generator))
                        if LifeLeft(generator,1) <=0 
                            yearsleft = randi(5);
                            DecommissionYear(generator,1) = current_year + yearsleft;
                            LifeLeft(generator,1) = yearsleft;
                        elseif LifeLeft(generator,1) > 0
                            DecommissionYear(generator,1) = current_year + LifeLeft(generator,1);
                            LifeLeft(generator,1) = LifeLeft(generator,1);
                        end
                    elseif ~isnan(Planned_decommission(generator))
                           LifeLeft(generator,1) = Planned_decommission(generator) - current_year;

                        if LifeLeft(generator,1) <=0 
                            yearsleft = randi(5);
                            DecommissionYear(generator,1) = current_year + yearsleft;
                            LifeLeft(generator,1) = yearsleft;

                        elseif LifeLeft(generator,1) > 0
                            DecommissionYear(generator,1) = current_year + LifeLeft(generator,1);
                            LifeLeft(generator,1) = LifeLeft(generator,1);
                        end
                    end
                end
                DecommissionYear(28522:28525) = 0; % not iterating through the final power plants due to nans, these are decomissioned anyways
                save(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''],'DecommissionYear','LifeLeft');
            elseif saveyear ~=1
                load(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''])
            end

        LifeLeft(isnan(LifeLeft))=0;
        DecommissionYear(DecommissionYear==0)=nan;

            for generator = 1:length(Plants)
                PowerPlantRevenue(generator,1) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,1)*RetailtoWholesaleConversionFactor);
            end

         for generator = 1:length(Plants)
                OM_costs(generator) = Fixed_OM_gas*Plants(generator,1) + Variable_OM_gas*Plants(generator,1).*Plants(generator,3).*AnnualHours;
            end

            for generator = 1:length(Plants)
                Cost_of_Fuel(generator) = Fuel_costs_gas*((Plants(generator,1).*Plants(generator,3).*AnnualHours)/eta_gas);
            end
    
            for generator = 1:length(Plants)
                Costs(generator) = (alpha_gas*Investment_costs_gas+OM_costs(generator)+Cost_of_Fuel(generator));
            end

            Costs(Costs == Inf)=nan;
            Costs(Costs == 0)=nan;

        
            for generator = 1:length(Plants)
                PowerPlantProfits(generator,1:LifeLeft(generator,1)) = PowerPlantRevenue(generator) - Costs(generator);
            
                PowerPlant_StringInformation(generator,1) = Plants_string(generator,1);%corporate owner of the plant
                PowerPlant_StringInformation(generator,2) = Plants_string(generator,2);%national location of the plant
                PowerPlant_StringInformation(generator,3) = Plants_string(generator,3);%Operating status
            end

            for generator = 1:length(Plants)%%add in carbon tax portion
                for tax = 1:4%1 - global carbon tax 1.9, 2 - region specific 1.9, 3 - global carbon tax 2.6, 4 - region specific 2.6
                    for yr = 1:mean_Life
                        if tax == 1
                            PowerPlantProfits_CarbonTax(generator,1:LifeLeft(generator,1),tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax19(yr+4,7)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator)/1e6) ; %starts carbon tax at the year 2024
                        elseif tax == 2
                            PowerPlantProfits_CarbonTax(generator,1:LifeLeft(generator,1),tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax19(yr+4,Plants(generator,12)+1)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator)/1e6) ; %starts carbon tax at the year 2024
                        elseif tax == 3
                            PowerPlantProfits_CarbonTax(generator,1:LifeLeft(generator,1),tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax26(yr+4,7)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator)/1e6) ; %starts carbon tax at the year 2024
                        elseif tax == 4
                            PowerPlantProfits_CarbonTax(generator,1:LifeLeft(generator,1),tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax26(yr+4,Plants(generator,12)+1)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator)/1e6) ; %starts carbon tax at the year 2024
                        end
                    end
                end
            end

        % for generator = 1:length(Plants)%%add in carbon tax portion
        %     PowerPlantProfits(generator,1) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,1))...%gains
        %     -(Plants(generator,1).*Plants(generator,3).*AnnualHours.*((FuelCosts(1,1))./Plants(generator,7)))...%costs
        %     - Plants(generator,8)*Plants(generator,1) - Plants(generator,6)*Plants(generator,1).*DiscountRate;
        % 
        %     OM_annual_increase(generator) = PowerPlantProfits(generator,1)./(DecommissionYear(generator,1) - current_year);
        % end

        % for generator = 1:length(Plants)%%add in carbon tax portion
        %     PowerPlantProfits(generator,1) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,1))...%gains
        %     -(Plants(generator,1).*Plants(generator,3).*AnnualHours.*((FuelCosts(1,1))./Plants(generator,7)))...%costs
        %     - Plants(generator,8)*Plants(generator,1) - Plants(generator,6)*Plants(generator,1).*DiscountRate;
        % 
        %     OM_annual_increase(generator) = PowerPlantProfits(generator,1)./(DecommissionYear(generator,1) - current_year);
        % end

        % for generator = 1:length(Plants)
        %     for yr = 2:mean_Life
        %         PowerPlantProfits(generator,yr) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,1))...%gains
        %     -(Plants(generator,1).*Plants(generator,3).*AnnualHours.*((FuelCosts(1,1))./Plants(generator,7)))...%costs
        %     - Plants(generator,8)*Plants(generator,1)-OM_annual_increase(generator)*yr - Plants(generator,6)*Plants(generator,1).*DiscountRate;
        %     end
        % end


        PowerPlantProfits(PowerPlantProfits<0)  = 0;

        PresentAssetValue = zeros(size(PowerPlantProfits));
        for generator = 1:length(Plants)
            for yr = 1:mean_Life
               PresentAssetValue(generator,yr) =  (PresentAssetValue(generator,yr)./(1 + DiscountRate).^yr);%.*CapacityWeighted(generator);
            end
        end 


        % for generator = 1:length(Plants)%%add in carbon tax portion
        %     for yr = 1:mean_Life
        %         for tax = 1:length(CarbonPrice)
        %             PowerPlantProfits_CarbonTax(generator,yr,tax) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,yr))...%gains
        %             -(Plants(generator,1).*Plants(generator,3).*AnnualHours.*((FuelCosts(1,yr))./Plants(generator,7))+Plants(generator,4)*CarbonPrice(tax)*((CarbonTaxYear(yr)-current_year)/(2100-current_year)).^2) ...%costs  
        %             - Plants(generator,8)*Plants(generator,1)-OM_annual_increase(generator)*yr - Plants(generator,6)*Plants(generator,1).*DiscountRate;
        %         end
        %     end
        % end


        PresentAssetValue_Carbontax = zeros(size(PowerPlantProfits_CarbonTax));
        for generator = 1:length(Plants)
            for yr = 1:mean_Life
                for tax = 1:length(CarbonPrice)
                    PresentAssetValue_Carbontax(generator,yr,tax) =  PowerPlantProfits_CarbonTax(generator,yr,tax)./(1 + DiscountRate).^yr;
                end
            end
        end 

        PresentAssetValue_Carbontax(PresentAssetValue_Carbontax <= 0) = nan;

        PresentAssetValue_Weighted = nan(size(PresentAssetValue_Carbontax));
        for generator = 1:length(Plants)
            for yr = 1:mean_Life
               for tax = 1:length(CarbonPrice)
                  PresentAssetValue_Weighted(generator,yr,tax) = PresentAssetValue_Carbontax(generator,yr,tax);%.*CapacityWeighted(generator);
               end
            end
        end

        PresentAssetValue_Weighted = squeeze(nansum(PresentAssetValue_Weighted,1));
        PresentAssetValue_Weighted(PresentAssetValue_Weighted == 0) = nan;

        year = current_year:(current_year + mean_Life);
        barColorMap = flip(autumn(length(CarbonPrice)));

        figure()
        for i = 1:length(CarbonPrice)
            plot(year(1:40),PresentAssetValue_Weighted(1:40,i),'LineWidth',3,'Color',barColorMap(i,:));
            hold on
        end
        plot(year(1:40),PresentAssetValue_Weighted(1:40,16),'k--','LineWidth',3);%RCP 2.6
        hold on
        plot(year(1:40),PresentAssetValue_Weighted(1:40,43),'k','LineWidth',3);%RCP 1.9
        hold off
        xlim([2025 2050])
        colormap(autumn)
        colorbar
        caxis([nanmin(CarbonPrice) nanmax(CarbonPrice)])
        ax = gca;
        exportgraphics(ax,['../Plots/Figure - price decline/Gas.eps'],'ContentType','vector');    

        save('../Data/Results/OM_Costs_Gas.mat','OM_annual_increase');


     elseif gentype == 3
         
        load('../Data/Results/Oil_Plants');
        load('../Data/Results/Oil_Plants_strings');
        load('../Data/Results/OilCostbyCountry')
        load('../Data/WholeSaleCostofElectricityOil');
        
        
        FuelCosts = F_Costs;
        CarbonPrice = 10:100:10000;
        
        PowerPlantProfits_CarbonTax = nan(length(Plants),mean_Life,length(CarbonPrice));
        
        PowerPlantProfits_CarbonTax = nan(length(Plants),mean_Life,length(CarbonPrice));
        PowerPlantProfits = nan(length(Plants),mean_Life);
        
        TotalCapacity = sum(Plants(:,1));
        CapacityWeighted = Plants(:,1)./TotalCapacity;
        
        
        LifeLeft = mean_Life - Plants(:,2);
    
            if saveyear == 1
                for generator = 1:length(Plants)
                    if isnan(Planned_decommission(generator))
                        if LifeLeft(generator,1) <=0 
                            yearsleft = randi(5);
                            DecommissionYear(generator,1) = current_year + yearsleft;
                            LifeLeft(generator,1) = yearsleft;
                        elseif LifeLeft(generator,1) > 0
                            DecommissionYear(generator,1) = current_year + LifeLeft(generator,1);
                            LifeLeft(generator,1) = LifeLeft(generator,1);
                        end
                    elseif ~isnan(Planned_decommission(generator))
                           LifeLeft(generator,1) = Planned_decommission(generator) - current_year;

                        if LifeLeft(generator,1) <=0 
                            yearsleft = randi(5);
                            DecommissionYear(generator,1) = current_year + yearsleft;
                            LifeLeft(generator,1) = yearsleft;

                        elseif LifeLeft(generator,1) > 0
                            DecommissionYear(generator,1) = current_year + LifeLeft(generator,1);
                            LifeLeft(generator,1) = LifeLeft(generator,1);
                        end
                    end
                end
                DecommissionYear(28522:28525) = 0; % not iterating through the final power plants due to nans, these are decomissioned anyways
                save(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''],'DecommissionYear','LifeLeft');
            elseif saveyear ~=1
                load(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''])
            end

    

            for generator = 1:length(Plants)%%add in carbon tax portion
                PowerPlantProfits(generator,1) = (Plants(generator,1).*mean_OilCF.*AnnualHours.*WholeSaleCostofElectricity(generator,1))...%gains
                -(Plants(generator,1).*mean_OilCF.*AnnualHours.*((FuelCosts(1,1))./Plants(generator,7)))...%costs
                - Plants(generator,8)*Plants(generator,1) - Plants(generator,6)*Plants(generator,1).*DiscountRate;
    
                OM_annual_increase(generator) = PowerPlantProfits(generator,1)./(DecommissionYear(generator,1) - current_year);
            end
    
            for generator = 1:length(Plants)
                for yr = 2:mean_Life
                    PowerPlantProfits(generator,yr) = (Plants(generator,1).*mean_OilCF.*AnnualHours.*WholeSaleCostofElectricity(generator,1))...%gains
                -(Plants(generator,1).*mean_OilCF.*AnnualHours.*((FuelCosts(1,1))./Plants(generator,7)))...%costs
                - Plants(generator,8)*Plants(generator,1)-OM_annual_increase(generator)*yr - Plants(generator,6)*Plants(generator,1).*DiscountRate;
                end
            end
    
    
            PowerPlantProfits(PowerPlantProfits<0)  = 0;
    
            PresentAssetValue = zeros(size(PowerPlantProfits));
            for generator = 1:length(Plants)
                for yr = 1:mean_Life
                   PresentAssetValue(generator,yr) =  (PresentAssetValue(generator,yr)./(1 + DiscountRate).^yr);%.*CapacityWeighted(generator);
                end
            end 
    
    
            for generator = 1:length(Plants)%%add in carbon tax portion
                for yr = 1:mean_Life
                    for tax = 1:length(CarbonPrice)
                        PowerPlantProfits_CarbonTax(generator,yr,tax) = (Plants(generator,1).*mean_OilCF.*AnnualHours.*WholeSaleCostofElectricity(generator,yr))...%gains
                        -(Plants(generator,1).*mean_OilCF.*AnnualHours.*((FuelCosts(1,1))./Plants(generator,7))+Plants(generator,4)*CarbonPrice(tax)*((CarbonTaxYear(yr)-current_year)/(2100-current_year)).^2) ...%costs  
                        - Plants(generator,8)*Plants(generator,1)-OM_annual_increase(generator)*yr - Plants(generator,6)*Plants(generator,1).*DiscountRate;
                    end
                end
            end
    
    
            PresentAssetValue_Carbontax = zeros(size(PowerPlantProfits_CarbonTax));
            for generator = 1:length(Plants)
                for yr = 1:mean_Life
                    for tax = 1:length(CarbonPrice)
                        PresentAssetValue_Carbontax(generator,yr,tax) =  PowerPlantProfits_CarbonTax(generator,yr,tax)./(1 + DiscountRate).^yr;
                    end
                end
            end 
    
            PresentAssetValue_Carbontax(PresentAssetValue_Carbontax <= 0) = nan;
    
            PresentAssetValue_Weighted = nan(size(PresentAssetValue_Carbontax));
            for generator = 1:length(Plants)
                for yr = 1:mean_Life
                   for tax = 1:length(CarbonPrice)
                      PresentAssetValue_Weighted(generator,yr,tax) = PresentAssetValue_Carbontax(generator,yr,tax);%.*CapacityWeighted(generator);
                   end
                end
            end
    
            PresentAssetValue_Weighted = squeeze(nansum(PresentAssetValue_Weighted,1));
            PresentAssetValue_Weighted(PresentAssetValue_Weighted == 0) = nan;
    
            year = current_year:(current_year + mean_Life);
            barColorMap = flip(autumn(length(CarbonPrice)));
    
            figure()
            for i = 1:length(CarbonPrice)
                plot(year(:),PresentAssetValue_Weighted(:,i),'LineWidth',3,'Color',barColorMap(i,:));
                hold on
            end
            plot(year(:),PresentAssetValue_Weighted(:,16),'k--','LineWidth',3);%RCP 2.6
            hold on
            plot(year(:),PresentAssetValue_Weighted(:,43),'k','LineWidth',3);%RCP 1.9
            hold off
            xlim([2025 2050])
            colormap(autumn)
            colorbar
            caxis([nanmin(CarbonPrice) nanmax(CarbonPrice)])
            ax = gca;
            exportgraphics(ax,['../Plots/Figure - price decline/Oil.eps'],'ContentType','vector');    

            save('../Data/Results/OM_Costs_Oil.mat','OM_annual_increase');

     end
 end
          
















        
elseif section == 3%company financial calculations
    for gentype = FUEL
        load(['../Data/Results/' PowerPlantFuel{gentype} '_Plants']);
        load(['../Data/Results/' PowerPlantFuel{gentype} '_Plants_strings']);
        load(['../Data/Results/' PowerPlantFuel{gentype} 'CostbyCountry'])
        load(['../Data/WholeSaleCostofElectricity' PowerPlantFuel{gentype} '']);
        CarbonTax19 = xlsread('../Data/CarbonTax1_9.xlsx','standard');
        CarbonTax26 = xlsread('../Data/CarbonTax2_6.xlsx','standard');
        load(['../Data/Results/' PowerPlantFuel{gentype} 'Colors'])
        if gentype == 1
            colorschemecategoryFuel = colorschemecategoryCoal;
        else
            colorschemecategoryFuel = colorschemecategoryGas;
        end
        Plants(isnan(Plants)) = 0;
        
        clear PowerPlantProfits
        % Plants(isnan(Plants)) = 0;

        PowerPlantRevenue = zeros(length(Plants),1);

        for generator = 1:length(Plants)
            PowerPlantRevenue(generator,1) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,1)*RetailtoWholesaleConversionFactor);
        end
        
        FuelCosts = F_Costs;

        if gentype == 1
            LifeLeft = mean_Life_coal - Plants(:,2);
            mean_Life = mean_Life_coal;
        elseif gentype == 2
            LifeLeft = mean_Life_gas - Plants(:,2);
            mean_Life = mean_Life_gas;
        end

        if saveyear == 1
            for generator = 1:length(Plants)
                if isnan(Planned_decommission(generator))
                    if LifeLeft(generator,1) <=0 
                        yearsleft = randi(5);
                        DecommissionYear(generator,1) = current_year + yearsleft;
                        LifeLeft(generator,1) = yearsleft;
                    elseif LifeLeft(generator,1) > 0
                        DecommissionYear(generator,1) = current_year + LifeLeft(generator,1);
                        LifeLeft(generator,1) = LifeLeft(generator,1);
                    end
                elseif ~isnan(Planned_decommission(generator))
                       LifeLeft(generator,1) = Planned_decommission(generator) - current_year;

                    if LifeLeft(generator,1) <=0 
                        yearsleft = randi(5);
                        DecommissionYear(generator,1) = current_year + yearsleft;
                        LifeLeft(generator,1) = yearsleft;

                    elseif LifeLeft(generator,1) > 0
                        DecommissionYear(generator,1) = current_year + LifeLeft(generator,1);
                        LifeLeft(generator,1) = LifeLeft(generator,1);
                    end
                end
            end
            DecommissionYear(28522:28525) = 0; % not iterating through the final power plants due to nans, these are decomissioned anyways
            save(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''],'DecommissionYear','LifeLeft');
        elseif saveyear ~=1
            load(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''])
        end

        max_Life = nanmax(LifeLeft);

        LifeLeft(isnan(LifeLeft))=0;
        % for generator = 1:length(Plants)%%Nameplate * CF * annual hours 
        %     PowerPlantProfits(generator,1) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,1))...%gains
        %     -(Plants(generator,1).*Plants(generator,3).*AnnualHours.*((FuelCosts(1,1))./Plants(generator,7)))...%costs
        %     - Plants(generator,8)*Plants(generator,1) - Plants(generator,6)*Plants(generator,1).*DiscountRate;
        % 
        %     OM_annual_increase(generator) = PowerPlantProfits(generator,1)./(DecommissionYear(generator,1) - current_year);
        % end

        % for generator = 1:length(Plants)
        %     for yr = 2:40
        %      PowerPlantProfits(generator,yr) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,1))...%gains
        %     -(Plants(generator,1).*Plants(generator,3).*AnnualHours.*((FuelCosts(1,1))./Plants(generator,7)))...%costs
        %     - Plants(generator,8)*Plants(generator,1)-OM_annual_increase(generator)*yr - Plants(generator,6)*Plants(generator,1).*DiscountRate;
        % 
        % 
        %     PowerPlant_StringInformation(generator,1) = Plants_string(generator,1);%corporate owner of the plant
        %     PowerPlant_StringInformation(generator,2) = Plants_string(generator,2);%national location of the plant
        %     PowerPlant_StringInformation(generator,3) = Plants_string(generator,3);%Operating status
        %     end
        % end
        if gentype == 1 
            % for generator = 1:length(Plants)
            %     OM_costs(generator) = Fixed_OM_coal*Plants(generator,1) + (Variable_OM_coal - PowerPlantRevenue(generator,1))*Plants(generator,1).*Plants(generator,3).*AnnualHours;
            % end
            % 
            % for generator = 1:length(Plants)
            %     Cost_of_Fuel(generator) = Fuel_costs_coal*((Plants(generator,1).*Plants(generator,3).*AnnualHours)/eta_coal);
            % 
            % end
            % 
            % for generator = 1:length(Plants)
            %     LCOE(generator) = (alpha_coal*Investment_costs_coal+OM_costs(generator)+Cost_of_Fuel(generator))/(Plants(generator,1).*Plants(generator,3).*AnnualHours);
            % end
            % 
            % LCOE(LCOE == Inf)=nan;


            for generator = 1:length(Plants)
                OM_costs(generator) = Fixed_OM_coal*Plants(generator,1) + Variable_OM_coal*Plants(generator,1).*Plants(generator,3).*AnnualHours;
            end

            for generator = 1:length(Plants)
                Cost_of_Fuel(generator) = Fuel_costs_coal*((Plants(generator,1).*Plants(generator,3).*AnnualHours)/eta_coal);
            end
    
            for generator = 1:length(Plants)
                Costs(generator) = (alpha_coal*Investment_costs_coal+OM_costs(generator)+Cost_of_Fuel(generator));
            end

            Costs = Costs';
            Costs(PowerPlantRevenue==0)=0;

            Costs(Costs == Inf)=nan;
            Costs(Costs == 0)=nan;

        
            for generator = 1:length(Plants)
                PowerPlantProfits(generator,1:LifeLeft(generator,1)) = PowerPlantRevenue(generator) - Costs(generator);
            
                PowerPlant_StringInformation(generator,1) = Plants_string(generator,1);%corporate owner of the plant
                PowerPlant_StringInformation(generator,2) = Plants_string(generator,2);%national location of the plant
                PowerPlant_StringInformation(generator,3) = Plants_string(generator,3);%Operating status
            end

            PowerPlantProfits_CarbonTax = zeros(length(PowerPlantProfits),max_Life,4);
            Stranded_Assets_based_on_added_costs = zeros(size(PowerPlantProfits_CarbonTax));
            for generator = 1:length(Plants)%%add in carbon tax portion
                for tax = 1:4%1 - global carbon tax 1.9, 2 - region specific 1.9, 3 - global carbon tax 2.6, 4 - region specific 2.6
                    for yr = 1:max_Life
                        if tax == 1
                            PowerPlantProfits_CarbonTax(generator,yr,tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax19(yr+4,7)*(Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); %starts carbon tax at the year 2024
                            Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax19(yr+4,7)*(Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                        elseif tax == 2
                            PowerPlantProfits_CarbonTax(generator,yr,tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax19(yr+4,Plants(generator,12)+1)*(Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); %starts carbon tax at the year 2024
                            Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax19(yr+4,Plants(generator,12)+1)*(Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                        elseif tax == 3
                            PowerPlantProfits_CarbonTax(generator,yr,tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax26(yr+4,7)*(Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); %starts carbon tax at the year 2024
                            Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax26(yr+4,7)*(Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                        elseif tax == 4
                            PowerPlantProfits_CarbonTax(generator,yr,tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax26(yr+4,Plants(generator,12)+1)*(Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)); %starts carbon tax at the year 2024
                            Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax26(yr+4,Plants(generator,12)+1)*(Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                        end
                    end
                end
            end

            for i = 1:length(Plants)
                for j = 1:max_Life
                    if PowerPlantProfits(i,j) == 0 %ensures power plant profits set to zero if power plant is decommisioned based on operational life
                        PowerPlantProfits_CarbonTax(i,j,:) = 0;
                        Stranded_Assets_based_on_added_costs(i,j,:) = 0;
                    end
                end
            end

        elseif gentype ==2 

            for generator = 1:length(Plants)
                OM_costs(generator) = Fixed_OM_gas*Plants(generator,1) + Variable_OM_gas*Plants(generator,1).*Plants(generator,3).*AnnualHours;
            end

            for generator = 1:length(Plants)
                Cost_of_Fuel(generator) = Fuel_costs_gas*((Plants(generator,1).*Plants(generator,3).*AnnualHours)/eta_gas);
            end
    
            for generator = 1:length(Plants)
                Costs(generator) = (alpha_gas*Investment_costs_gas+OM_costs(generator)+Cost_of_Fuel(generator));
            end

            Costs = Costs';
            Costs(PowerPlantRevenue==0)=0;

            Costs(Costs == Inf)=nan;
            Costs(Costs == 0)=nan;

        
            for generator = 1:length(Plants)
                PowerPlantProfits(generator,1:LifeLeft(generator,1)) = PowerPlantRevenue(generator) - Costs(generator);
            
                PowerPlant_StringInformation(generator,1) = Plants_string(generator,1);%corporate owner of the plant
                PowerPlant_StringInformation(generator,2) = Plants_string(generator,2);%national location of the plant
                PowerPlant_StringInformation(generator,3) = Plants_string(generator,3);%Operating status
            end

            PowerPlantProfits_CarbonTax = zeros(length(PowerPlantProfits),max_Life,4);
            Stranded_Assets_based_on_added_costs = zeros(size(PowerPlantProfits_CarbonTax));
            for generator = 1:length(Plants)%%add in carbon tax portion
                for tax = 1:4%1 - global carbon tax 1.9, 2 - region specific 1.9, 3 - global carbon tax 2.6, 4 - region specific 2.6
                    for yr = 1:max_Life
                        if tax == 1
                            PowerPlantProfits_CarbonTax(generator,yr,tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax19(yr+4,7)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator)) *(Plants(generator,5)/100); %starts carbon tax at the year 2024
                            Stranded_Assets_based_on_added_costs(generator,yr,tax) =CarbonTax19(yr+4,7)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator))*(Plants(generator,5)/100) ; % equation based on https://www.gem.wiki/Estimating_carbon_dioxide_emissions_from_gas_plants
                        elseif tax == 2
                            PowerPlantProfits_CarbonTax(generator,yr,tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax19(yr+4,Plants(generator,12)+1)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator)) *(Plants(generator,5)/100); 
                            Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax19(yr+4,Plants(generator,12)+1)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator)) *(Plants(generator,5)/100);
                        elseif tax == 3
                            PowerPlantProfits_CarbonTax(generator,yr,tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax26(yr+4,7)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator))*(Plants(generator,5)/100) ;
                            Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax26(yr+4,7)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator)) *(Plants(generator,5)/100); 
                        elseif tax == 4
                            PowerPlantProfits_CarbonTax(generator,yr,tax) = PowerPlantRevenue(generator) - Costs(generator) - CarbonTax26(yr+4,Plants(generator,12)+1)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator)) *(Plants(generator,5)/100); 
                            Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax26(yr+4,Plants(generator,12)+1)*Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator)) *(Plants(generator,5)/100); 
                        end
                    end
                end
            end

            for i = 1:length(Plants)
                for j = 1:max_Life
                    if PowerPlantProfits(i,j) == 0 %ensures power plant profits set to zero if power plant is decommisioned based on operational life
                        PowerPlantProfits_CarbonTax(i,j,:) = 0;
                        Stranded_Assets_based_on_added_costs(i,j,:) = 0;
                    end
                end
            end


        end
        PowerPlantProfits_CarbonTax(isnan(PowerPlantProfits_CarbonTax)) = 0;
        PowerPlantProfits(isnan(PowerPlantProfits))=0;

    
        % PowerPlantProfits(PowerPlantProfits<0)  = 0; %prevents profits from being negative, instead power plants are shut down at this time


        %calculates the proportion of power plant assets by company based
        %on the percent ownership of that company
        for generators = 1:length(Plants)
            PowerPlantProfits(generator,:) = PowerPlantProfits(generator,:) * (Plants(generator,5)/100);
        end


        Present_Value_Stranded_Assets_based_on_added_costs = zeros(size(PowerPlantProfits_CarbonTax));
        for generator = 1:length(Plants)
            for yr = 1:max_Life
                PresentAssetValue(generator,yr) = PowerPlantProfits(generator,yr)./(1 + DiscountRate).^yr;
            end
        end 
        
        % PowerPlantProfits_CarbonTax(PowerPlantProfits_CarbonTax<0) = 0;

             
        for generator = 1:length(Plants)
            for yr = 1:max_Life
                for i = 1:4
                    PresentAssetValue_Carbontax(generator,yr,i) = PowerPlantProfits_CarbonTax(generator,yr,i)./((1 + DiscountRate).^yr);
                    Present_Value_Stranded_Assets_based_on_added_costs(generator,yr,i) = Stranded_Assets_based_on_added_costs(generator,yr,i)./((1 + DiscountRate).^yr);
                end
            end
        end         

                    
        StrandedAssetValue = zeros(size(PowerPlantProfits_CarbonTax));
        % for generator = 1:length(Plants) % We only care about the difference of these two values. Stranded assets would be equal to the additional unrecoverable costs added to the power infrastrucutre regardless of profits
        %     for yr = 1:max_Life
        %         for i = 1:4
        %             if PowerPlantProfits(generator,yr) > 0 && PowerPlantProfits_CarbonTax(generator,yr,i) >= 0
        %                 StrandedAssetValue(generator,yr,i) = (PowerPlantProfits(generator,yr)-PowerPlantProfits_CarbonTax(generator,yr,i))./(1 + DiscountRate).^yr;
        %             elseif PowerPlantProfits(generator,yr) > 0 && PowerPlantProfits_CarbonTax(generator,yr,i) <= 0
        %                 StrandedAssetValue(generator,yr,i) = (PowerPlantProfits(generator,yr)-PowerPlantProfits_CarbonTax(generator,yr,i))./(1 + DiscountRate).^yr;
        %             elseif PowerPlantProfits(generator,yr) <= 0 && PowerPlantProfits_CarbonTax(generator,yr,i) < 0
        %                 StrandedAssetValue(generator,yr,i) = (abs(PowerPlantProfits_CarbonTax(generator,yr,i))-abs(PowerPlantProfits(generator,yr)))./(1 + DiscountRate).^yr;
        %             end
        %         end
        %     end
        % end 

         for generator = 1:length(Plants) % We only care about the difference of these two values. Stranded assets would be equal to the additional unrecoverable costs added to the power infrastrucutre regardless of profits
            for yr = 1:max_Life
                for i = 1:4
                    StrandedAssetValue(generator,yr,i) = abs(((PowerPlantProfits(generator,yr))-(PowerPlantProfits_CarbonTax(generator,yr,i))))./((1 + DiscountRate).^yr);
                end
            end
        end 
        
        % AnnualStrandedAssets = StrandedAssetValue;
        % StrandedAssetValue = squeeze(nansum(StrandedAssetValue,2));
        AnnualStrandedAssets = Present_Value_Stranded_Assets_based_on_added_costs;
        StrandedAssetValue = squeeze(nansum(Present_Value_Stranded_Assets_based_on_added_costs,2));
        
        
        CorporateOwners = unique(PowerPlant_StringInformation(:,1));
        CountryLocations = unique(PowerPlant_StringInformation(:,2));
        PowerPlantFinances_byCompany = zeros(length(CorporateOwners),max_Life,5);
        RevenuebyCompany = zeros(length(CorporateOwners),1);
        colorschemecategory = nan(length(CorporateOwners),length(colorschemecategoryFuel));
        StrandedAssetValuebyCompany = zeros(length(CorporateOwners),4);
        PresentAssetValuebyCompany = zeros(length(CorporateOwners),1);
        PowerPlantStrandedAssets_byCompany = zeros(length(CorporateOwners),max_Life,4);
        
        for generator = 1:length(PowerPlant_StringInformation)
            for Company = 1:length(CorporateOwners)
                if strcmpi(PowerPlant_StringInformation{generator,1},CorporateOwners{Company,1})
                    for yr = 1:max_Life
                        PowerPlantFinances_byCompany(Company,yr,1) = PowerPlantFinances_byCompany(Company,yr,1) + PowerPlantProfits(generator,yr);
                        PowerPlantFinances_byCompany(Company,yr,2) = PowerPlantFinances_byCompany(Company,yr,2) + PowerPlantProfits_CarbonTax(generator,yr);
                        PowerPlantFinances_byCompany(Company,yr,3) = PowerPlantFinances_byCompany(Company,yr,3) + PresentAssetValue(generator,yr);
                        PowerPlantFinances_byCompany(Company,yr,4) = PowerPlantFinances_byCompany(Company,yr,4) + PresentAssetValue_Carbontax(generator,yr);
                        
                        PowerPlantStrandedAssets_byCompany(Company,yr,:) = PowerPlantStrandedAssets_byCompany(Company,yr,:) + AnnualStrandedAssets(generator,yr,:);
                    end
                    PresentAssetValuebyCompany(Company,:) = PresentAssetValuebyCompany(Company,:) + nansum(PresentAssetValue(generator,:),2);
                    PowerPlantString_ByCompany(Company,:) = PowerPlant_StringInformation(generator,1);
                    RevenuebyCompany(Company,1) = RevenuebyCompany(Company,1) + PowerPlantRevenue(generator);
                    StrandedAssetValuebyCompany(Company,:) = StrandedAssetValuebyCompany(Company,:) + StrandedAssetValue(generator,:);
                    PowerPlantFinances_byCompany(Company,1,5) = PowerPlantFinances_byCompany(Company,1,5) + StrandedAssetValue(generator,2);
                    colorschemecategory(Company,generator) = colorschemecategoryFuel(generator);
                end
            end
        end
        
       TotalPowerPlantCapacitybyCompany = zeros(length(CorporateOwners),1);
       PowerPlantLife_byCompany = zeros(length(CorporateOwners),max_Life);
       
       Capacity = Plants(:,1);
        
        for generator = 1:length(Plants)
            for yr = 1:max_Life 
                PlantAge(generator,yr) =  Plants(generator,2)+yr;
            end
        end
        
        PlantAge(isnan(PlantAge)) = 0;
        
        for Company = 1:length(CorporateOwners)
            for generator = 1:length(PowerPlant_StringInformation)
                if strcmpi(PowerPlant_StringInformation{generator,1},CorporateOwners{Company,1})
                    TotalPowerPlantCapacitybyCompany(Company,1) = TotalPowerPlantCapacitybyCompany(Company,1) + Capacity(generator,1)* (Plants(generator,5)/100);
                end
            end
        end
        
        for Company = 1:length(CorporateOwners)
            for generator = 1:length(PowerPlant_StringInformation)
                if strcmpi(PowerPlant_StringInformation{generator,1},CorporateOwners{Company,1})
                    PowerPlantLife_byCompany(Company,:) = PowerPlantLife_byCompany(Company,:) + PlantAge(generator,:).*(Capacity(generator,1)./TotalPowerPlantCapacitybyCompany(Company))*(Plants(generator,5)/100);%plant age weighted by capacity and percent ownership
                end
            end
        end
        
        PowerPlantLife_byCompany = round(PowerPlantLife_byCompany);
        PowerPlantFinances_byCountry = zeros(length(CountryLocations),max_Life,5);
        RevenuebyCountry = zeros(length(CountryLocations),1);
        PowerPlantStrandedAssets_byCountry = zeros(length(CountryLocations),max_Life,4);
        
        for generator = 1:length(PowerPlant_StringInformation)
            for country = 1:length(CountryLocations)
                if strcmpi(PowerPlant_StringInformation{generator,2},CountryLocations{country,1})
                    for yr = 1:max_Life
                        PowerPlantFinances_byCountry(country,yr,1) = PowerPlantFinances_byCountry(country,yr,1) + PowerPlantProfits(generator,yr);
                        PowerPlantFinances_byCountry(country,yr,2) = PowerPlantFinances_byCountry(country,yr,2) + PowerPlantProfits_CarbonTax(generator,yr);
                        PowerPlantFinances_byCountry(country,yr,3) = PowerPlantFinances_byCountry(country,yr,3) + PresentAssetValue(generator,yr);
                        PowerPlantFinances_byCountry(country,yr,4) = PowerPlantFinances_byCountry(country,yr,4) + PresentAssetValue_Carbontax(generator,yr);
                        
                        PowerPlantString_ByCountry(country,:) = PowerPlant_StringInformation(generator,2);
                        PowerPlantStrandedAssets_byCountry(country,yr,:) = PowerPlantStrandedAssets_byCountry(country,yr,:)+AnnualStrandedAssets(generator,yr,:);
                    end
                    RevenuebyCountry(country,1) = RevenuebyCountry(country,1) + PowerPlantRevenue(generator);
                    PowerPlantFinances_byCountry(country,1,5) = PowerPlantFinances_byCountry(country,1,5) + StrandedAssetValue(generator,2);
                end
            end
        end
        
        colorschemecategory  = mode(colorschemecategory,2);
        colorschemecategory(colorschemecategory == 0) = 8;
        save(['../Data/Results/colorschemecategory' PowerPlantFuel{gentype} '2'],'colorschemecategory');

        if saveresults == 1
            save(['../Data/Results/PowerPlantFinances_byCompany_' PowerPlantFuel{gentype} ''],'PowerPlantFinances_byCompany','PowerPlantString_ByCompany','PowerPlantLife_byCompany','TotalPowerPlantCapacitybyCompany','PlantAge','AnnualStrandedAssets','PresentAssetValuebyCompany','StrandedAssetValuebyCompany','PowerPlantStrandedAssets_byCompany');
            save(['../Data/Results/PowerPlantFinances_byCountry_' PowerPlantFuel{gentype} ''],'PowerPlantFinances_byCountry','PowerPlantString_ByCountry','PowerPlantStrandedAssets_byCountry');
            save(['../Data/Results/' PowerPlantFuel{gentype} 'Revenue.mat'],'RevenuebyCountry','RevenuebyCompany')
        end
    end
    
















elseif section == 4%Figure - Annual Stranded Assets
    for gentype = FUEL
        if CombineFuelTypeResults ~= 1
            load(['../Data/Results/' PowerPlantFuel{gentype} '_Plants']);
            load(['../Data/Results/' PowerPlantFuel{gentype} '_Plants_strings']);      
            load(['../Data/Results/PowerPlantFinances_byCompany_' PowerPlantFuel{gentype} '']);
%                 AnnualStrandedAssets = squeeze(nansum(AnnualStrandedAssets,2));
            Plants(:,2) = round(Plants(:,2));
            Plants(isnan(Plants)) = 0;
            Emission_factor(isnan(Emission_factor))=0;

            if gentype == 1
                LifeLeft = mean_Life_coal - Plants(:,2);
                mean_Life = mean_Life_coal;
                Heat_rate(isnan(Heat_rate))=0;
            elseif gentype == 2
                LifeLeft = mean_Life_gas - Plants(:,2);
                mean_Life = mean_Life_gas;
            end
    
            if saveyear == 1
                for generator = 1:length(Plants)
                    if isnan(Planned_decommission(generator))
                        if LifeLeft(generator,1) <=0 
                            yearsleft = randi(5);
                            DecommissionYear(generator,1) = current_year + yearsleft;
                            LifeLeft(generator,1) = yearsleft;
                        elseif LifeLeft(generator,1) > 0
                            DecommissionYear(generator,1) = current_year + LifeLeft(generator,1);
                            LifeLeft(generator,1) = LifeLeft(generator,1);
                        end
                    elseif ~isnan(Planned_decommission(generator))
                           LifeLeft(generator,1) = Planned_decommission(generator) - current_year;

                        if LifeLeft(generator,1) <=0 
                            yearsleft = randi(5);
                            DecommissionYear(generator,1) = current_year + yearsleft;
                            LifeLeft(generator,1) = yearsleft;

                        elseif LifeLeft(generator,1) > 0
                            DecommissionYear(generator,1) = current_year + LifeLeft(generator,1);
                            LifeLeft(generator,1) = LifeLeft(generator,1);
                        end
                    end
                end
                DecommissionYear(28522:28525) = 0; % not iterating through the final power plants due to nans, these are decomissioned anyways
                save(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''],'DecommissionYear','LifeLeft');
            elseif saveyear ~=1
                load(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''])
            end
    
    
            LifeLeft(isnan(LifeLeft))=0;


            CompanyNames = unique(Plants_string(:,1));
            CountryNames = unique(Plants_string(:,2));
            if FUEL == 1
                AnnualEmissionsByCompany = zeros(length(CompanyNames),mean_Life+10);
                AnnualEmissionsByCountry = zeros(length(CountryNames),mean_Life+10);
    
                AnnualCapacityByCompany = zeros(length(CompanyNames),mean_Life+10);
                AnnualStrandedAssetByCompany19_globalpricing = zeros(length(CompanyNames),mean_Life+10);
                AnnualStrandedAssetByCompany26_globalpricing = zeros(length(CompanyNames),mean_Life+10);
                
                AnnualStrandedAssetByCompany19_regionalpricing = zeros(length(CompanyNames),mean_Life+10);
                AnnualStrandedAssetByCompany26_regionalpricing = zeros(length(CompanyNames),mean_Life+10);
                NumberofPlantsperCompanyperYear = zeros(length(CompanyNames),mean_Life+10);
                
                
                AnnualStrandedAssetByCountry19_globalpricing = zeros(length(CountryNames),mean_Life+10);
                AnnualStrandedAssetByCountry26_globalpricing = zeros(length(CountryNames),mean_Life+10);
                
                AnnualStrandedAssetByCountry19_regionalpricing = zeros(length(CountryNames),mean_Life+10);
                AnnualStrandedAssetByCountry26_regionalpricing = zeros(length(CountryNames),mean_Life+10);
            elseif FUEL == 2 
                AnnualEmissionsByCompany = zeros(length(CompanyNames),mean_Life+20);
                AnnualEmissionsByCountry = zeros(length(CountryNames),mean_Life+20);
    
                AnnualCapacityByCompany = zeros(length(CompanyNames),mean_Life+20);
                AnnualStrandedAssetByCompany19_globalpricing = zeros(length(CompanyNames),mean_Life+20);
                AnnualStrandedAssetByCompany26_globalpricing = zeros(length(CompanyNames),mean_Life+20);
                
                AnnualStrandedAssetByCompany19_regionalpricing = zeros(length(CompanyNames),mean_Life+20);
                AnnualStrandedAssetByCompany26_regionalpricing = zeros(length(CompanyNames),mean_Life+20);
                NumberofPlantsperCompanyperYear = zeros(length(CompanyNames),mean_Life+20);
                
                
                AnnualStrandedAssetByCountry19_globalpricing = zeros(length(CountryNames),mean_Life+20);
                AnnualStrandedAssetByCountry26_globalpricing = zeros(length(CountryNames),mean_Life+20);
                
                AnnualStrandedAssetByCountry19_regionalpricing = zeros(length(CountryNames),mean_Life+20);
                AnnualStrandedAssetByCountry26_regionalpricing = zeros(length(CountryNames),mean_Life+20);
            end
            
            for generator = 1:length(Plants)
                for Company = 1:length(CompanyNames)
                    if LifeLeft(generator) > 0
                        if strcmpi(Plants_string{generator,1},CompanyNames{Company,1})
                            AnnualCapacityByCompany(Company,1:LifeLeft(generator)) = AnnualCapacityByCompany(Company,1:LifeLeft(generator)) + Plants(generator,1)*(Plants(generator,5)/100);
                            NumberofPlantsperCompanyperYear(Company,1:LifeLeft(generator)) = NumberofPlantsperCompanyperYear(Company,1:LifeLeft(generator))+1*(Plants(generator,5)/100);
                        end
                    end
                end
            end
            
            for generator = 1:length(Plants)
                for Company = 1:length(CompanyNames)
                    if LifeLeft(generator) > 0
                        if strcmpi(Plants_string{generator,1},CompanyNames{Company,1})
                            for yr = 1:nanmax(LifeLeft)
                                AnnualStrandedAssetByCompany19_globalpricing(Company,yr) = AnnualStrandedAssetByCompany19_globalpricing(Company,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,1),2));
                                AnnualStrandedAssetByCompany26_globalpricing(Company,yr) = AnnualStrandedAssetByCompany26_globalpricing(Company,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,3),2));

                                AnnualStrandedAssetByCompany19_regionalpricing(Company,yr) = AnnualStrandedAssetByCompany19_regionalpricing(Company,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,2),2));
                                AnnualStrandedAssetByCompany26_regionalpricing(Company,yr) = AnnualStrandedAssetByCompany26_regionalpricing(Company,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,4),2));
                            end
                        end
                    end
                end
            end

            % for generator = 1:length(Plants)
            %     for Company = 1:length(CompanyNames)
            %         if LifeLeft(generator) > 0
            %             if strcmpi(Plants_string{generator,1},CompanyNames{Company,1})
            %                 AnnualStrandedAssetByCompany19_globalpricing(Company,1:LifeLeft(generator)) = AnnualStrandedAssetByCompany19_globalpricing(Company,1:LifeLeft(generator)) + AnnualStrandedAssets(generator,1:LifeLeft(generator),1);
            %                 AnnualStrandedAssetByCompany26_globalpricing(Company,1:LifeLeft(generator)) = AnnualStrandedAssetByCompany26_globalpricing(Company,1:LifeLeft(generator)) + AnnualStrandedAssets(generator,1:LifeLeft(generator),3);
            % 
            %                 AnnualStrandedAssetByCompany19_regionalpricing(Company,1:LifeLeft(generator)) = AnnualStrandedAssetByCompany19_regionalpricing(Company,1:LifeLeft(generator)) + AnnualStrandedAssets(generator,1:LifeLeft(generator),2);
            %                 AnnualStrandedAssetByCompany26_regionalpricing(Company,1:LifeLeft(generator)) = AnnualStrandedAssetByCompany26_regionalpricing(Company,1:LifeLeft(generator)) + AnnualStrandedAssets(generator,1:LifeLeft(generator),4);
            %             end
            %         end
            %     end
            % end
            
            if gentype == 1
                for generator = 1:length(Plants)
                    for Company = 1:length(CompanyNames)
                        if LifeLeft(generator) > 0
                            if strcmpi(Plants_string{generator,1},CompanyNames{Company,1})
                                AnnualCapacityByCompany(Company,1:LifeLeft(generator)) = AnnualCapacityByCompany(Company,1:LifeLeft(generator)) + Plants(generator,1)*(Plants(generator,5)/100);
                                AnnualEmissionsByCompany(Company,1:LifeLeft(generator)) = AnnualEmissionsByCompany(Company,1:LifeLeft(generator)) + (Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                                AnnualEmissionsByCompany_Coal_strings{Company,1} = CompanyNames{Company,1};
                            end
                        end
                    end
                end
                                
                CoalAnnualEmissions_Fuel = nansum(AnnualEmissionsByCompany,1);
                CommittedEmissions = nansum(AnnualEmissionsByCompany,2);
                CoalAnnualEmissions = zeros(length(CommittedEmissions),50);

                for Company = 1:length(CommittedEmissions)
                    for yr = 1:nanmax(LifeLeft)
                        CoalAnnualEmissions(Company,yr) = CoalAnnualEmissions(Company,yr) + squeeze(nansum(AnnualEmissionsByCompany(Company,yr:end)));
                    end
                end

                CoalAnnualEmissions = nansum(CoalAnnualEmissions,1);
                
                CoalAnnualEmissions_Company = AnnualEmissionsByCompany;
    
                for generator = 1:length(Plants)
                    for Country = 1:length(CountryNames)
                        if LifeLeft(generator) > 0
                            if strcmpi(Plants_string{generator,2},CountryNames{Country,1})
                                AnnualEmissionsByCountry(Country,1:LifeLeft(generator)) = AnnualEmissionsByCountry(Country,1:LifeLeft(generator)) + (Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                                AnnualEmissionsByCountry_Coal_strings{Country,1} = CountryNames{Country,1};
                            end
                        end
                    end
                end
                
                for generator = 1:length(Plants)
                    for Country = 1:length(CountryNames)
                        if LifeLeft(generator) > 0
                            if strcmpi(Plants_string{generator,2},CountryNames{Country,1})     
                                for yr = 1:mean_Life
                                    AnnualStrandedAssetByCountry19_globalpricing(Country,yr) = AnnualStrandedAssetByCountry19_globalpricing(Country,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,1),2));
                                    AnnualStrandedAssetByCountry26_globalpricing(Country,yr) = AnnualStrandedAssetByCountry26_globalpricing(Country,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,3),2));

                                    AnnualStrandedAssetByCountry19_regionalpricing(Country,yr) = AnnualStrandedAssetByCountry19_regionalpricing(Country,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,2),2));
                                    AnnualStrandedAssetByCountry26_regionalpricing(Country,yr) = AnnualStrandedAssetByCountry26_regionalpricing(Country,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,4),2));
                                end
                            end
                        end
                    end
                end

                % for generator = 1:length(Plants)
                %     for Country = 1:length(CountryNames)
                %         if LifeLeft(generator) > 0
                %             if strcmpi(Plants_string{generator,2},CountryNames{Country,1})     
                %                 AnnualStrandedAssetByCountry19_globalpricing(Country,1:LifeLeft(generator)) = AnnualStrandedAssetByCountry19_globalpricing(Country,1:LifeLeft(generator)) + AnnualStrandedAssets(generator,1:LifeLeft(generator),1);
                %                 AnnualStrandedAssetByCountry26_globalpricing(Country,1:LifeLeft(generator)) = AnnualStrandedAssetByCountry26_globalpricing(Country,1:LifeLeft(generator)) + AnnualStrandedAssets(generator,1:LifeLeft(generator),3);
                % 
                %                 AnnualStrandedAssetByCountry19_regionalpricing(Country,1:LifeLeft(generator)) = AnnualStrandedAssetByCountry19_regionalpricing(Country,1:LifeLeft(generator)) + AnnualStrandedAssets(generator,1:LifeLeft(generator),2);
                %                 AnnualStrandedAssetByCountry26_regionalpricing(Country,1:LifeLeft(generator)) = AnnualStrandedAssetByCountry26_regionalpricing(Country,1:LifeLeft(generator)) + AnnualStrandedAssets(generator,1:LifeLeft(generator),4);
                %             end
                %         end
                %     end
                % end

            
                
                CoalAnnualEmissions_Country = AnnualEmissionsByCountry;
                
                AnnualStrandedAssetByCompany19_globalpricing_Coal = AnnualStrandedAssetByCompany19_globalpricing;
                AnnualStrandedAssetByCompany26_globalpricing_Coal = AnnualStrandedAssetByCompany26_globalpricing;
                AnnualStrandedAssetByCompany19_regionalpricing_Coal = AnnualStrandedAssetByCompany19_regionalpricing;
                AnnualStrandedAssetByCompany26_regionalpricing_Coal = AnnualStrandedAssetByCompany26_regionalpricing;
                
                AnnualStrandedAssetByCountry19_globalpricing_Coal = AnnualStrandedAssetByCountry19_globalpricing;
                AnnualStrandedAssetByCountry26_globalpricing_Coal = AnnualStrandedAssetByCountry26_globalpricing;
                AnnualStrandedAssetByCountry19_regionalpricing_Coal = AnnualStrandedAssetByCountry19_regionalpricing;
                AnnualStrandedAssetByCountry26_regionalpricing_Coal = AnnualStrandedAssetByCountry26_regionalpricing;
                
                
                figure()
                plot(1:mean_Life,nansum(AnnualStrandedAssetByCompany19_globalpricing(:,1:mean_Life),1))
    
                figure()
                plot(1:mean_Life,CoalAnnualEmissions_Fuel(:,1:mean_Life))
                ylabel('annual emissions')
                AnnualEmissionsByCompany_Coal_strings{end+1} = [];

                figure()
                plot(1:mean_Life,CoalAnnualEmissions(:,1:mean_Life))
                ylabel('committed emissions')
    
                save('../Data/Results/CoalAnnualEmissions.mat','CoalAnnualEmissions_Fuel','CoalAnnualEmissions_Country','CoalAnnualEmissions_Company','AnnualEmissionsByCompany_Coal_strings','AnnualEmissionsByCountry_Coal_strings','CommittedEmissions');
                save('../Data/Results/CoalCompanyCapacity.mat','AnnualCapacityByCompany','NumberofPlantsperCompanyperYear');
                save('../Data/Results/CoalStrandedAssets.mat','AnnualStrandedAssetByCompany19_globalpricing_Coal','AnnualStrandedAssetByCompany26_globalpricing_Coal',...
                    'AnnualStrandedAssetByCompany19_regionalpricing_Coal','AnnualStrandedAssetByCompany26_regionalpricing_Coal',...
                    'AnnualStrandedAssetByCountry19_globalpricing_Coal','AnnualStrandedAssetByCountry26_globalpricing_Coal',...
                    'AnnualStrandedAssetByCountry19_regionalpricing_Coal','AnnualStrandedAssetByCountry26_regionalpricing_Coal');
            else
                for generator = 1:length(Plants)
                    for Company = 1:length(CompanyNames)
                        if LifeLeft(generator) > 0
                            if strcmpi(Plants_string{generator,1},CompanyNames{Company,1})
                                AnnualCapacityByCompany(Company,1:LifeLeft(generator)) = AnnualCapacityByCompany(Company,1:LifeLeft(generator)) + Plants(generator,1)*(Plants(generator,5)/100);
                                AnnualEmissionsByCompany(Company,1:LifeLeft(generator)) = AnnualEmissionsByCompany(Company,1:LifeLeft(generator)) + Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator))* (Plants(generator,5)/100); %
                                AnnualEmissionsByCompany_Gas_strings{Company,1} = CompanyNames{Company,1};
                            end
                        end
                    end
                end

                                
                GasAnnualEmissions_Fuel = nansum(AnnualEmissionsByCompany,1);
                CommittedEmissions = nansum(AnnualEmissionsByCompany,2);
                GasAnnualEmissions = zeros(length(CommittedEmissions),50);

                for Company = 1:length(CommittedEmissions)
                    for yr = 1:nanmax(LifeLeft)
                        GasAnnualEmissions(Company,yr) = GasAnnualEmissions(Company,yr) + squeeze(nansum(AnnualEmissionsByCompany(Company,yr:end)));
                    end
                end

                GasAnnualEmissions = nansum(GasAnnualEmissions,1);
                   
                GasAnnualEmissions = nansum(AnnualEmissionsByCompany,1);
                GasAnnualEmissions_Company = AnnualEmissionsByCompany;
    
                for generator = 1:length(Plants)
                    for Country = 1:length(CountryNames)
                        if LifeLeft(generator) > 0
                            if strcmpi(Plants_string{generator,2},CountryNames{Country,1})
                                AnnualEmissionsByCountry(Country,1:LifeLeft(generator)) = AnnualEmissionsByCountry(Country,1:LifeLeft(generator)) + Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator))* (Plants(generator,5)/100); 
                                AnnualEmissionsByCountry_Gas_strings{Country,1} = CountryNames{Country,1};
                            end
                        end
                    end
                end
                
                for generator = 1:length(Plants)
                    for Country = 1:length(CountryNames)
                        if LifeLeft(generator) > 0
                            if strcmpi(Plants_string{generator,2},CountryNames{Country,1})     
                                for yr = 1:mean_Life
                                    AnnualStrandedAssetByCountry19_globalpricing(Country,yr) = AnnualStrandedAssetByCountry19_globalpricing(Country,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,1),2));
                                    AnnualStrandedAssetByCountry26_globalpricing(Country,yr) = AnnualStrandedAssetByCountry26_globalpricing(Country,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,3),2));

                                    AnnualStrandedAssetByCountry19_regionalpricing(Country,yr) = AnnualStrandedAssetByCountry19_regionalpricing(Country,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,2),2));
                                    AnnualStrandedAssetByCountry26_regionalpricing(Country,yr) = AnnualStrandedAssetByCountry26_regionalpricing(Country,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,4),2));
                                end
                            end
                        end
                    end
                end

                % for generator = 1:length(Plants)
                %     for Country = 1:length(CountryNames)
                %         if LifeLeft(generator) > 0
                %             if strcmpi(Plants_string{generator,2},CountryNames{Country,1})     
                %                 AnnualStrandedAssetByCountry19_globalpricing(Country,1:LifeLeft(generator)) = AnnualStrandedAssetByCountry19_globalpricing(Country,1:LifeLeft(generator)) + AnnualStrandedAssets(generator,1:LifeLeft(generator),1);
                %                 AnnualStrandedAssetByCountry26_globalpricing(Country,1:LifeLeft(generator)) = AnnualStrandedAssetByCountry26_globalpricing(Country,1:LifeLeft(generator)) + AnnualStrandedAssets(generator,1:LifeLeft(generator),3);
                % 
                %                 AnnualStrandedAssetByCountry19_regionalpricing(Country,1:LifeLeft(generator)) = AnnualStrandedAssetByCountry19_regionalpricing(Country,1:LifeLeft(generator)) + AnnualStrandedAssets(generator,1:LifeLeft(generator),2);
                %                 AnnualStrandedAssetByCountry26_regionalpricing(Country,1:LifeLeft(generator)) = AnnualStrandedAssetByCountry26_regionalpricing(Country,1:LifeLeft(generator)) + AnnualStrandedAssets(generator,1:LifeLeft(generator),4);
                %             end
                %         end
                %     end
                % end

                GasAnnualEmissions_Fuel = nansum(AnnualEmissionsByCountry,1);
                GasAnnualEmissions_Country = AnnualEmissionsByCountry;
                
                AnnualStrandedAssetByCompany19_globalpricing_Gas = AnnualStrandedAssetByCompany19_globalpricing;
                AnnualStrandedAssetByCompany26_globalpricing_Gas = AnnualStrandedAssetByCompany26_globalpricing;
                AnnualStrandedAssetByCompany19_regionalpricing_Gas = AnnualStrandedAssetByCompany19_regionalpricing;
                AnnualStrandedAssetByCompany26_regionalpricing_Gas = AnnualStrandedAssetByCompany26_regionalpricing;
                
                AnnualStrandedAssetByCountry19_globalpricing_Gas = AnnualStrandedAssetByCountry19_globalpricing;
                AnnualStrandedAssetByCountry26_globalpricing_Gas = AnnualStrandedAssetByCountry26_globalpricing;
                AnnualStrandedAssetByCountry19_regionalpricing_Gas = AnnualStrandedAssetByCountry19_regionalpricing;
                AnnualStrandedAssetByCountry26_regionalpricing_Gas = AnnualStrandedAssetByCountry26_regionalpricing;
                
                
                figure()
                plot(1:mean_Life,nansum(AnnualStrandedAssetByCompany19_globalpricing(:,1:mean_Life),1))
    
                figure()
                plot(1:mean_Life,GasAnnualEmissions_Fuel(:,1:mean_Life))
                ylabel('annual emissions')
                AnnualEmissionsByCompany_Gas_strings{end+1} = [];

                figure()
                plot(1:mean_Life,GasAnnualEmissions(:,1:mean_Life))
                ylabel('committed emissions')
    
                save('../Data/Results/GasAnnualEmissions.mat','GasAnnualEmissions_Fuel','GasAnnualEmissions_Country','GasAnnualEmissions_Company','AnnualEmissionsByCompany_Gas_strings','AnnualEmissionsByCountry_Gas_strings','CommittedEmissions');
                save('../Data/Results/GasCompanyCapacity.mat','AnnualCapacityByCompany','NumberofPlantsperCompanyperYear');
                save('../Data/Results/GasStrandedAssets.mat','AnnualStrandedAssetByCompany19_globalpricing_Gas','AnnualStrandedAssetByCompany26_globalpricing_Gas',...
                    'AnnualStrandedAssetByCompany19_regionalpricing_Gas','AnnualStrandedAssetByCompany26_regionalpricing_Gas',...
                    'AnnualStrandedAssetByCountry19_globalpricing_Gas','AnnualStrandedAssetByCountry26_globalpricing_Gas',...
                    'AnnualStrandedAssetByCountry19_regionalpricing_Gas','AnnualStrandedAssetByCountry26_regionalpricing_Gas');
            end
       
        elseif CombineFuelTypeResults == 1
            load('../Data/Results/CoalAnnualEmissions.mat');
            load ../Data/Results/PowerPlantFinances_byCompany_Coal.mat
            load ../Data/Results/PowerPlantFinances_byCountry_Coal.mat
            load ../Data/Results/CoalStrandedAssets.mat
            
            
            PowerPlantFinances_byCompany_Coal = PowerPlantFinances_byCompany;
            PowerPlantFinances_byCountry_Coal = PowerPlantFinances_byCountry;
            PowerPlantFinances_byCompany_Coal(PowerPlantFinances_byCompany_Coal<0) = 0;
            PowerPlantFinances_byCountry_Coal(PowerPlantFinances_byCountry_Coal<0) = 0;
            
            load('../Data/Results/GasAnnualEmissions.mat');
            load ../Data/Results/PowerPlantFinances_byCompany_Gas.mat
            load ../Data/Results/PowerPlantFinances_byCountry_Gas.mat
            load ../Data/Results/GasStrandedAssets.mat
            
            PowerPlantFinances_byCompany_Gas = PowerPlantFinances_byCompany;
            PowerPlantFinances_byCountry_Gas = PowerPlantFinances_byCountry;
            PowerPlantFinances_byCompany_Gas(PowerPlantFinances_byCompany_Gas<0) = 0;
            PowerPlantFinances_byCountry_Gas(PowerPlantFinances_byCountry_Gas<0) = 0;
            
            % load('../Data/Results/OilAnnualEmissions.mat');
            % load ../Data/Results/PowerPlantFinances_byCompany_Oil.mat
            % load ../Data/Results/PowerPlantFinances_byCountry_Oil.mat
            % load ../Data/Results/OilStrandedAssets.mat
            % 
            % PowerPlantFinances_byCompany_Oil = PowerPlantFinances_byCompany;
            % PowerPlantFinances_byCountry_Oil = PowerPlantFinances_byCountry;
            % PowerPlantFinances_byCompany_Oil(PowerPlantFinances_byCompany_Oil<0) = 0;
            % PowerPlantFinances_byCountry_Oil(PowerPlantFinances_byCountry_Oil<0) = 0;
            % 
            AnnualEmissions = [CoalAnnualEmissions_Fuel' GasAnnualEmissions_Fuel'];
            NewColormap = autumn(length(1:3));
            
            AnnualEmissions = AnnualEmissions./(1e9);%conversts from tons to gigatons 
            
            figure()
            area(CarbonTaxYear(1:length(AnnualEmissions)),AnnualEmissions)
            colororder(NewColormap);
            legend({'Coal','Natural Gas'})
            xlim([current_year 2059])
            xlabel('Year')
            ylabel('Annual Emissions (GtCO2)')
            aY = gca;
            exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualEmissions_byFuel.eps','ContentType','vector');    
            
            CountrySA = [squeeze(PowerPlantFinances_byCountry_Coal(:,1,5)); squeeze(PowerPlantFinances_byCountry_Gas(:,1,5))];
            CountrySA(isnan(CountrySA)) = 0;

            Country_Names = [AnnualEmissionsByCountry_Coal_strings; AnnualEmissionsByCountry_Gas_strings];
            Country_Names = unique(Country_Names);

            CountryEmissions = zeros(length(Country_Names),50);

            for Country = 1:length(Country_Names)
                for Country_emissions = 1:length(AnnualEmissionsByCountry_Coal_strings)
                    if strcmpi(AnnualEmissionsByCountry_Coal_strings{Country_emissions,1},Country_Names{Country,1})
                        CountryEmissions(Country,1:50) = CountryEmissions(Country,1:50) + CoalAnnualEmissions_Country(Country_emissions,1:50);
                    end
                end
            end

            for Country = 1:length(Country_Names)
                for Country_emissions = 1:length(AnnualEmissionsByCountry_Gas_strings)
                    if strcmpi(AnnualEmissionsByCountry_Gas_strings{Country_emissions,1},Country_Names{Country,1})
                        CountryEmissions(Country,1:50) = CountryEmissions(Country,1:50) + GasAnnualEmissions_Country(Country_emissions,1:50);
                    end
                end
            end


            % CountryEmissions = [CoalAnnualEmissions_Country' GasAnnualEmissions_Country];
            CountryEmissions_strings = cat(1,AnnualEmissionsByCountry_Coal_strings,AnnualEmissionsByCountry_Gas_strings);
            % 
            % CountryStrings =  CountryEmissions_strings(~cellfun('isempty',CountryEmissions_strings));
            % CountryStrings = unique(CountryStrings);
            
            % CountryEmissionsUnique = zeros(length(CountryStrings),40);
            % CountrySAUnique = zeros(length(CountryStrings),1);
            % 
            % for  i = 1:length(CountryStrings)
            %     for j = 1:length(CountryEmissions_strings)
            %         if strcmpi(CountryEmissions_strings{j,1},CountryStrings{i,1})
            %            CountryEmissionsUnique(i,:) = CountryEmissionsUnique(i,:) + CountryEmissions(:,j)';
            %            CountrySAUnique(i,:) = CountrySAUnique(i,:) + CountrySA(j,:);
            %         end
            %     end
            % end
            
            Newcolorbar = autumn(length(1:7));
            % COLORS = zeros(length(CountryEmissionsUnique),3);
            % [Top_Countries_Emissions indx_country] =maxk(CountryEmissionsUnique,10);
            COLORS = zeros(length(CountryEmissions),3);
            [Top_Countries_Emissions indx_country] =maxk(CountryEmissions,10);
            
            % Top_Countries_strings = CountryStrings(indx_country(:,1),1);
            Top_Countries_strings = Country_Names(indx_country(:,1),1);
            % RestofCountriesEmissions = nansum(CountryEmissionsUnique,1)-nansum(Top_Countries_Emissions,1);
            RestofCountriesEmissions = nansum(CountryEmissions,1)-nansum(Top_Countries_Emissions,1);
            CountryEmissions = [RestofCountriesEmissions' Top_Countries_Emissions']';
            
            CountryStrings2 = cell(length(Top_Countries_strings)+1,1);
            CountryStrings2(2:end,1) = Top_Countries_strings;
            CountryStrings2{1,1} = 'Rest of world';
            
            Top_Countries_strings = CountryStrings2;

            CountryEmissions = CountryEmissions./(1e9);%conversts from tons to gigatons 
            
            
            figure()
            area(CarbonTaxYear(1:length(CountryEmissions)),CountryEmissions')
            legend(Top_Countries_strings)
%             colororder(COLORS);
%             colorbar([nanmin(CountrySAUnique) nanmax(CountrySAUnique)]);
            xlim([current_year 2059])
            xlabel('Year')
            ylabel('Annual Emissions (GtCO2)')
            aY = gca;
            exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualEmissions_byCountry.eps','ContentType','vector');              
            Companies = [AnnualEmissionsByCompany_Coal_strings(1:end-1); AnnualEmissionsByCompany_Gas_strings(1:end-1)];
            Companies = unique(Companies);

            StrandedAssetsbyCompany = zeros(length(Companies),47);
            CompanyEmissions= zeros(length(Companies),47);

            for Company = 1:length(Companies)
                for Coal_Emissions = 1:length(AnnualEmissionsByCompany_Coal_strings)
                    if strcmpi(AnnualEmissionsByCompany_Coal_strings{Coal_Emissions,1},Companies{Company,1})
                        StrandedAssetsbyCompany(Company,1:47) = StrandedAssetsbyCompany(Company,1:47) + PowerPlantFinances_byCompany_Coal(Coal_Emissions,1:47,5);
                        CompanyEmissions(Company,1:47) = CompanyEmissions(Company,1:47) + CoalAnnualEmissions_Company(Coal_Emissions,1:47);
                    end
                end
            end

            for Company = 1:length(Companies)
                for Gas_Emissions = 1:length(AnnualEmissionsByCompany_Gas_strings)
                    if strcmpi(AnnualEmissionsByCompany_Gas_strings{Gas_Emissions,1},Companies{Company,1})
                        StrandedAssetsbyCompany(Company,1:46) = StrandedAssetsbyCompany(Company,1:46) + PowerPlantFinances_byCompany_Gas(Gas_Emissions,1:46,5);
                        CompanyEmissions(Company,1:47) = CompanyEmissions(Company,1:47) + GasAnnualEmissions_Company(Gas_Emissions,1:47);
                    end
                end
            end
            
            % StrandedAssetsbyCompany = [squeeze(PowerPlantFinances_byCompany_Coal(:,:,5))' squeeze(PowerPlantFinances_byCompany_Gas(:,:,5))'];
            
            % CompanyEmissions = [CoalAnnualEmissions_Company' GasAnnualEmissions_Company];
            CompanyEmissions_strings = cat(1,AnnualEmissionsByCompany_Coal_strings(1:end-1),AnnualEmissionsByCompany_Gas_strings(1:end-1));
            % 
            % CompanyStrings =  CompanyEmissions_strings(~cellfun('isempty',CompanyEmissions_strings));
            % CompanyStrings = unique(CompanyStrings);
            CompanyStrings = Companies;
            
            % CompanyEmissionsUnique = zeros(length(CompanyStrings),40);
            CompanyEmissionsUnique = CompanyEmissions;
            CompanySA_Unique = zeros(length(CompanyStrings),1);
            
            Newcolorbar = autumn(length(CompanyEmissionsUnique));
            ColorMatrix = zeros(length(CompanyEmissionsUnique),2);           
            
            % for  i = 1:length(CompanyStrings)
            %     for j = 1:length(CompanyEmissions_strings)
            %         if strcmpi(CompanyEmissions_strings{j,1},CompanyStrings{i,1})
            %            CompanyEmissionsUnique(i,:) = CompanyEmissionsUnique(i,:) + CompanyEmissions(:,j)';
            %         end
            %     end
            % end
            CompanySA_Unique(isnan(CompanySA_Unique)) = 0;
            ColorMatrix(:,1) = 1:length(CompanyEmissionsUnique);
            ColorMatrix(:,2) = CompanySA_Unique;
            ColorMatrix(ColorMatrix == 0) = nan;
            ColorMatrix = sort(ColorMatrix,2);
            ColorMatrix(isnan(ColorMatrix)) = 0;
            
            % [NextNinety_Emissions indx] =maxk(CompanyEmissionsUnique,100);%extracts the top 100 companies
            [NextNinety_Emissions indx] =maxk(CompanyEmissionsUnique,100);%extracts the top 100 companies
            [NextNinety_Emissions indx] =mink(NextNinety_Emissions,90);%subtracts the top 10
            [TopTen_Emissions indx] =maxk(CompanyEmissionsUnique,10);
            TopColors = Newcolorbar(ColorMatrix(indx(:,1),1),:);
            COLORS = [TopColors; Newcolorbar(1,:,:)];
            
            RestStrandedEmissions = nansum(CompanyEmissionsUnique,1);
            NextNinety_Emissions = nansum(NextNinety_Emissions,1);
            TopTen_Emissions = nansum(TopTen_Emissions,1);
            RestStrandedEmissions = RestStrandedEmissions - NextNinety_Emissions - TopTen_Emissions;
            StrandedEmissions = [RestStrandedEmissions' NextNinety_Emissions' TopTen_Emissions'];
            
            StrandedEmissions = StrandedEmissions./(1e9);%conversts from tons to gigatons 
            
            figure()
            area(CarbonTaxYear(1:length(StrandedEmissions)),StrandedEmissions)
            legend('Rest','Next 90','Top 10')
            % colororder(COLORS);
            xlim([current_year 2059])
            % ylim([0 12])
            xlabel('Year')
            ylabel('Annual Emissions (GtCO2)')
            aY = gca;
            exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualEmissions_byCompany.eps','ContentType','vector');   
            
            
            TotalStrandedAssets_Global_19_ByFuel = [nansum(AnnualStrandedAssetByCompany19_globalpricing_Coal,1); nansum(AnnualStrandedAssetByCompany19_globalpricing_Gas,1)];
            TotalStrandedAssets_Global_26_ByFuel  = [nansum(AnnualStrandedAssetByCompany26_globalpricing_Coal,1); nansum(AnnualStrandedAssetByCompany26_globalpricing_Gas,1)];
            
            TotalStrandedAssets_Regional_19_ByFuel = [nansum(AnnualStrandedAssetByCompany19_regionalpricing_Coal,1); nansum(AnnualStrandedAssetByCompany19_regionalpricing_Gas,1)];
            TotalStrandedAssets_Regional_26_ByFuel = [nansum(AnnualStrandedAssetByCompany26_regionalpricing_Coal,1); nansum(AnnualStrandedAssetByCompany26_regionalpricing_Gas,1)];
            
            
            figure()
            bar(1,TotalStrandedAssets_Regional_19_ByFuel(:,1)/(1e12),'stacked')
            hold on
            bar(2,TotalStrandedAssets_Regional_26_ByFuel(:,1)/(1e12),'stacked')
            % colororder(NewColormap);
            legend({'Coal','Natural Gas'})
            ylim([0 25])
            % xlabel('Year')
            ylabel('Stranded Assets (USD $)')
            aY = gca;
            exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualStrandings_byFuel_bar.eps','ContentType','vector');  

            TotalStrandedAssets_Global_19_ByFuel =  TotalStrandedAssets_Global_19_ByFuel(:,1);
            TotalStrandedAssets_Global_26_ByFuel =  TotalStrandedAssets_Global_26_ByFuel(:,1);
            

            % figure()
            % area(CarbonTaxYear(1:length(TotalStrandedAssets_Global_19_ByFuel)),TotalStrandedAssets_Global_19_ByFuel')
            % colororder(NewColormap);
            % legend({'Coal','Natural Gas'})
            % xlim([current_year 2059])
            % % ylim([0 14e12])
            % xlabel('Year')
            % ylabel('Stranded Assets (USD $)')
            % aY = gca;
            % exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualStrandings_byFuel_Global19_max.eps','ContentType','vector');    
            % 
            % figure()
            % area(CarbonTaxYear(1:length(TotalStrandedAssets_Global_26_ByFuel)),TotalStrandedAssets_Global_26_ByFuel')
            % colororder(NewColormap);
            % legend({'Coal','Natural Gas'})
            % ylim([0 7e12])
            % xlim([current_year 2059])
            % xlabel('Year')
            % ylabel('Stranded Assets (USD $)')
            % aY = gca;
            % exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualStrandings_byFuel_Global26.eps','ContentType','vector');    
            % 

              
            % figure()
            % area(CarbonTaxYear(1:length(TotalStrandedAssets_Regional_19_ByFuel)),TotalStrandedAssets_Regional_19_ByFuel')
            % colororder(NewColormap);
            % legend({'Coal','Natural Gas'})
            % ylim([0 14e12])
            % xlim([current_year 2059])
            % xlabel('Year')
            % ylabel('Stranded Assets (USD $)')
            % aY = gca;
            % exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualStrandings_byFuel_Regional19_max.eps','ContentType','vector');    
            % 
            % % 
            % figure()
            % area(CarbonTaxYear(1:length(TotalStrandedAssets_Regional_26_ByFuel)),TotalStrandedAssets_Regional_26_ByFuel')
            % colororder(NewColormap);
            % legend({'Coal','Natural Gas'})
            % xlim([current_year 2059])
            % ylim([0 14e12])
            % xlabel('Year')
            % ylabel('Stranded Assets (USD $)')
            % aY = gca;
            % exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualStrandings_byFuel_Regional26.eps','ContentType','vector');    
            
            
            TotalStrandedAssets_Country_Global_19 = [AnnualStrandedAssetByCountry19_globalpricing_Coal; AnnualStrandedAssetByCountry19_globalpricing_Gas];
            TotalStrandedAssets_Country_Global_26 = [AnnualStrandedAssetByCountry26_globalpricing_Coal; AnnualStrandedAssetByCountry26_globalpricing_Gas];
            
            TotalStrandedAssets_Country_Regional_26 = [AnnualStrandedAssetByCountry26_regionalpricing_Coal; AnnualStrandedAssetByCountry26_regionalpricing_Gas];
            TotalStrandedAssets_Country_Regional_19 = [AnnualStrandedAssetByCountry19_regionalpricing_Coal; AnnualStrandedAssetByCountry19_regionalpricing_Gas];
            CountryStrings = Country_Names;
            
            CountryassetsUnique19_global = zeros(length(CountryStrings),50);
            CountryassetsUnique26_global = zeros(length(CountryStrings),50);
            
            CountryassetsUnique19_regional = zeros(length(CountryStrings),50);
            CountryassetsUnique26_regional = zeros(length(CountryStrings),50);
            
            for  i = 1:length(CountryStrings)
                for j = 1:length(CountryEmissions_strings)
                    if strcmpi(CountryEmissions_strings{j,1},CountryStrings{i,1})
                       CountryassetsUnique19_global(i,:) = CountryassetsUnique19_global(i,:) + TotalStrandedAssets_Country_Global_19(j,:);
                       CountryassetsUnique26_global(i,:) = CountryassetsUnique26_global(i,:) + TotalStrandedAssets_Country_Global_26(j,:);
                       
                       CountryassetsUnique19_regional(i,:) = CountryassetsUnique19_regional(i,:) + TotalStrandedAssets_Country_Regional_19(j,:);
                       CountryassetsUnique26_regional(i,:) = CountryassetsUnique26_regional(i,:) + TotalStrandedAssets_Country_Regional_26(j,:);
                    end
                end
            end
            
            [~, indx] = maxk(CountryassetsUnique19_regional(:,1),5);%extracts the top 10
            Top_Countries_assets_regional19 = CountryassetsUnique19_regional(indx,:);
            RestofCountriesEmissions_regional19 = nansum(CountryassetsUnique19_regional,1)-nansum(Top_Countries_assets_regional19,1);
            CountryAssets_regional19 = [RestofCountriesEmissions_regional19' Top_Countries_assets_regional19']';
            Top_Countries_strings = cell(6,1);
            Top_Countries_strings(1,1) = {'REST OF WORLD'};
            Top_Countries_strings(2:end,1) = CountryStrings(indx(:,1),1);
            


            CountryNames = {'Albania', 'Australia', 'Austria', 'Belgium', 'Bosnia-Herzegovina', 'Bulgaria', 'Canada',...
                            'Croatia', 'Cyprus', 'Czech Republic', 'Denmark', 'Estonia', 'Finland', 'France', 'Germany', 'Greece', 'Guam', 'Hungary',...
                            'Iceland', 'Ireland', 'Italy', 'Latvia', 'Lithuania', 'Luxembourg', 'Malta', 'Montenegro', 'Netherlands', 'New Zealand',...
                            'Norway', 'Poland', 'Portugal', 'Puerto Rico', 'Romania', 'Serbia', 'Slovakia', 'Slovenia', 'Spain', 'Sweden', 'Switzerland', ...
                            'North Macedonia', 'Türkiye', 'United Kingdom', 'United States','ENGLAND & WALES','Scotland','Ireland','Moldova','Ukraine','Russia'};
            
            Europe_Assets = 0;
            for Nation = 1:length(CountryStrings)
                for National_name = 1:length(CountryNames)
                    if strcmp(CountryStrings{Nation}, CountryNames{National_name})
                       Europe_Assets = Europe_Assets + CountryassetsUnique19_regional(Nation,1);
                    end
                end
            end

            US_Assets = CountryassetsUnique19_regional(165,1);

            figure()
            bar(1,CountryAssets_regional19(:,1)/(1e12),'stacked')
            % colororder(NewColormap);
            legend(Top_Countries_strings)
            ylim([0 25])
            % xlabel('Year')
            ylabel('Stranded Assets (USD $)')
            aY = gca;
            exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualStrandings_byCountry_1_9_bar.eps','ContentType','vector');
            CountryAssets_regional19 = CountryAssets_regional19(:,1);
            

            figure()
            area(CarbonTaxYear(1:length(CountryAssets_regional19)),CountryAssets_regional19'/(1e12))
            legend(Top_Countries_strings)
            xlim([current_year 2059])
            % ylim([0 14e12])
            xlabel('Year')
            ylabel('Stranded Assets (USD $)')
            aY = gca;
            % exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualAssets_byCountry_global19.eps','ContentType','vector');  
            
            [~, indx] = maxk(nansum(CountryassetsUnique26_regional,2),5);%extracts the top 10
            Top_Countries_assets_regional26 = CountryassetsUnique26_regional(indx,:);
            RestofCountriesEmissions_regional26 = nansum(TotalStrandedAssets_Country_Regional_26,1)-nansum(Top_Countries_assets_regional26,1);
            CountryAssets_regional26 = [RestofCountriesEmissions_regional26' Top_Countries_assets_regional26']';
            Top_Countries_strings = cell(6,1);
            Top_Countries_strings(1,1) = {'REST OF WORLD'};
            Top_Countries_strings(2:end,1) = CountryStrings(indx(:,1),1);
            

            figure()
            bar(1,CountryAssets_regional26(:,1)/(1e12),'stacked')
            legend(Top_Countries_strings)
            ylim([0 25])
            ylabel('Stranded Assets (USD $)')
            aY = gca;
            exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualStrandings_byCountry_2_6_bar.eps','ContentType','vector');
            CountryAssets_regional26 = CountryAssets_regional26(:,1);

            % figure()
            % area(CarbonTaxYear(1:length(CountryAssets_global26)),CountryAssets_global26')
            % legend(Top_Countries_strings)
            % xlim([current_year 2059])
            % ylim([0 7e12])
            % xlabel('Year')
            % ylabel('Stranded Assets (USD $)')
            % aY = gca;
            % exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualAssets_byCountry_global26.eps','ContentType','vector');  

            [~, indx] = maxk(nansum(CountryassetsUnique19_regional,2),5);%extracts the top 10
            Top_Countries_assets_regional19 = CountryassetsUnique19_regional(indx,:);
            RestofCountriesEmissions_regional19 = nansum(TotalStrandedAssets_Country_Regional_19,1)-nansum(Top_Countries_assets_regional19,1);
            CountryAssets_regional19 = [RestofCountriesEmissions_regional19' Top_Countries_assets_regional19']';
            Top_Countries_strings = cell(6,1);
            Top_Countries_strings(1,1) = {'REST OF WORLD'};
            Top_Countries_strings(2:end,1) = CountryStrings(indx(:,1),1);

            figure()
            area(CarbonTaxYear(1:length(CountryAssets_regional19)),CountryAssets_regional19'/(1e12))
            legend(Top_Countries_strings)
            xlim([current_year 2059])
            xlabel('Year')
            ylabel('Stranded Assets (USD $)')
            % ylim([0 14e12])
            aY = gca;
            % exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualAssets_byCountry_regional19.eps','ContentType','vector');  

            [~, indx] = maxk(nansum(CountryassetsUnique26_regional,2),5);%extracts the top 10
            Top_Countries_assets_regional26 = CountryassetsUnique26_regional(indx,:);
            RestofCountriesEmissions_regional26 = nansum(TotalStrandedAssets_Country_Regional_26,1)-nansum(Top_Countries_assets_regional26,1);
            CountryAssets_regional26 = [RestofCountriesEmissions_regional26' Top_Countries_assets_regional26']';
            Top_Countries_strings = cell(6,1);
            Top_Countries_strings(1,1) = {'REST OF WORLD'};
            Top_Countries_strings(2:end,1) = CountryStrings(indx(:,1),1);

            figure()
            area(CarbonTaxYear(1:length(CountryAssets_regional26)),CountryAssets_regional26'/(1e12))
            legend(Top_Countries_strings)
            xlim([current_year 2059])
            % ylim([0 7e12])
            xlabel('Year')
            ylabel('Stranded Assets (USD $)')
            aY = gca;
            % exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualAssets_byCountry_regional26.eps','ContentType','vector');  
            % 
            
            TotalStrandedAssets_Company_Global_19 = [AnnualStrandedAssetByCompany19_globalpricing_Coal; AnnualStrandedAssetByCompany19_globalpricing_Gas];
            TotalStrandedAssets_Company_Global_26 = [AnnualStrandedAssetByCompany26_globalpricing_Coal; AnnualStrandedAssetByCompany26_globalpricing_Gas];
            
            TotalStrandedAssets_Company_Regional_26 = [AnnualStrandedAssetByCompany26_regionalpricing_Coal; AnnualStrandedAssetByCompany26_regionalpricing_Gas];
            TotalStrandedAssets_Company_Regional_19 = [AnnualStrandedAssetByCompany19_regionalpricing_Coal; AnnualStrandedAssetByCompany19_regionalpricing_Gas];
            
             CompanyAssetsUnique_global19 = zeros(length(CompanyStrings),50); CompanyAssetsUnique_global26 = zeros(length(CompanyStrings),50);
             CompanyAssetsUnique_regional19 = zeros(length(CompanyStrings),50); CompanyAssetsUnique_regional26 = zeros(length(CompanyStrings),50);
             
            
            for  i = 1:length(CompanyStrings)
                for j = 1:length(CompanyEmissions_strings)
                    if strcmpi(CompanyEmissions_strings{j,1},CompanyStrings{i,1})
                       CompanyAssetsUnique_global19(i,:) = CompanyAssetsUnique_global19(i,:) + TotalStrandedAssets_Company_Global_19(j,:);
                       CompanyAssetsUnique_global26(i,:) = CompanyAssetsUnique_global26(i,:) + TotalStrandedAssets_Company_Global_26(j,:);
                       CompanyAssetsUnique_regional19(i,:) = CompanyAssetsUnique_regional19(i,:) + TotalStrandedAssets_Company_Regional_19(j,:);
                       CompanyAssetsUnique_regional26(i,:) = CompanyAssetsUnique_regional26(i,:) + TotalStrandedAssets_Company_Regional_26(j,:);
                    end
                end
            end

            save('../Data/Results/CompanyAssetsUnique_regional19','CompanyAssetsUnique_regional19','CompanyEmissions_strings','CompanyStrings','AnnualStrandedAssetByCompany19_regionalpricing_Coal','AnnualStrandedAssetByCompany19_regionalpricing_Gas')
            NextNinety_Assets = maxk(CompanyAssetsUnique_regional19,100);%extracts the top 100 companies
            NextNinety_Assets = mink(NextNinety_Assets,90);%subtracts the top 10
            TopTen_Assets = maxk(CompanyAssetsUnique_regional19,10);
            
            RestStrandedAssets = nansum(CompanyAssetsUnique_regional19,1);
            NextNinety_Assets = nansum(NextNinety_Assets,1);
            TopTen_Assets = nansum(TopTen_Assets,1);
            RestStrandedAssets = RestStrandedAssets - NextNinety_Assets - TopTen_Assets;
            StrandedAssets = [RestStrandedAssets' NextNinety_Assets' TopTen_Assets'];
            
            figure()
            bar(1,StrandedAssets(1,:)/(1e12),'stacked')
            legend('Rest','Next 90','Top 10')
            ylim([0 25])
            ylabel('Stranded Assets (USD $)')
            aY = gca;
            exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualStrandings_byCompany_1_9_bar.eps','ContentType','vector');

            StrandedAssetsbycompany19 = StrandedAssets(1,:);

            figure()
            area(CarbonTaxYear(1:length(StrandedAssets)),StrandedAssets/(1e12))
            legend('Rest','Next 90','Top 10')
            % colororder(COLORS);
            xlim([current_year 2059])
            % ylim([0 14e12])
            xlabel('Year')
            ylabel('Stranded Assets ($-USD)')
            aY = gca;
            % exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualAssets_byCompany_global19.eps','ContentType','vector');  
            
            NextNinety_Assets = maxk(CompanyAssetsUnique_regional26,100);%extracts the top 100 companies
            NextNinety_Assets = mink(NextNinety_Assets,90);%subtracts the top 10
            TopTen_Assets = maxk(CompanyAssetsUnique_regional26,10);
            
            RestStrandedAssets = nansum(CompanyAssetsUnique_regional26,1);
            NextNinety_Assets = nansum(NextNinety_Assets,1);
            TopTen_Assets = nansum(TopTen_Assets,1);
            RestStrandedAssets = RestStrandedAssets - NextNinety_Assets - TopTen_Assets;
            StrandedAssets = [RestStrandedAssets' NextNinety_Assets' TopTen_Assets'];
            
            figure()
            bar(1,StrandedAssets(1,:)/(1e12),'stacked')
            legend('Rest','Next 90','Top 10')
            ylim([0 25])
            ylabel('Stranded Assets (USD $)')
            aY = gca;
            exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualStrandings_byCompany_2_6_bar.eps','ContentType','vector');

            StrandedAssetsbycompany26 = StrandedAssets(1,:);
            save('../Data/Results/figure_4_stats.mat','TotalStrandedAssets_Global_19_ByFuel','TotalStrandedAssets_Global_26_ByFuel','CountryAssets_regional19','CountryAssets_regional26','StrandedAssetsbycompany19','StrandedAssetsbycompany26')
            figure()
            area(CarbonTaxYear(1:length(StrandedAssets)),StrandedAssets/(1e12))
            legend('Rest','Next 90','Top 10')
            % colororder(COLORS);
            xlim([current_year 2059])
            % ylim([0 7e12])
            xlabel('Year')
            ylabel('Stranded Assets ($-USD)')
            aY = gca;
            % exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualAssets_byCompany_global26.eps','ContentType','vector');  
            
            NextNinety_Assets = maxk(CompanyAssetsUnique_regional19,100);%extracts the top 100 companies
            NextNinety_Assets = mink(NextNinety_Assets,90);%subtracts the top 10
            TopTen_Assets = maxk(CompanyAssetsUnique_regional19,10);

            RestStrandedAssets = nansum(CompanyAssetsUnique_regional19,1);
            NextNinety_Assets = nansum(NextNinety_Assets,1);
            TopTen_Assets = nansum(TopTen_Assets,1);
            RestStrandedAssets = RestStrandedAssets - NextNinety_Assets - TopTen_Assets;
            StrandedAssets = [RestStrandedAssets' NextNinety_Assets' TopTen_Assets'];

            figure()
            area(CarbonTaxYear(1:length(StrandedAssets)),StrandedAssets/(1e12))
            legend('Rest','Next 90','Top 10')
            % colororder(COLORS);
            xlim([current_year 2059])
            % ylim([0 14e12])
            xlabel('Year')
            ylabel('Stranded Assets ($-USD)')
            aY = gca;
            % exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualAssets_byCompany_regional19.eps','ContentType','vector');  

            NextNinety_Assets = maxk(CompanyAssetsUnique_regional26,100);%extracts the top 100 companies
            NextNinety_Assets = mink(NextNinety_Assets,90);%subtracts the top 10
            TopTen_Assets = maxk(CompanyAssetsUnique_regional26,10);

            RestStrandedAssets = nansum(CompanyAssetsUnique_regional26,1);
            NextNinety_Assets = nansum(NextNinety_Assets,1);
            TopTen_Assets = nansum(TopTen_Assets,1);
            RestStrandedAssets = RestStrandedAssets - NextNinety_Assets - TopTen_Assets;
            StrandedAssets = [RestStrandedAssets' NextNinety_Assets' TopTen_Assets'];
            StrandedAssets(StrandedAssets<0) = 0;

            figure()
            area(CarbonTaxYear(1:length(StrandedAssets)),StrandedAssets/(1e12))
            legend('Rest','Next 90','Top 10')
            % colororder(COLORS);
            xlim([current_year 2059])
            xlabel('Year')
            % ylim([0 7e12])
            ylabel('Stranded Assets ($-USD)')
            aY = gca;
            % exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualAssets_byCompany_regional26.eps','ContentType','vector');  
            % 

            
        end
    end
    
elseif section == 5%figure 2
    for gentype = FUEL
        load(['../Data/Results/' PowerPlantFuel{gentype} '_Plants']);
        load(['../Data/Results/' PowerPlantFuel{gentype} '_Plants_strings']);

        if gentype == 1
            OCC = Capital_costs_coal;
        else
            OCC = Capital_costs_gas;
        end
        
        if gentype == 1
            LifeLeft = mean_Life_coal - Plants(:,2);
            mean_Life = mean_Life_coal;
        elseif gentype == 2
            LifeLeft = mean_Life_gas - Plants(:,2);
            mean_Life = mean_Life_gas;
        end



%         if CombineFuelTypeResults ~= 1
%             if gentype == 1
%                 clear PowerPlantFinances_byCompany PowerPlantString_ByCompany
%                 load ../Data/Results/PowerPlantFinances_byCompany_Coal.mat
%                 load '../Data/Results/colorschemecategoryCoal2'
% 
%                 colorschemecategory = round(colorschemecategory);
%                 NewColorScheme = zeros(length(colorschemecategory),3);
% 
%                for i  = 1:length(colorschemecategory)%programed from illustrator RGB colors
%                     if colorschemecategory(i) == 1%United States
%                         NewColorScheme(i,:) = [245,157,51];%orange
%                     elseif colorschemecategory(i) == 6%Asia
%                         NewColorScheme(i,:) = [148,89,161];%purple
%                     elseif colorschemecategory(i) == 3%China
%                         NewColorScheme(i,:) = [238,53,48];%red
%                     elseif colorschemecategory(i) == 5%MAF  
%                         NewColorScheme(i,:) = [119,192,70];%green
%                     elseif colorschemecategory(i) == 2%LAM 
%                         NewColorScheme(i,:) = [47,57,131];%light blue
%                     elseif colorschemecategory(i) == 9%India
%                         NewColorScheme(i,:) = [240,233,94];%yellow
%                     elseif colorschemecategory(i) == 4%Europe
%                         NewColorScheme(i,:) = [107,139,193];
%                     elseif colorschemecategory(i) == 8%Row
%                         NewColorScheme(i,:) = [194,31,79];%light purple
%                    elseif colorschemecategory(i) == 7%REF
%                         NewColorScheme(i,:) = [74,186,183];%aqua
%                     end
%                end 
% for I = COUNTRY
%     CountryINDEX = find(colorschemecategory == I);
% 
% 
%                 PresentAssetValue = PresentAssetValuebyCompany(CountryINDEX,1);
%                 GlobalStrandedAssetValue19 = StrandedAssetValuebyCompany(CountryINDEX,1);
%                 PowerPlantString_ByCompany = PowerPlantString_ByCompany(CountryINDEX,1);
%                 colorschemecategory = colorschemecategory(CountryINDEX,1);
% 
%                 [TopTen_StrandedAssets19 indx] =maxk(GlobalStrandedAssetValue19,10);
%                 TopTen_CompanyNames = PowerPlantString_ByCompany(indx,1);
%                 TopColors = NewColorScheme(indx,:);
% 
%                  figure()
%                 pie(TopTen_StrandedAssets19,TopTen_CompanyNames)
%                 aY = gca;
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_TopTenCompanies_StrandedAssets_coal_global19.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_TopTenCompanies_StrandedAssets_coal_global19.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_TopTenCompanies_StrandedAssets_coal_global19.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_TopTenCompanies_StrandedAssets_coal_global19.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_TopTenCompanies_StrandedAssets_coal_global19.eps','ContentType','vector');
%                 end
% 
% 
%                 TopTenPercentStranded = TopTen_StrandedAssets19./PresentAssetValue(indx,:);
% 
%                 TopStrandingsMatrix = nan(length(TopTenPercentStranded),5);
%                 TopStrandingsMatrix(:,1) = TopTenPercentStranded;
%                 TopStrandingsMatrix(:,2:4) = TopColors;
% 
% 
%                 [TopStrandingsMatrix indx] = sortrows(TopStrandingsMatrix,1);
%                 TopTenPercentStranded = TopStrandingsMatrix(:,1);
%                 TopColors = TopStrandingsMatrix(:,2:4);
% 
%                 TopTen_CompanyNames = TopTen_CompanyNames(indx);
% 
%                 PERCENT19 = TopTenPercentStranded; 
%                 TOP19 = TopTen_CompanyNames;
%                 TOPSTRANDED = TopTen_StrandedAssets19;
%                 TOPPRESENTVALUE = PresentAssetValue(indx,:);
% 
%                 [NextNinety_StrandedAssets indx] =maxk(GlobalStrandedAssetValue19,100);%extracts the top 100 companies
%                 NextNinety_CompanyNames = PowerPlantString_ByCompany(indx,1);
%                 NextNinety_PresentValue = PresentAssetValue(indx,:);
%                 NextColors = NewColorScheme(indx,:);
% 
%                 [NextNinety_StrandedAssets indx] =mink(NextNinety_StrandedAssets,90);%subtracts the top 10
%                 NextNinety_CompanyNames = NextNinety_CompanyNames(indx,1);
%                 NextNinetyPercentStranded = NextNinety_StrandedAssets./NextNinety_PresentValue(indx,1);
%                 NextColors = NextColors(indx,:);
% 
% 
% 
%                 Next90StrandingsMatrix = nan(length(NextNinetyPercentStranded),5);
%                 Next90StrandingsMatrix(:,1) = NextNinetyPercentStranded;
%                 Next90StrandingsMatrix(:,2:4) = NextColors;
% 
% 
%                 [Next90StrandingsMatrix indx]= sortrows(Next90StrandingsMatrix,1);
%                 NextNinetyPercentStranded = Next90StrandingsMatrix(:,1);
%                 NextColors = Next90StrandingsMatrix(:,2:4);
%                 NextNinety_CompanyNames = NextNinety_CompanyNames(indx);
% 
% 
% %                 save('../Data/Results/TopTen_StrandedAssets19_Coal','TopTen_StrandedAssets19','TopTen_CompanyNames');
% 
%                 Next90_StrandedAssets = TopTen_StrandedAssets19;
%                 Next90_CompanyNames = TopTen_CompanyNames;
% 
%                 Next90_StrandedAssets(length(Next90_StrandedAssets)+1,1) = nansum(NextNinety_StrandedAssets);
%                 Next90_CompanyNames{length(Next90_CompanyNames)+1,1} = 'Next ninety';
% 
% 
% 
%                 figure()
%                 pie(Next90_StrandedAssets,Next90_CompanyNames)
%                 aY = gca;
% %                 exportgraphics(aY,'../Plots/Figure - pie graphs/NextNinetyCompanies_StrandedAssets_coal_global19.eps','ContentType','vector');
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_NextNinetyCompanies_StrandedAssets_coal_global19.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_NextNinetyCompanies_StrandedAssets_coal_global19.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_NextNinetyCompanies_StrandedAssets_coal_global19.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_NextNinetyCompanies_StrandedAssets_coal_global19.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_NextNinetyCompanies_StrandedAssets_coal_global19.eps','ContentType','vector');
%                 end
% 
%                 edges = zeros(length(TopTenPercentStranded)+1,1);
%                 edges(2:end,1) = 1:1:length(edges)-1;
%                 vals = TopTenPercentStranded;
%                 center = (edges(1:end-1) + edges(2:end))/2;
%                 width = diff(edges);
% 
%                 TopColors = TopColors./255;%rescales to matlab RGB format
% 
%                 figure()
%                 hold on
%                 for i=1:length(center)
%                 barh(center(i),vals(i),'FaceColor',TopColors(i,:))
%                 end
%                 hold off
%                 cx = gca;
%                 xlim([0 1])
% %                 exportgraphics(cx,['../Plots/Figure - pie graphs/PercentAssetValue_top10_coal_global19.eps'],'ContentType','vector');
% %                 save('../Data/Results/TopTen_StrandedAssets19_Coal','TopTen_StrandedAssets19','TopTen_CompanyNames','TopTenPercentStranded','TopColors');
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_PercentAssetValue_top10_coal_global19.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_PercentAssetValue_top10_coal_global19.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_PercentAssetValue_top10_coal_global19.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_PercentAssetValue_top10_coal_global19.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_PercentAssetValue_top10_coal_global19.eps','ContentType','vector');
%                 end
% 
%                 edges = zeros(length(NextNinetyPercentStranded)+1,1);
%                 edges(2:end,1) = 1:1:length(edges)-1;
%                 vals = NextNinetyPercentStranded;
%                 center = (edges(1:end-1) + edges(2:end))/2;
%                 width = diff(edges);
% 
%                 NextColors = NextColors./255;%rescales to matlab RGB format
% 
%                 figure()
%                 hold on
%                 for i=1:length(center)
%                 barh(center(i),vals(i),'FaceColor',NextColors(i,:))
%                 end
%                 hold off
%                 cx = gca;
%                 xlim([0 1])
% %                 exportgraphics(cx,['../Plots/Figure - pie graphs/PercentAssetValue_next90_coal_global19.eps'],'ContentType','vector');
% %                 save('../Data/Results/Next90_StrandedAssets19_Coal','NextNinety_StrandedAssets','NextNinety_CompanyNames','NextNinetyPercentStranded','NextColors');
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_PercentAssetValue_next90_coal_global19.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_PercentAssetValue_next90_coal_global19.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_PercentAssetValue_next90_coal_global19.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_PercentAssetValue_next90_coal_global19.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_PercentAssetValue_next90_coal_global19.eps','ContentType','vector');
%                 end
% 
%                 GlobalStrandedAssetValue26 = StrandedAssetValuebyCompany(CountryINDEX,3); 
% 
%                 [TopTen_StrandedAssets26 indx] =maxk(GlobalStrandedAssetValue26,10);
%                 TopTen_CompanyNames = PowerPlantString_ByCompany(indx,1);
%                 TopTenPercentStranded = TopTen_StrandedAssets26./PresentAssetValue(indx,:);
%                 TopColors = NewColorScheme(indx,:);
% 
% 
%                  figure()
%                 pie(TopTen_StrandedAssets26,TopTen_CompanyNames)
%                 aY = gca;
% %                 exportgraphics(aY,'../Plots/Figure - pie graphs/TopTenCompanies_StrandedAssets_coal_global26.eps','ContentType','vector');
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_TopTenCompanies_StrandedAssets_coal_global26.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_TopTenCompanies_StrandedAssets_coal_global26.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_TopTenCompanies_StrandedAssets_coal_global26.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_TopTenCompanies_StrandedAssets_coal_global26.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_TopTenCompanies_StrandedAssets_coal_global26.eps','ContentType','vector');
%                 end
% 
% 
%                 TopStrandingsMatrix = nan(length(TopTenPercentStranded),5);
%                 TopStrandingsMatrix(:,1) = TopTenPercentStranded;
%                 TopStrandingsMatrix(:,2:4) = TopColors;
% 
% 
%                 [TopStrandingsMatrix indx] = sortrows(TopStrandingsMatrix,1);
%                 TopTenPercentStranded = TopStrandingsMatrix(:,1);
%                 TopColors = TopStrandingsMatrix(:,2:4);
% 
% 
%                 [NextNinety_StrandedAssets indx] =maxk(GlobalStrandedAssetValue26,100);%extracts the top 100 companies
%                 NextNinety_CompanyNames = PowerPlantString_ByCompany(indx,1);
%                 NextNinety_PresentValue = PresentAssetValue(indx,:);
%                 NextColors = NewColorScheme(indx,:);
% 
%                 [NextNinety_StrandedAssets indx] =mink(NextNinety_StrandedAssets,90);%subtracts the top 10
%                 NextNinety_CompanyNames = NextNinety_CompanyNames(indx,1);
%                 NextNinetyPercentStranded = NextNinety_StrandedAssets./NextNinety_PresentValue(indx,1);
%                 NextColors = NextColors(indx,:);  
% 
% 
% 
% 
%                 Next90StrandingsMatrix = nan(length(NextNinetyPercentStranded),5);
%                 Next90StrandingsMatrix(:,1) = NextNinetyPercentStranded;
%                 Next90StrandingsMatrix(:,2:4) = NextColors;
% 
% 
%                 [Next90StrandingsMatrix indx]= sortrows(Next90StrandingsMatrix,1);
%                 NextNinetyPercentStranded = Next90StrandingsMatrix(:,1);
%                 NextColors = Next90StrandingsMatrix(:,2:4);
%                 NextNinety_CompanyNames = NextNinety_CompanyNames(indx);
% 
% 
% 
%                 Next90_StrandedAssets = TopTen_StrandedAssets26;
%                 Next90_CompanyNames = TopTen_CompanyNames;
% 
%                 Next90_StrandedAssets(length(Next90_StrandedAssets)+1,1) = nansum(NextNinety_StrandedAssets);
%                 Next90_CompanyNames{length(Next90_CompanyNames)+1,1} = 'Next ninety';
% 
%                 figure()
%                 pie(Next90_StrandedAssets,Next90_CompanyNames)
%                 aY = gca;
% %                 exportgraphics(aY,'../Plots/Figure - pie graphs/NextNianetyCompanies_StrandedAssets_coal_global26.eps','ContentType','vector');
% 
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_NextNinetyCompanies_StrandedAssets_coal_global26.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_NextNinetyCompanies_StrandedAssets_coal_global26.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_NextNinetyCompanies_StrandedAssets_coal_global26.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_NextNinetyCompanies_StrandedAssets_coal_global26.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_NextNinetyCompanies_StrandedAssets_coal_global26.eps','ContentType','vector');
%                 end
% 
%                 edges = zeros(length(TopTenPercentStranded)+1,1);
%                 edges(2:end,1) = 1:1:length(edges)-1;
%                 vals = TopTenPercentStranded;
%                 center = (edges(1:end-1) + edges(2:end))/2;
%                 width = diff(edges);
% 
%                 TopColors = TopColors./255;%rescales to matlab RGB format
% 
%                 figure()
%                 hold on
%                 for i=1:length(center)
%                 barh(center(i),vals(i),'FaceColor',TopColors(i,:))
%                 end
%                 hold off
%                 cx = gca;
%                 xlim([0 1])
% %                 exportgraphics(cx,['../Plots/Figure - pie graphs/PercentAssetValue_top10_coal_global26.eps'],'ContentType','vector');
% %                 save('../Data/Results/TopTen_StrandedAssets26_Coal','TopTen_StrandedAssets26','TopTen_CompanyNames','TopTenPercentStranded','TopColors');
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_PercentAssetValue_top10_coal_global26.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_PercentAssetValue_top10_coal_global26.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_PercentAssetValue_top10_coal_global26.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_PercentAssetValue_top10_coal_global26.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_PercentAssetValue_top10_coal_global26.eps','ContentType','vector');
%                 end
% 
% 
%                 edges = zeros(length(NextNinetyPercentStranded)+1,1);
%                 edges(2:end,1) = 1:1:length(edges)-1;
%                 vals = NextNinetyPercentStranded;
%                 center = (edges(1:end-1) + edges(2:end))/2;
%                 width = diff(edges);
% 
%                 NextColors = NextColors./255;%rescales to matlab RGB format
% 
%                 figure()
%                 hold on
%                 for i=1:length(center)
%                 barh(center(i),vals(i),'FaceColor',NextColors(i,:))
%                 end
%                 hold off
%                 cx = gca;
%                 xlim([0 1])
% %                 exportgraphics(cx,['../Plots/Figure - pie graphs/PercentAssetValue_next90_coal_global26.eps'],'ContentType','vector');
% %                 save('../Data/Results/Next90_StrandedAssets26_Coal','NextNinety_StrandedAssets','NextNinety_CompanyNames','NextNinetyPercentStranded','NextColors');
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_PercentAssetValue_next90_coal_global26.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_PercentAssetValue_next90_coal_global26.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_PercentAssetValue_next90_coal_global26.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_PercentAssetValue_next90_coal_global26.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_PercentAssetValue_top10_coal_global26.eps','ContentType','vector');
%                 end
% 
% end
%             elseif gentype == 2
% 
%                 clear PowerPlantFinances_byCompany PowerPlantString_ByCompany
%                 load ../Data/Results/PowerPlantFinances_byCompany_Gas.mat
%                 load '../Data/Results/colorschemecategoryGas2'
% 
%                 colorschemecategory = round(colorschemecategory);
%                 NewColorScheme = zeros(length(colorschemecategory),3);
% 
%                for i  = 1:length(colorschemecategory)%programed from illustrator RGB colors
%                     if colorschemecategory(i) == 1%United States
%                         NewColorScheme(i,:) = [245,157,51];%orange
%                     elseif colorschemecategory(i) == 6%Asia
%                         NewColorScheme(i,:) = [148,89,161];%purple
%                     elseif colorschemecategory(i) == 3%China
%                         NewColorScheme(i,:) = [238,53,48];%red
%                     elseif colorschemecategory(i) == 5%MAF  
%                         NewColorScheme(i,:) = [119,192,70];%green
%                     elseif colorschemecategory(i) == 2%LAM 
%                         NewColorScheme(i,:) = [47,57,131];%light blue
%                     elseif colorschemecategory(i) == 9%India
%                         NewColorScheme(i,:) = [240,233,94];%yellow
%                     elseif colorschemecategory(i) == 4%Europe
%                         NewColorScheme(i,:) = [107,139,193];
%                     elseif colorschemecategory(i) == 8%Row
%                         NewColorScheme(i,:) = [194,31,79];%light purple
%                    elseif colorschemecategory(i) == 7%REF
%                         NewColorScheme(i,:) = [74,186,183];%aqua
%                     end
%                end 
% for I = COUNTRY
%     CountryINDEX = find(colorschemecategory == I);
% 
% 
%                 PresentAssetValue = PresentAssetValuebyCompany(CountryINDEX,1);
%                 GlobalStrandedAssetValue19 = StrandedAssetValuebyCompany(CountryINDEX,1);
%                 PowerPlantString_ByCompany = PowerPlantString_ByCompany(CountryINDEX,1);
%                 colorschemecategory = colorschemecategory(CountryINDEX,1);
% 
%                 [TopTen_StrandedAssets19 indx] =maxk(GlobalStrandedAssetValue19,10);
%                 TopTen_CompanyNames = PowerPlantString_ByCompany(indx,1);
%                 TopColors = NewColorScheme(indx,:);
% 
%                  figure()
%                 pie(TopTen_StrandedAssets19,TopTen_CompanyNames)
%                 aY = gca;
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_TopTenCompanies_StrandedAssets_Gas_global19.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_TopTenCompanies_StrandedAssets_Gas_global19.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_TopTenCompanies_StrandedAssets_Gas_global19.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_TopTenCompanies_StrandedAssets_Gas_global19.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_TopTenCompanies_StrandedAssets_Gas_global19.eps','ContentType','vector');
%                 end
% 
% 
%                 TopTenPercentStranded = TopTen_StrandedAssets19./PresentAssetValue(indx,:);
% 
%                 TopStrandingsMatrix = nan(length(TopTenPercentStranded),5);
%                 TopStrandingsMatrix(:,1) = TopTenPercentStranded;
%                 TopStrandingsMatrix(:,2:4) = TopColors;
% 
% 
%                 [TopStrandingsMatrix indx] = sortrows(TopStrandingsMatrix,1);
%                 TopTenPercentStranded = TopStrandingsMatrix(:,1);
%                 TopColors = TopStrandingsMatrix(:,2:4);
% 
%                 TopTen_CompanyNames = TopTen_CompanyNames(indx);
% 
%                 PERCENT19 = TopTenPercentStranded; 
%                 TOP19 = TopTen_CompanyNames;
%                 TOPSTRANDED = TopTen_StrandedAssets19;
%                 TOPPRESENTVALUE = PresentAssetValue(indx,:);
% 
%                 [NextNinety_StrandedAssets indx] =maxk(GlobalStrandedAssetValue19,100);%extracts the top 100 companies
%                 NextNinety_CompanyNames = PowerPlantString_ByCompany(indx,1);
%                 NextNinety_PresentValue = PresentAssetValue(indx,:);
%                 NextColors = NewColorScheme(indx,:);
% 
%                 [NextNinety_StrandedAssets indx] =mink(NextNinety_StrandedAssets,90);%subtracts the top 10
%                 NextNinety_CompanyNames = NextNinety_CompanyNames(indx,1);
%                 NextNinetyPercentStranded = NextNinety_StrandedAssets./NextNinety_PresentValue(indx,1);
%                 NextColors = NextColors(indx,:);
% 
% 
% 
%                 Next90StrandingsMatrix = nan(length(NextNinetyPercentStranded),5);
%                 Next90StrandingsMatrix(:,1) = NextNinetyPercentStranded;
%                 Next90StrandingsMatrix(:,2:4) = NextColors;
% 
% 
%                 [Next90StrandingsMatrix indx]= sortrows(Next90StrandingsMatrix,1);
%                 NextNinetyPercentStranded = Next90StrandingsMatrix(:,1);
%                 NextColors = Next90StrandingsMatrix(:,2:4);
%                 NextNinety_CompanyNames = NextNinety_CompanyNames(indx);
% 
% 
% %                 save('../Data/Results/TopTen_StrandedAssets19_Gas','TopTen_StrandedAssets19','TopTen_CompanyNames');
% 
%                 Next90_StrandedAssets = TopTen_StrandedAssets19;
%                 Next90_CompanyNames = TopTen_CompanyNames;
% 
%                 Next90_StrandedAssets(length(Next90_StrandedAssets)+1,1) = nansum(NextNinety_StrandedAssets);
%                 Next90_CompanyNames{length(Next90_CompanyNames)+1,1} = 'Next ninety';
% 
% 
% 
%                 figure()
%                 pie(Next90_StrandedAssets,Next90_CompanyNames)
%                 aY = gca;
% %                 exportgraphics(aY,'../Plots/Figure - pie graphs/NextNinetyCompanies_StrandedAssets_Gas_global19.eps','ContentType','vector');
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_NextNinetyCompanies_StrandedAssets_Gas_global19.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_NextNinetyCompanies_StrandedAssets_Gas_global19.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_NextNinetyCompanies_StrandedAssets_Gas_global19.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_NextNinetyCompanies_StrandedAssets_Gas_global19.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_NextNinetyCompanies_StrandedAssets_Gas_global19.eps','ContentType','vector');
%                 end
% 
%                 edges = zeros(length(TopTenPercentStranded)+1,1);
%                 edges(2:end,1) = 1:1:length(edges)-1;
%                 vals = TopTenPercentStranded;
%                 center = (edges(1:end-1) + edges(2:end))/2;
%                 width = diff(edges);
% 
%                 TopColors = TopColors./255;%rescales to matlab RGB format
% 
%                 figure()
%                 hold on
%                 for i=1:length(center)
%                 barh(center(i),vals(i),'FaceColor',TopColors(i,:))
%                 end
%                 hold off
%                 cx = gca;
%                 xlim([0 1])
% %                 exportgraphics(cx,['../Plots/Figure - pie graphs/PercentAssetValue_top10_Gas_global19.eps'],'ContentType','vector');
% %                 save('../Data/Results/TopTen_StrandedAssets19_Gas','TopTen_StrandedAssets19','TopTen_CompanyNames','TopTenPercentStranded','TopColors');
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_PercentAssetValue_top10_Gas_global19.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_PercentAssetValue_top10_Gas_global19.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_PercentAssetValue_top10_Gas_global19.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_PercentAssetValue_top10_Gas_global19.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_PercentAssetValue_top10_Gas_global19.eps','ContentType','vector');
%                 end
% 
%                 edges = zeros(length(NextNinetyPercentStranded)+1,1);
%                 edges(2:end,1) = 1:1:length(edges)-1;
%                 vals = NextNinetyPercentStranded;
%                 center = (edges(1:end-1) + edges(2:end))/2;
%                 width = diff(edges);
% 
%                 NextColors = NextColors./255;%rescales to matlab RGB format
% 
%                 figure()
%                 hold on
%                 for i=1:length(center)
%                 barh(center(i),vals(i),'FaceColor',NextColors(i,:))
%                 end
%                 hold off
%                 cx = gca;
%                 xlim([0 1])
% %                 exportgraphics(cx,['../Plots/Figure - pie graphs/PercentAssetValue_next90_Gas_global19.eps'],'ContentType','vector');
% %                 save('../Data/Results/Next90_StrandedAssets19_Gas','NextNinety_StrandedAssets','NextNinety_CompanyNames','NextNinetyPercentStranded','NextColors');
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_PercentAssetValue_next90_Gas_global19.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_PercentAssetValue_next90_Gas_global19.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_PercentAssetValue_next90_Gas_global19.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_PercentAssetValue_next90_Gas_global19.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_PercentAssetValue_next90_Gas_global19.eps','ContentType','vector');
%                 end
% 
%                 GlobalStrandedAssetValue26 = StrandedAssetValuebyCompany(CountryINDEX,3); 
% 
%                 [TopTen_StrandedAssets26 indx] =maxk(GlobalStrandedAssetValue26,10);
%                 TopTen_CompanyNames = PowerPlantString_ByCompany(indx,1);
%                 TopTenPercentStranded = TopTen_StrandedAssets26./PresentAssetValue(indx,:);
%                 TopColors = NewColorScheme(indx,:);
% 
% 
%                  figure()
%                 pie(TopTen_StrandedAssets26,TopTen_CompanyNames)
%                 aY = gca;
% %                 exportgraphics(aY,'../Plots/Figure - pie graphs/TopTenCompanies_StrandedAssets_Gas_global26.eps','ContentType','vector');
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_TopTenCompanies_StrandedAssets_Gas_global26.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_TopTenCompanies_StrandedAssets_Gas_global26.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_TopTenCompanies_StrandedAssets_Gas_global26.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_TopTenCompanies_StrandedAssets_Gas_global26.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_TopTenCompanies_StrandedAssets_Gas_global26.eps','ContentType','vector');
%                 end
% 
% 
%                 TopStrandingsMatrix = nan(length(TopTenPercentStranded),5);
%                 TopStrandingsMatrix(:,1) = TopTenPercentStranded;
%                 TopStrandingsMatrix(:,2:4) = TopColors;
% 
% 
%                 [TopStrandingsMatrix indx] = sortrows(TopStrandingsMatrix,1);
%                 TopTenPercentStranded = TopStrandingsMatrix(:,1);
%                 TopColors = TopStrandingsMatrix(:,2:4);
% 
% 
%                 [NextNinety_StrandedAssets indx] =maxk(GlobalStrandedAssetValue26,100);%extracts the top 100 companies
%                 NextNinety_CompanyNames = PowerPlantString_ByCompany(indx,1);
%                 NextNinety_PresentValue = PresentAssetValue(indx,:);
%                 NextColors = NewColorScheme(indx,:);
% 
%                 [NextNinety_StrandedAssets indx] =mink(NextNinety_StrandedAssets,90);%subtracts the top 10
%                 NextNinety_CompanyNames = NextNinety_CompanyNames(indx,1);
%                 NextNinetyPercentStranded = NextNinety_StrandedAssets./NextNinety_PresentValue(indx,1);
%                 NextColors = NextColors(indx,:);  
% 
% 
% 
% 
%                 Next90StrandingsMatrix = nan(length(NextNinetyPercentStranded),5);
%                 Next90StrandingsMatrix(:,1) = NextNinetyPercentStranded;
%                 Next90StrandingsMatrix(:,2:4) = NextColors;
% 
% 
%                 [Next90StrandingsMatrix indx]= sortrows(Next90StrandingsMatrix,1);
%                 NextNinetyPercentStranded = Next90StrandingsMatrix(:,1);
%                 NextColors = Next90StrandingsMatrix(:,2:4);
%                 NextNinety_CompanyNames = NextNinety_CompanyNames(indx);
% 
% 
% 
%                 Next90_StrandedAssets = TopTen_StrandedAssets26;
%                 Next90_CompanyNames = TopTen_CompanyNames;
% 
%                 Next90_StrandedAssets(length(Next90_StrandedAssets)+1,1) = nansum(NextNinety_StrandedAssets);
%                 Next90_CompanyNames{length(Next90_CompanyNames)+1,1} = 'Next ninety';
% 
%                 figure()
%                 pie(Next90_StrandedAssets,Next90_CompanyNames)
%                 aY = gca;
% %                 exportgraphics(aY,'../Plots/Figure - pie graphs/NextNianetyCompanies_StrandedAssets_Gas_global26.eps','ContentType','vector');
% 
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_NextNinetyCompanies_StrandedAssets_Gas_global26.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_NextNinetyCompanies_StrandedAssets_Gas_global26.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_NextNinetyCompanies_StrandedAssets_Gas_global26.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_NextNinetyCompanies_StrandedAssets_Gas_global26.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_NextNinetyCompanies_StrandedAssets_Gas_global26.eps','ContentType','vector');
%                 end
% 
%                 edges = zeros(length(TopTenPercentStranded)+1,1);
%                 edges(2:end,1) = 1:1:length(edges)-1;
%                 vals = TopTenPercentStranded;
%                 center = (edges(1:end-1) + edges(2:end))/2;
%                 width = diff(edges);
% 
%                 TopColors = TopColors./255;%rescales to matlab RGB format
% 
%                 figure()
%                 hold on
%                 for i=1:length(center)
%                 barh(center(i),vals(i),'FaceColor',TopColors(i,:))
%                 end
%                 hold off
%                 cx = gca;
%                 xlim([0 1])
% %                 exportgraphics(cx,['../Plots/Figure - pie graphs/PercentAssetValue_top10_Gas_global26.eps'],'ContentType','vector');
% %                 save('../Data/Results/TopTen_StrandedAssets26_Gas','TopTen_StrandedAssets26','TopTen_CompanyNames','TopTenPercentStranded','TopColors');
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_PercentAssetValue_top10_Gas_global26.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_PercentAssetValue_top10_Gas_global26.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_PercentAssetValue_top10_Gas_global26.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_PercentAssetValue_top10_Gas_global26.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_PercentAssetValue_top10_Gas_global26.eps','ContentType','vector');
%                 end
% 
% 
%                 edges = zeros(length(NextNinetyPercentStranded)+1,1);
%                 edges(2:end,1) = 1:1:length(edges)-1;
%                 vals = NextNinetyPercentStranded;
%                 center = (edges(1:end-1) + edges(2:end))/2;
%                 width = diff(edges);
% 
%                 NextColors = NextColors./255;%rescales to matlab RGB format
% 
%                 figure()
%                 hold on
%                 for i=1:length(center)
%                 barh(center(i),vals(i),'FaceColor',NextColors(i,:))
%                 end
%                 hold off
%                 cx = gca;
%                 xlim([0 1])
% %                 exportgraphics(cx,['../Plots/Figure - pie graphs/PercentAssetValue_next90_Gas_global26.eps'],'ContentType','vector');
% %                 save('../Data/Results/Next90_StrandedAssets26_Gas','NextNinety_StrandedAssets','NextNinety_CompanyNames','NextNinetyPercentStranded','NextColors');
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_PercentAssetValue_next90_Gas_global26.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_PercentAssetValue_next90_Gas_global26.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_PercentAssetValue_next90_Gas_global26.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_PercentAssetValue_next90_Gas_global26.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_PercentAssetValue_top10_Gas_global26.eps','ContentType','vector');
%                 end
% 
% end
% 
% 
% 
%             elseif gentype ==3
% 
%                 clear PowerPlantFinances_byCompany PowerPlantString_ByCompany
%                 load ../Data/Results/PowerPlantFinances_byCompany_Oil.mat
%                 load '../Data/Results/colorschemecategoryOil2'
% 
%                 colorschemecategory = round(colorschemecategory);
%                 NewColorScheme = zeros(length(colorschemecategory),3);
% 
%                for i  = 1:length(colorschemecategory)%programed from illustrator RGB colors
%                     if colorschemecategory(i) == 1%United States
%                         NewColorScheme(i,:) = [245,157,51];%orange
%                     elseif colorschemecategory(i) == 6%Asia
%                         NewColorScheme(i,:) = [148,89,161];%purple
%                     elseif colorschemecategory(i) == 3%China
%                         NewColorScheme(i,:) = [238,53,48];%red
%                     elseif colorschemecategory(i) == 5%MAF  
%                         NewColorScheme(i,:) = [119,192,70];%green
%                     elseif colorschemecategory(i) == 2%LAM 
%                         NewColorScheme(i,:) = [47,57,131];%light blue
%                     elseif colorschemecategory(i) == 9%India
%                         NewColorScheme(i,:) = [240,233,94];%yellow
%                     elseif colorschemecategory(i) == 4%Europe
%                         NewColorScheme(i,:) = [107,139,193];
%                     elseif colorschemecategory(i) == 8%Row
%                         NewColorScheme(i,:) = [194,31,79];%light purple
%                    elseif colorschemecategory(i) == 7%REF
%                         NewColorScheme(i,:) = [74,186,183];%aqua
%                     end
%                end 
% for I = COUNTRY
%     CountryINDEX = find(colorschemecategory == I);
% 
% 
%                 PresentAssetValue = PresentAssetValuebyCompany(CountryINDEX,1);
%                 GlobalStrandedAssetValue19 = StrandedAssetValuebyCompany(CountryINDEX,1);
%                 PowerPlantString_ByCompany = PowerPlantString_ByCompany(CountryINDEX,1);
%                 colorschemecategory = colorschemecategory(CountryINDEX,1);
% 
%                 [TopTen_StrandedAssets19 indx] =maxk(GlobalStrandedAssetValue19,10);
%                 TopTen_CompanyNames = PowerPlantString_ByCompany(indx,1);
%                 TopColors = NewColorScheme(indx,:);
% 
%                  figure()
%                 pie(TopTen_StrandedAssets19,TopTen_CompanyNames)
%                 aY = gca;
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_TopTenCompanies_StrandedAssets_Oil_global19.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_TopTenCompanies_StrandedAssets_Oil_global19.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_TopTenCompanies_StrandedAssets_Oil_global19.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_TopTenCompanies_StrandedAssets_Oil_global19.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_TopTenCompanies_StrandedAssets_Oil_global19.eps','ContentType','vector');
%                 end
% 
% 
%                 TopTenPercentStranded = TopTen_StrandedAssets19./PresentAssetValue(indx,:);
% 
%                 TopStrandingsMatrix = nan(length(TopTenPercentStranded),5);
%                 TopStrandingsMatrix(:,1) = TopTenPercentStranded;
%                 TopStrandingsMatrix(:,2:4) = TopColors;
% 
% 
%                 [TopStrandingsMatrix indx] = sortrows(TopStrandingsMatrix,1);
%                 TopTenPercentStranded = TopStrandingsMatrix(:,1);
%                 TopColors = TopStrandingsMatrix(:,2:4);
% 
%                 TopTen_CompanyNames = TopTen_CompanyNames(indx);
% 
%                 PERCENT19 = TopTenPercentStranded; 
%                 TOP19 = TopTen_CompanyNames;
%                 TOPSTRANDED = TopTen_StrandedAssets19;
%                 TOPPRESENTVALUE = PresentAssetValue(indx,:);
% 
%                 [NextNinety_StrandedAssets indx] =maxk(GlobalStrandedAssetValue19,100);%extracts the top 100 companies
%                 NextNinety_CompanyNames = PowerPlantString_ByCompany(indx,1);
%                 NextNinety_PresentValue = PresentAssetValue(indx,:);
%                 NextColors = NewColorScheme(indx,:);
% 
%                 [NextNinety_StrandedAssets indx] =mink(NextNinety_StrandedAssets,90);%subtracts the top 10
%                 NextNinety_CompanyNames = NextNinety_CompanyNames(indx,1);
%                 NextNinetyPercentStranded = NextNinety_StrandedAssets./NextNinety_PresentValue(indx,1);
%                 NextColors = NextColors(indx,:);
% 
% 
% 
%                 Next90StrandingsMatrix = nan(length(NextNinetyPercentStranded),5);
%                 Next90StrandingsMatrix(:,1) = NextNinetyPercentStranded;
%                 Next90StrandingsMatrix(:,2:4) = NextColors;
% 
% 
%                 [Next90StrandingsMatrix indx]= sortrows(Next90StrandingsMatrix,1);
%                 NextNinetyPercentStranded = Next90StrandingsMatrix(:,1);
%                 NextColors = Next90StrandingsMatrix(:,2:4);
%                 NextNinety_CompanyNames = NextNinety_CompanyNames(indx);
% 
% 
% %                 save('../Data/Results/TopTen_StrandedAssets19_Oil','TopTen_StrandedAssets19','TopTen_CompanyNames');
% 
%                 Next90_StrandedAssets = TopTen_StrandedAssets19;
%                 Next90_CompanyNames = TopTen_CompanyNames;
% 
%                 Next90_StrandedAssets(length(Next90_StrandedAssets)+1,1) = nansum(NextNinety_StrandedAssets);
%                 Next90_CompanyNames{length(Next90_CompanyNames)+1,1} = 'Next ninety';
% 
% 
% 
%                 figure()
%                 pie(Next90_StrandedAssets,Next90_CompanyNames)
%                 aY = gca;
% %                 exportgraphics(aY,'../Plots/Figure - pie graphs/NextNinetyCompanies_StrandedAssets_Oil_global19.eps','ContentType','vector');
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_NextNinetyCompanies_StrandedAssets_Oil_global19.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_NextNinetyCompanies_StrandedAssets_Oil_global19.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_NextNinetyCompanies_StrandedAssets_Oil_global19.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_NextNinetyCompanies_StrandedAssets_Oil_global19.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_NextNinetyCompanies_StrandedAssets_Oil_global19.eps','ContentType','vector');
%                 end
% 
%                 edges = zeros(length(TopTenPercentStranded)+1,1);
%                 edges(2:end,1) = 1:1:length(edges)-1;
%                 vals = TopTenPercentStranded;
%                 center = (edges(1:end-1) + edges(2:end))/2;
%                 width = diff(edges);
% 
%                 TopColors = TopColors./255;%rescales to matlab RGB format
% 
%                 figure()
%                 hold on
%                 for i=1:length(center)
%                 barh(center(i),vals(i),'FaceColor',TopColors(i,:))
%                 end
%                 hold off
%                 cx = gca;
%                 xlim([0 1])
% %                 exportgraphics(cx,['../Plots/Figure - pie graphs/PercentAssetValue_top10_Oil_global19.eps'],'ContentType','vector');
% %                 save('../Data/Results/TopTen_StrandedAssets19_Oil','TopTen_StrandedAssets19','TopTen_CompanyNames','TopTenPercentStranded','TopColors');
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_PercentAssetValue_top10_Oil_global19.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_PercentAssetValue_top10_Oil_global19.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_PercentAssetValue_top10_Oil_global19.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_PercentAssetValue_top10_Oil_global19.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_PercentAssetValue_top10_Oil_global19.eps','ContentType','vector');
%                 end
% 
%                 edges = zeros(length(NextNinetyPercentStranded)+1,1);
%                 edges(2:end,1) = 1:1:length(edges)-1;
%                 vals = NextNinetyPercentStranded;
%                 center = (edges(1:end-1) + edges(2:end))/2;
%                 width = diff(edges);
% 
%                 NextColors = NextColors./255;%rescales to matlab RGB format
% 
%                 figure()
%                 hold on
%                 for i=1:length(center)
%                 barh(center(i),vals(i),'FaceColor',NextColors(i,:))
%                 end
%                 hold off
%                 cx = gca;
%                 xlim([0 1])
% %                 exportgraphics(cx,['../Plots/Figure - pie graphs/PercentAssetValue_next90_Oil_global19.eps'],'ContentType','vector');
% %                 save('../Data/Results/Next90_StrandedAssets19_Oil','NextNinety_StrandedAssets','NextNinety_CompanyNames','NextNinetyPercentStranded','NextColors');
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_PercentAssetValue_next90_Oil_global19.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_PercentAssetValue_next90_Oil_global19.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_PercentAssetValue_next90_Oil_global19.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_PercentAssetValue_next90_Oil_global19.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_PercentAssetValue_next90_Oil_global19.eps','ContentType','vector');
%                 end
% 
%                 GlobalStrandedAssetValue26 = StrandedAssetValuebyCompany(CountryINDEX,3); 
% 
%                 [TopTen_StrandedAssets26 indx] =maxk(GlobalStrandedAssetValue26,10);
%                 TopTen_CompanyNames = PowerPlantString_ByCompany(indx,1);
%                 TopTenPercentStranded = TopTen_StrandedAssets26./PresentAssetValue(indx,:);
%                 TopColors = NewColorScheme(indx,:);
% 
% 
%                  figure()
%                 pie(TopTen_StrandedAssets26,TopTen_CompanyNames)
%                 aY = gca;
% %                 exportgraphics(aY,'../Plots/Figure - pie graphs/TopTenCompanies_StrandedAssets_Oil_global26.eps','ContentType','vector');
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_TopTenCompanies_StrandedAssets_Oil_global26.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_TopTenCompanies_StrandedAssets_Oil_global26.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_TopTenCompanies_StrandedAssets_Oil_global26.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_TopTenCompanies_StrandedAssets_Oil_global26.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_TopTenCompanies_StrandedAssets_Oil_global26.eps','ContentType','vector');
%                 end
% 
% 
%                 TopStrandingsMatrix = nan(length(TopTenPercentStranded),5);
%                 TopStrandingsMatrix(:,1) = TopTenPercentStranded;
%                 TopStrandingsMatrix(:,2:4) = TopColors;
% 
% 
%                 [TopStrandingsMatrix indx] = sortrows(TopStrandingsMatrix,1);
%                 TopTenPercentStranded = TopStrandingsMatrix(:,1);
%                 TopColors = TopStrandingsMatrix(:,2:4);
% 
% 
%                 [NextNinety_StrandedAssets indx] =maxk(GlobalStrandedAssetValue26,100);%extracts the top 100 companies
%                 NextNinety_CompanyNames = PowerPlantString_ByCompany(indx,1);
%                 NextNinety_PresentValue = PresentAssetValue(indx,:);
%                 NextColors = NewColorScheme(indx,:);
% 
%                 [NextNinety_StrandedAssets indx] =mink(NextNinety_StrandedAssets,90);%subtracts the top 10
%                 NextNinety_CompanyNames = NextNinety_CompanyNames(indx,1);
%                 NextNinetyPercentStranded = NextNinety_StrandedAssets./NextNinety_PresentValue(indx,1);
%                 NextColors = NextColors(indx,:);  
% 
% 
% 
% 
%                 Next90StrandingsMatrix = nan(length(NextNinetyPercentStranded),5);
%                 Next90StrandingsMatrix(:,1) = NextNinetyPercentStranded;
%                 Next90StrandingsMatrix(:,2:4) = NextColors;
% 
% 
%                 [Next90StrandingsMatrix indx]= sortrows(Next90StrandingsMatrix,1);
%                 NextNinetyPercentStranded = Next90StrandingsMatrix(:,1);
%                 NextColors = Next90StrandingsMatrix(:,2:4);
%                 NextNinety_CompanyNames = NextNinety_CompanyNames(indx);
% 
% 
% 
%                 Next90_StrandedAssets = TopTen_StrandedAssets26;
%                 Next90_CompanyNames = TopTen_CompanyNames;
% 
%                 Next90_StrandedAssets(length(Next90_StrandedAssets)+1,1) = nansum(NextNinety_StrandedAssets);
%                 Next90_CompanyNames{length(Next90_CompanyNames)+1,1} = 'Next ninety';
% 
%                 figure()
%                 pie(Next90_StrandedAssets,Next90_CompanyNames)
%                 aY = gca;
% %                 exportgraphics(aY,'../Plots/Figure - pie graphs/NextNianetyCompanies_StrandedAssets_Oil_global26.eps','ContentType','vector');
% 
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_NextNinetyCompanies_StrandedAssets_Oil_global26.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_NextNinetyCompanies_StrandedAssets_Oil_global26.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_NextNinetyCompanies_StrandedAssets_Oil_global26.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_NextNinetyCompanies_StrandedAssets_Oil_global26.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_NextNinetyCompanies_StrandedAssets_Oil_global26.eps','ContentType','vector');
%                 end
% 
%                 edges = zeros(length(TopTenPercentStranded)+1,1);
%                 edges(2:end,1) = 1:1:length(edges)-1;
%                 vals = TopTenPercentStranded;
%                 center = (edges(1:end-1) + edges(2:end))/2;
%                 width = diff(edges);
% 
%                 TopColors = TopColors./255;%rescales to matlab RGB format
% 
%                 figure()
%                 hold on
%                 for i=1:length(center)
%                 barh(center(i),vals(i),'FaceColor',TopColors(i,:))
%                 end
%                 hold off
%                 cx = gca;
%                 xlim([0 1])
% %                 exportgraphics(cx,['../Plots/Figure - pie graphs/PercentAssetValue_top10_Oil_global26.eps'],'ContentType','vector');
% %                 save('../Data/Results/TopTen_StrandedAssets26_Oil','TopTen_StrandedAssets26','TopTen_CompanyNames','TopTenPercentStranded','TopColors');
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_PercentAssetValue_top10_Oil_global26.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_PercentAssetValue_top10_Oil_global26.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_PercentAssetValue_top10_Oil_global26.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_PercentAssetValue_top10_Oil_global26.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_PercentAssetValue_top10_Oil_global26.eps','ContentType','vector');
%                 end
% 
% 
%                 edges = zeros(length(NextNinetyPercentStranded)+1,1);
%                 edges(2:end,1) = 1:1:length(edges)-1;
%                 vals = NextNinetyPercentStranded;
%                 center = (edges(1:end-1) + edges(2:end))/2;
%                 width = diff(edges);
% 
%                 NextColors = NextColors./255;%rescales to matlab RGB format
% 
%                 figure()
%                 hold on
%                 for i=1:length(center)
%                 barh(center(i),vals(i),'FaceColor',NextColors(i,:))
%                 end
%                 hold off
%                 cx = gca;
%                 xlim([0 1])
% %                 exportgraphics(cx,['../Plots/Figure - pie graphs/PercentAssetValue_next90_Oil_global26.eps'],'ContentType','vector');
% %                 save('../Data/Results/Next90_StrandedAssets26_Oil','NextNinety_StrandedAssets','NextNinety_CompanyNames','NextNinetyPercentStranded','NextColors');
% 
%                 if I == 1
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/US_PercentAssetValue_next90_Oil_global26.eps','ContentType','vector');
%                 elseif I ~= 1 &&I ~= 3 && I~= 4 && I~=9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/ROW_PercentAssetValue_next90_Oil_global26.eps','ContentType','vector');
%                 elseif I == 3
%                    exportgraphics(aY,'../Plots/Figure - pie graphs/China_PercentAssetValue_next90_Oil_global26.eps','ContentType','vector');
%                 elseif I == 4
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/Europe_PercentAssetValue_next90_Oil_global26.eps','ContentType','vector');
%                 elseif I == 9
%                     exportgraphics(aY,'../Plots/Figure - pie graphs/India_PercentAssetValue_top10_Oil_global26.eps','ContentType','vector');
%                 end
% 
% end
% 
% 
%             end
%         elseif CombineFuelTypeResults == 1
% %              load('../Data/Results/PowerPlantFinances_byCompany_Coal')
%              load '../Data/Results/Next90_StrandedAssets19_Coal'
%              load '../Data/Results/TopTen_StrandedAssets19_Coal'
% 
%              StrandedAssets19_Coal = zeros(100,1);
%              PercentStranded19_Coal = zeros(100,1);
%              Colors19_Coal = zeros(100,3);
%              CompanyNames19_Coal = cell(100,1);
% 
%              for i = 1:100
%                  if i <=10
%                     CompanyNames19_Coal(i,1) = TopTen_CompanyNames(i,1);
%                  elseif i > 10
%                     CompanyNames19_Coal(i,1) =  NextNinety_CompanyNames(i-10,1);
%                  end
%              end
% 
%              StrandedAssets19_Coal(1:10,1) = TopTen_StrandedAssets19;
%              StrandedAssets19_Coal(11:100,1) = NextNinety_StrandedAssets;
%              PercentStranded19_Coal(1:10,1) = TopTenPercentStranded;
%              PercentStranded19_Coal(11:100,1) = NextNinetyPercentStranded;
%              Colors19_Coal(1:10,:) = TopColors;
%              Colors19_Coal(11:100,:) = NextColors;
% 
%              load '../Data/Results/TopTen_StrandedAssets26_Coal'
%              load '../Data/Results/Next90_StrandedAssets26_Coal'
%              load '../Data/Results/colorschemecategoryCoal2'
% 
%              StrandedAssets26_Coal = zeros(100,1);
%              PercentStranded26_Coal = zeros(100,1);
%              Colors26 = zeros(100,3);
%              CompanyNames26_Coal = cell(100,1);
% 
%              for i = 1:100
%                  if i <=10
%                     CompanyNames26_Coal(i,1) = TopTen_CompanyNames(i,1);
%                  elseif i > 10
%                     CompanyNames26_Coal(i,1) =  NextNinety_CompanyNames(i-10,1);
%                  end
%              end
% 
%              StrandedAssets26_Coal(1:10,1) = TopTen_StrandedAssets26;
%              StrandedAssets26_Coal(11:100,1) = NextNinety_StrandedAssets;
%              PercentStranded26_Coal(1:10,1) = TopTenPercentStranded;
%              PercentStranded26_Coal(11:100,1) = NextNinetyPercentStranded;
%              Colors26_Coal(1:10,:) = TopColors;
%              Colors26_Coal(11:100,:) = NextColors;
% 
% 
% 
%              load '../Data/Results/Next90_StrandedAssets19_Gas'
%              load '../Data/Results/TopTen_StrandedAssets19_Gas'
% 
%              StrandedAssets19_Gas = zeros(100,1);
%              PercentStranded19_Gas = zeros(100,1);
%              Colors19_Gas = zeros(100,3);
%              CompanyNames19_Gas = cell(100,1);
% 
%              for i = 1:100
%                  if i <=10
%                     CompanyNames19_Gas(i,1) = TopTen_CompanyNames(i,1);
%                  elseif i > 10
%                     CompanyNames19_Gas(i,1) =  NextNinety_CompanyNames(i-10,1);
%                  end
%              end
% 
%              StrandedAssets19_Gas(1:10,1) = TopTen_StrandedAssets19;
%              StrandedAssets19_Gas(11:100,1) = NextNinety_StrandedAssets;
%              PercentStranded19_Gas(1:10,1) = TopTenPercentStranded;
%              PercentStranded19_Gas(11:100,1) = NextNinetyPercentStranded;
%              Colors19_Gas(1:10,:) = TopColors;
%              Colors19_Gas(11:100,:) = NextColors;
% 
% 
%              load '../Data/Results/Next90_StrandedAssets26_Gas'
%              load '../Data/Results/colorschemecategoryGas2'
% 
%              StrandedAssets26_Gas = zeros(100,1);
%              PercentStranded26_Gas = zeros(100,1);
%              Colors26_Gas = zeros(100,3); 
%              CompanyNames26_Gas = cell(100,1);
% 
%              for i = 1:100
%                  if i <=10
%                     CompanyNames26_Gas(i,1) = TopTen_CompanyNames(i,1);
%                  elseif i > 10
%                     CompanyNames26_Gas(i,1) =  NextNinety_CompanyNames(i-10,1);
%                  end
%              end
% 
%              StrandedAssets26_Gas(1:10,1) = TopTen_StrandedAssets26;
%              StrandedAssets26_Gas(11:100,1) = NextNinety_StrandedAssets;
%              PercentStranded26_Gas(1:10,1) = TopTenPercentStranded;
%              PercentStranded26_Gas(11:100,1) = NextNinetyPercentStranded;
%              Colors26_Gas(1:10,:) = TopColors;
%              Colors26_Gas(11:100,:) = NextColors;
% 
%              load '../Data/Results/Next90_StrandedAssets19_Oil'
%              load '../Data/Results/TopTen_StrandedAssets19_Oil'
% 
%              StrandedAssets19_Oil = zeros(100,1);
%              PercentStranded19_Oil = zeros(100,1);
%              Colors19_Oil = zeros(100,3);
%              CompanyNames19_Oil = cell(100,1);
% 
%              for i = 1:100
%                  if i <=10
%                     CompanyNames19_Oil(i,1) = TopTen_CompanyNames(i,1);
%                  elseif i > 10
%                     CompanyNames19_Oil(i,1) =  NextNinety_CompanyNames(i-10,1);
%                  end
%              end
% 
%              StrandedAssets19_Oil(1:10,1) = TopTen_StrandedAssets19;
%              StrandedAssets19_Oil(11:100,1) = NextNinety_StrandedAssets;
%              PercentStranded19_Oil(1:10,1) = TopTenPercentStranded;
%              PercentStranded19_Oil(11:100,1) = NextNinetyPercentStranded;
%              Colors19_Oil(1:10,:) = TopColors;
%              Colors19_Oil(11:100,:) = NextColors;            
% 
%              load '../Data/Results/Next90_StrandedAssets26_Oil'
%              load '../Data/Results/colorschemecategoryOil2'
% 
%              StrandedAssets26_Oil = zeros(100,1);
%              PercentStranded26_Oil = zeros(100,1);
%              Colors26_Oil = zeros(100,3);
%              CompanyNames26_Oil = cell(100,1);
% 
%              for i = 1:100
%                  if i <=10
%                     CompanyNames26_Oil(i,1) = TopTen_CompanyNames(i,1);
%                  elseif i > 10
%                     CompanyNames26_Oil(i,1) =  NextNinety_CompanyNames(i-10,1);
%                  end
%              end
% 
%              StrandedAssets26_Oil(1:10,1) = TopTen_StrandedAssets26;
%              StrandedAssets26_Oil(11:100,1) = NextNinety_StrandedAssets;
%              PercentStranded26_Oil(1:10,1) = TopTenPercentStranded;
%              PercentStranded26_Oil(11:100,1) = NextNinetyPercentStranded;
%              Colors26_Oil(1:10,:) = TopColors;
%              Colors26_Oil(11:100,:) = NextColors;
% 
%              colorschemecategory_19 = cat(1,Colors19_Coal,Colors19_Gas,Colors19_Oil);
%              colorschemecategory_26 = cat(1,Colors26_Coal,Colors26_Gas,Colors26_Oil);
% 
%              StrandedAssets_19 = cat(1,StrandedAssets19_Coal,StrandedAssets19_Gas,StrandedAssets19_Oil);
%              StrandedAssets_26 = cat(1,StrandedAssets26_Coal,StrandedAssets26_Gas,StrandedAssets26_Oil);
% 
%              PercentStranded_19 = cat(1,PercentStranded19_Coal,PercentStranded19_Gas,PercentStranded19_Oil);
%              PercentStranded_26 = cat(1,PercentStranded26_Coal,PercentStranded26_Gas,PercentStranded26_Oil);
% 
%              CompanyNames19 = cat(1,CompanyNames19_Coal,CompanyNames19_Gas,CompanyNames19_Oil);
%              CompanyNames26 = cat(1,CompanyNames26_Coal,CompanyNames26_Gas,CompanyNames26_Oil);
% 
%              UniqueNames19 = unique(CompanyNames19);
%              UniqueNames26 = unique(CompanyNames26);            
% 
% 
%              NewColorScheme19 = zeros(length(colorschemecategory_19),1);
% 
%             for i  = 1:length(colorschemecategory_19)%programed from illustrator RGB colors
%                 if colorschemecategory_19(i,1) == 245/255 && ...
%                         colorschemecategory_19(i,2) == 157/255 &&...
%                         colorschemecategory_19(i,3) == 51/255
% 
%                     NewColorScheme19(i) = 1;%United States [245,157,51];%orange
% 
%                 elseif colorschemecategory_19(i,1) == 148/255 && ...
%                         colorschemecategory_19(i,2) == 89/255 &&...
%                         colorschemecategory_19(i,3) == 161/255
% 
%                         NewColorScheme19(i) = 6;%Asia [148,89,161];%purple
% 
%                elseif colorschemecategory_19(i,1) == 238/255 && ...
%                         colorschemecategory_19(i,2) == 53/255 &&...
%                         colorschemecategory_19(i,3) == 48/255
% 
%                         NewColorScheme19(i) = 3;%China [238,53,48];%red
% 
%                 elseif colorschemecategory_19(i,1) == 107/255 && ...
%                         colorschemecategory_19(i,2) == 139/255 &&...
%                         colorschemecategory_19(i,3) == 193/255
% 
%                         NewColorScheme19(i) = 4;%Europe [107,139,193];
% 
%                 elseif colorschemecategory_19(i,1) == 47/255 && ...
%                         colorschemecategory_19(i,2) == 57/255 &&...
%                         colorschemecategory_19(i,3) == 131/255
% 
%                         NewColorScheme19(i) = 2;%LAM [47,57,131];%light blue    
% 
%                 elseif colorschemecategory_19(i,1) == 240/255 && ...
%                         colorschemecategory_19(i,2) == 233/255 &&...
%                         colorschemecategory_19(i,3) == 94/255
% 
%                         NewColorScheme19(i) = 9;%India [240,233,94];%yellow
% 
%                 elseif colorschemecategory_19(i,1) == 119/255 && ...
%                         colorschemecategory_19(i,2) == 192/255 &&...
%                         colorschemecategory_19(i,3) == 70/255
% 
%                         NewColorScheme19(i) = 5;%MAF [119,192,70];%green
% 
%                 elseif colorschemecategory_19(i,1) == 194/255 && ...
%                         colorschemecategory_19(i,2) == 31/255 &&...
%                         colorschemecategory_19(i,3) == 79/255
% 
%                         NewColorScheme19(i) = 8;%ROW [194,31,79];%light purple      
% 
%                elseif colorschemecategory_19(i,1) == 74/255 && ...
%                         colorschemecategory_19(i,2) == 186/255 &&...
%                         colorschemecategory_19(i,3) == 183/255
% 
%                         NewColorScheme19(i) = 7;%REF [74,186,183];%aqua
%                 end
%             end
% 
% 
%              NewColorScheme26 = zeros(length(colorschemecategory_26),1);
% 
% 
%             for i  = 1:length(colorschemecategory_26)%programed from illustrator RGB colors
%                 if colorschemecategory_26(i,1) == 245/255 && ...
%                         colorschemecategory_26(i,2) == 157/255 &&...
%                         colorschemecategory_26(i,3) == 51/255
% 
%                     NewColorScheme26(i) = 1;%United States [245,157,51];%orange
% 
%                 elseif colorschemecategory_26(i,1) == 148/255 && ...
%                         colorschemecategory_26(i,2) == 89/255 &&...
%                         colorschemecategory_26(i,3) == 161/255
% 
%                         NewColorScheme26(i) = 6;%Asia [148,89,161];%purple
% 
%                elseif colorschemecategory_26(i,1) == 238/255 && ...
%                         colorschemecategory_26(i,2) == 53/255 &&...
%                         colorschemecategory_26(i,3) == 48/255
% 
%                         NewColorScheme26(i) = 3;%China [238,53,48];%red
% 
%                 elseif colorschemecategory_26(i,1) == 107/255 && ...
%                         colorschemecategory_26(i,2) == 139/255 &&...
%                         colorschemecategory_26(i,3) == 193/255
% 
%                         NewColorScheme26(i) = 4;%Europe [107,139,193];
% 
%                 elseif colorschemecategory_26(i,1) == 47/255 && ...
%                         colorschemecategory_26(i,2) == 57/255 &&...
%                         colorschemecategory_26(i,3) == 131/255
% 
%                         NewColorScheme26(i) = 2;%LAM [47,57,131];%light blue    
% 
%                 elseif colorschemecategory_26(i,1) == 240/255 && ...
%                         colorschemecategory_26(i,2) == 233/255 &&...
%                         colorschemecategory_26(i,3) == 94/255
% 
%                         NewColorScheme26(i) = 9;%India [240,233,94];%yellow
% 
%                 elseif colorschemecategory_26(i,1) == 119/255 && ...
%                         colorschemecategory_26(i,2) == 192/255 &&...
%                         colorschemecategory_26(i,3) == 70/255
% 
%                         NewColorScheme26(i) = 5;%MAF [119,192,70];%green
% 
%                 elseif colorschemecategory_26(i,1) == 194/255 && ...
%                         colorschemecategory_26(i,2) == 31/255 &&...
%                         colorschemecategory_26(i,3) == 79/255
% 
%                         NewColorScheme26(i) = 8;%ROW [194,31,79];%light purple      
% 
%                elseif colorschemecategory_26(i,1) == 74/255 && ...
%                         colorschemecategory_26(i,2) == 186/255 &&...
%                         colorschemecategory_26(i,3) == 183/255
% 
%                         NewColorScheme26(i) = 7;%REF [74,186,183];%aqua
%                 end
%             end
% 
%             colorschemecategory19 = zeros(length(UniqueNames19),300);
%              StrandedAssets19 = zeros(length(UniqueNames19),1);
%              PercentStranded19 = zeros(length(UniqueNames19),300); 
% 
%               for generator = 1:length(CompanyNames19)
%                  for Company = 1:length(UniqueNames19)
%                      if strcmpi(CompanyNames19{generator,1},UniqueNames19{Company,1})
%                          colorschemecategory19(Company) =  NewColorScheme19(generator);
%                          StrandedAssets19(Company) = StrandedAssets19(Company) + StrandedAssets_19(generator);
%                          PercentStranded19(Company,generator) =  PercentStranded_19(generator);
%                      end
%                  end
%               end
% 
%               PercentStranded19(PercentStranded19==0) = nan;
%               PercentStranded19 = nanmean(PercentStranded19,2);
% 
% %               colorschemecategory19(colorschemecategory19 == 0) = nan;
%               AverageColors = zeros(length(colorschemecategory19),1);
% 
%               for i = 1:length(UniqueNames19)
%                   ColorVector = colorschemecategory19(i,:);
%                   ColorVector(ColorVector == 0) = [];
%                   AverageColors(i) = mode(ColorVector);
%               end
% 
%               colorschemecategory19 = AverageColors;
% %               colorschemecategory19 = nanmean(colorschemecategory19,2);
% %               colorschemecategory19 = round(colorschemecategory19);
% 
%              colorschemecategory26 = zeros(length(UniqueNames26),300);
%              StrandedAssets26 = zeros(length(UniqueNames26),1);
%              PercentStranded26 = zeros(length(UniqueNames26),300);
% 
%               for generator = 1:length(CompanyNames26)
%                  for Company = 1:length(UniqueNames26)
%                      if strcmpi(CompanyNames26{generator,1},UniqueNames26{Company,1})
%                          colorschemecategory26(Company,generator) = NewColorScheme26(generator);
%                          StrandedAssets26(Company) = StrandedAssets26(Company) + StrandedAssets_26(generator);
%                          PercentStranded26(Company,generator) = PercentStranded_26(generator);
%                      end
%                  end
%               end
%             aaa = colorschemecategory26;
%               PercentStranded26(PercentStranded26==0) = nan;
%               PercentStranded26 = nanmean(PercentStranded26,2);
% 
% %               colorschemecategory26(colorschemecategory26 == 0) = nan;
%               AverageColors = zeros(length(colorschemecategory26),1);
% 
%               for i = 1:length(UniqueNames26)
%                   ColorVector = colorschemecategory26(i,:);
%                   ColorVector(ColorVector == 0) = [];
%                   AverageColors(i) = mode(ColorVector);
%               end
% 
%               colorschemecategory26 = AverageColors;
% 
% 
%             NewColorScheme19 = zeros(length(colorschemecategory19),3);
% 
%                 for i  = 1:length(colorschemecategory19)%programed from illustrator RGB colors
%                     if colorschemecategory19(i) == 1%United States
%                         NewColorScheme19(i,:) = [245,157,51];%orange
%                     elseif colorschemecategory19(i) == 6%Asia
%                         NewColorScheme19(i,:) = [148,89,161];%purple
%                     elseif colorschemecategory19(i) == 3%China
%                         NewColorScheme19(i,:) = [238,53,48];%red
%                     elseif colorschemecategory19(i) == 5%MAF  
%                         NewColorScheme19(i,:) = [119,192,70];%green
%                     elseif colorschemecategory19(i) == 2%LAM 
%                         NewColorScheme19(i,:) = [47,57,131];%light blue
%                     elseif colorschemecategory19(i) == 9%India
%                         NewColorScheme19(i,:) = [240,233,94];%yellow
%                     elseif colorschemecategory19(i) == 4%Europe
%                         NewColorScheme19(i,:) = [107,139,193];
%                     elseif colorschemecategory19(i) == 8%Row
%                         NewColorScheme19(i,:) = [194,31,79];%light purple
%                    elseif colorschemecategory19(i) == 7%REF
%                         NewColorScheme19(i,:) = [74,186,183];%aqua
%                     end
%                end 
% 
% 
%             NewColorScheme26 = zeros(length(colorschemecategory26),3);
% 
%             for i  = 1:length(colorschemecategory26)%programed from illustrator RGB colors
%                     if colorschemecategory26(i) == 1%United States
%                         NewColorScheme26(i,:) = [245,157,51];%orange
%                     elseif colorschemecategory26(i) == 6%Asia
%                         NewColorScheme26(i,:) = [148,89,161];%purple
%                     elseif colorschemecategory26(i) == 3%China
%                         NewColorScheme26(i,:) = [238,53,48];%red
%                     elseif colorschemecategory26(i) == 5%MAF  
%                         NewColorScheme26(i,:) = [119,192,70];%green
%                     elseif colorschemecategory26(i) == 2%LAM 
%                         NewColorScheme26(i,:) = [47,57,131];%light blue
%                     elseif colorschemecategory26(i) == 9%India
%                         NewColorScheme26(i,:) = [240,233,94];%yellow
%                     elseif colorschemecategory26(i) == 4%Europe
%                         NewColorScheme26(i,:) = [107,139,193];
%                     elseif colorschemecategory26(i) == 8%Row
%                         NewColorScheme26(i,:) = [194,31,79];%light purple
%                    elseif colorschemecategory26(i) == 7%REF
%                         NewColorScheme26(i,:) = [74,186,183];%aqua
%                     end
%                end 
% 
% 
% 
%                 [TopTen_StrandedAssets19, indx] =maxk(StrandedAssets19,10);
%                 TopTen_CompanyNames = UniqueNames19(indx,1);
%                 TopColors = NewColorScheme19(indx,:);
%                 TopTenPercentStranded = PercentStranded19(indx,1);
% 
% 
%                 TopStrandingsMatrix = nan(length(TopTenPercentStranded),5);
%                 TopStrandingsMatrix(:,1) = TopTenPercentStranded;
%                 TopStrandingsMatrix(:,2:4) = TopColors;
%                 TopStrandingsMatrix(:,5) = 1:10;
% 
%                 [TopStrandingsMatrix, indx] = sortrows(TopStrandingsMatrix,1);
%                 TopTenPercentStranded = TopStrandingsMatrix(:,1);
%                 TopColors = TopStrandingsMatrix(:,2:4);
%                 TopTen_CompanyNames = TopTen_CompanyNames(TopStrandingsMatrix(:,5));
% 
% 
% 
%                 [NextNinety_StrandedAssets, indx] =maxk(StrandedAssets19,100);%extracts the top 100 companies
%                 NextNinety_CompanyNames = UniqueNames19(indx,1);
%                 NextNinety_PresentValue = PercentStranded19(indx,1);
%                 NextColors = NewColorScheme19(indx,:);
% 
%                 [NextNinety_StrandedAssets, indx] =mink(NextNinety_StrandedAssets,90);%subtracts the top 10
%                 NextNinety_CompanyNames = NextNinety_CompanyNames(indx,1);
%                 NextNinetyPercentStranded = NextNinety_PresentValue(indx,1);
%                 NextColors = NextColors(indx,:);
% 
%                 Next90StrandingsMatrix = nan(length(NextNinetyPercentStranded),5);
%                 Next90StrandingsMatrix(:,1) = NextNinetyPercentStranded;
%                 Next90StrandingsMatrix(:,2:4) = NextColors;
%                 Next90StrandingsMatrix(:,5) = 1:90;
% 
%                 [Next90StrandingsMatrix, indx]= sortrows(Next90StrandingsMatrix,1);
%                 NextNinetyPercentStranded = Next90StrandingsMatrix(:,1);
%                 NextColors = Next90StrandingsMatrix(:,2:4);
%                 NextNinety_CompanyNames = NextNinety_CompanyNames(Next90StrandingsMatrix(:,5));
% 
% 
%                 figure()
%                 pie(TopTen_StrandedAssets19,TopTen_CompanyNames)
%                 aY = gca;
%                 exportgraphics(aY,'../Plots/Figure - pie graphs/TopTenCompanies_StrandedAssets_all_global19.eps','ContentType','vector');
% 
%                 Next90_StrandedAssets = TopTen_StrandedAssets19;
%                 Next90_CompanyNames = TopTen_CompanyNames;
% 
%                 Next90_StrandedAssets(length(Next90_StrandedAssets)+1,1) = nansum(NextNinety_StrandedAssets);
%                 Next90_CompanyNames{length(Next90_CompanyNames)+1,1} = 'Next ninety';
% 
%                 figure()
%                 pie(Next90_StrandedAssets,Next90_CompanyNames)
%                 aY = gca;
%                 exportgraphics(aY,'../Plots/Figure - pie graphs/NextNinetyCompanies_StrandedAssets_all_global19.eps','ContentType','vector');
% 
%                 edges = zeros(length(TopTenPercentStranded)+1,1);
%                 edges(2:end,1) = 1:1:length(edges)-1;
%                 vals = TopTenPercentStranded;
%                 center = (edges(1:end-1) + edges(2:end))/2;
%                 width = diff(edges);
% 
%                 TopColors = TopColors./255;%rescales to matlab RGB format
% 
%                 figure()
%                 hold on
%                 for i=1:length(center)
%                 barh(center(i),vals(i),'FaceColor',TopColors(i,:))
%                 end
%                 hold off
%                 cx = gca;
%                 xlim([0 1])
%                 exportgraphics(cx,['../Plots/Figure - pie graphs/PercentAssetValue_top10_all_global19.eps'],'ContentType','vector');
% 
% 
%                 edges = zeros(length(NextNinetyPercentStranded)+1,1);
%                 edges(2:end,1) = 1:1:length(edges)-1;
%                 vals = NextNinetyPercentStranded;
%                 center = (edges(1:end-1) + edges(2:end))/2;
%                 width = diff(edges);
% 
%                 NextColors = NextColors./255;%rescales to matlab RGB format
% 
%                 figure()
%                 hold on
%                 for i=1:length(center)
%                 barh(center(i),vals(i),'FaceColor',NextColors(i,:))
%                 end
%                 hold off
%                 cx = gca;
%                 xlim([0 1])
%                 exportgraphics(cx,['../Plots/Figure - pie graphs/PercentAssetValue_next90_all_global19.eps'],'ContentType','vector');
% 
% 
% 
%                 [TopTen_StrandedAssets26 indx] =maxk(StrandedAssets26,10);
%                 TopTen_CompanyNames = UniqueNames26(indx,1);
%                 TopColors = NewColorScheme26(indx,:);
%                 TopTenPercentStranded = PercentStranded26(indx,1);
% 
% 
%                 TopStrandingsMatrix = nan(length(TopTenPercentStranded),5);
%                 TopStrandingsMatrix(:,1) = TopTenPercentStranded;
%                 TopStrandingsMatrix(:,2:4) = TopColors;
% 
% 
%                 [TopStrandingsMatrix indx] = sortrows(TopStrandingsMatrix,1);
%                 TopTenPercentStranded = TopStrandingsMatrix(:,1);
%                 TopColors = TopStrandingsMatrix(:,2:4);
% 
% 
%                 [NextNinety_StrandedAssets indx] =maxk(StrandedAssets26,100);%extracts the top 100 companies
%                 NextNinety_CompanyNames = UniqueNames26(indx,1);
%                 NextNinety_PresentValue = PercentStranded26(indx,1);
%                 NextColors = NewColorScheme26(indx,:);
% 
%                 [NextNinety_StrandedAssets indx] =mink(NextNinety_StrandedAssets,90);%subtracts the top 10
%                 NextNinety_CompanyNames = NextNinety_CompanyNames(indx,1);
%                 NextNinetyPercentStranded = NextNinety_PresentValue(indx,1);
%                 NextColors = NextColors(indx,:);
% 
%                 Next90StrandingsMatrix = nan(length(NextNinetyPercentStranded),5);
%                 Next90StrandingsMatrix(:,1) = NextNinetyPercentStranded;
%                 Next90StrandingsMatrix(:,2:4) = NextColors;
% 
% 
%                 [Next90StrandingsMatrix indx]= sortrows(Next90StrandingsMatrix,1);
%                 NextNinetyPercentStranded = Next90StrandingsMatrix(:,1);
%                 NextColors = Next90StrandingsMatrix(:,2:4);
%                 NextNinety_CompanyNames = NextNinety_CompanyNames(indx);
% 
% 
%                 figure()
%                 pie(TopTen_StrandedAssets26,TopTen_CompanyNames)
%                 aY = gca;
%                 exportgraphics(aY,'../Plots/Figure - pie graphs/TopTenCompanies_StrandedAssets_all_global26.eps','ContentType','vector');
% 
%                 Next90_StrandedAssets = TopTen_StrandedAssets26;
%                 Next90_CompanyNames = TopTen_CompanyNames;
% 
%                 Next90_StrandedAssets(length(Next90_StrandedAssets)+1,1) = nansum(NextNinety_StrandedAssets);
%                 Next90_CompanyNames{length(Next90_CompanyNames)+1,1} = 'Next ninety';
% 
%                 figure()
%                 pie(Next90_StrandedAssets,Next90_CompanyNames)
%                 aY = gca;
%                 exportgraphics(aY,'../Plots/Figure - pie graphs/NextNinetyCompanies_StrandedAssets_all_global26.eps','ContentType','vector');
% 
%                 edges = zeros(length(TopTenPercentStranded)+1,1);
%                 edges(2:end,1) = 1:1:length(edges)-1;
%                 vals = TopTenPercentStranded;
%                 center = (edges(1:end-1) + edges(2:end))/2;
%                 width = diff(edges);
% 
%                 TopColors = TopColors./255;%rescales to matlab RGB format
% 
%                 figure()
%                 hold on
%                 for i=1:length(center)
%                 barh(center(i),vals(i),'FaceColor',TopColors(i,:))
%                 end
%                 hold off
%                 cx = gca;
%                 xlim([0 1])
%                 exportgraphics(cx,['../Plots/Figure - pie graphs/PercentAssetValue_top10_all_global26.eps'],'ContentType','vector');
% 
% 
%                 edges = zeros(length(NextNinetyPercentStranded)+1,1);
%                 edges(2:end,1) = 1:1:length(edges)-1;
%                 vals = NextNinetyPercentStranded;
%                 center = (edges(1:end-1) + edges(2:end))/2;
%                 width = diff(edges);
% 
%                 NextColors = NextColors./255;%rescales to matlab RGB format
% 
%                 figure()
%                 hold on
%                 for i=1:length(center)
%                 barh(center(i),vals(i),'FaceColor',NextColors(i,:))
%                 end
%                 hold off
%                 cx = gca;
%                 xlim([0 1])
%                 exportgraphics(cx,['../Plots/Figure - pie graphs/PercentAssetValue_next90_all_global26.eps'],'ContentType','vector');
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
%         end
    end
    
elseif section == 6%HHI calculations
    load '../Data/Results/CompanyAssetsUnique_regional19'
    Regional_stranded_assets_19 = sum(CompanyAssetsUnique_regional19,2,'omitnan');
    Market_share = (Regional_stranded_assets_19./sum(Regional_stranded_assets_19));
    HHI = sum(Market_share.^2,'omitnan'); 
    NextNinety_Assets = maxk(Regional_stranded_assets_19,100);%extracts the top 100 companies
    NextNinety_Assets = mink(NextNinety_Assets,90);%subtracts the top 10
    TopTen_Assets = maxk(Regional_stranded_assets_19,10);

    load '../Data/Results/PowerPlantFinances_byCompany_Coal'
    Regional_annual_stranded_assets_coal_19 = AnnualStrandedAssets(:,:,2);
    Market_share_coal = (StrandedAssetValuebyCompany(:,2)./sum(StrandedAssetValuebyCompany(:,2),'omitnan'));
    HHI_coal = sum(Market_share_coal.^2, 'omitnan');

    load '../Data/Results/PowerPlantFinances_byCompany_Gas'
    Market_share_gas = (StrandedAssetValuebyCompany(:,2)./sum(StrandedAssetValuebyCompany(:,2),'omitnan'));
    HHI_gas = sum(Market_share_gas.^2, 'omitnan');

    
elseif section == 7
    for gentype = FUEL
%         if CombineFuelTypeResults ~= 1
            latlim = [-60 65];
            lonlim = [-150 180];
            
            if FUEL == 1
             load '../Data/Results/PowerPlantFinances_byCountry_Coal'
            elseif FUEL == 2
             load '../Data/Results/PowerPlantFinances_byCountry_Gas' 
            elseif FUEL == 3
             load '../Data/Results/PowerPlantFinances_byCountry_Oil' 
            elseif FUEL == 4
                load '../Data/Results/PowerPlantFinances_byCountry_Coal'
                PowerPlantFinances_byCountryCoal = squeeze(nansum(PowerPlantStrandedAssets_byCountry,2));
                PowerPlantString_ByCountryCoal = PowerPlantString_ByCountry;
                
                load '../Data/Results/PowerPlantFinances_byCountry_Gas' 
                PowerPlantFinances_byCountryGas = squeeze(nansum(PowerPlantStrandedAssets_byCountry,2));
                PowerPlantString_ByCountryGas = PowerPlantString_ByCountry;
                
                load '../Data/Results/PowerPlantFinances_byCountry_Oil' 
                PowerPlantFinances_byCountryOil = squeeze(nansum(PowerPlantStrandedAssets_byCountry,2));
                PowerPlantString_ByCountryOil = PowerPlantString_ByCountry;
                
                
                  CountryStrings = [PowerPlantString_ByCountryCoal;PowerPlantString_ByCountryGas];
                  CountryStrings = unique(CountryStrings);
                  
                  CountryStrandedAssets = zeros(length(CountryStrings),4);

                   for country = 1:length(CountryStrings)
                       for countrycompare = 1:length(PowerPlantString_ByCountryCoal)
                           if strcmpi(CountryStrings{country,1},PowerPlantString_ByCountryCoal{countrycompare,1})
                              CountryStrandedAssets(country,:,:) = CountryStrandedAssets(country,:) + PowerPlantFinances_byCountryCoal(countrycompare,:,:);
                           end
                       end
                   end
                
                
                   for country = 1:length(CountryStrings)
                      for countrycompare = 1:length(PowerPlantString_ByCountryGas)
                          if strcmpi(CountryStrings{country,1},PowerPlantString_ByCountryGas{countrycompare,1})
                           CountryStrandedAssets(country,:,:) = CountryStrandedAssets(country,:) + PowerPlantFinances_byCountryGas(countrycompare,:,:);
                          end
                      end
                   end
                   
                   for country = 1:length(CountryStrings)
                      for countrycompare = 1:length(PowerPlantString_ByCountryOil)
                          if strcmpi(CountryStrings{country,1},PowerPlantString_ByCountryOil{countrycompare,1})
                           CountryStrandedAssets(country,:,:) = CountryStrandedAssets(country,:) + PowerPlantFinances_byCountryOil(countrycompare,:,:);
                          end
                      end
                   end
                   
                   PowerPlantString_ByCountry = CountryStrings;
                   StrandedAssetsbyCountry = CountryStrandedAssets;
            end
            
            
            CounBorder = struct2cell(shaperead('../Data/Shapefile/UIA_World_Countries_Boundaries-shp/World_Countries__Generalized_.shp', 'UseGeoCoords',true))';
            CountryBorder = shaperead('../Data/Shapefile/UIA_World_Countries_Boundaries-shp/World_Countries__Generalized_.shp', 'UseGeoCoords',true)';
            load '../Data/Results/coordinates.mat'
            population = readtable('../Data/population.csv');
            
            pop_strings = table2array(population(:,1));
            population = table2array(population(:,2));
            
            
            for i = 361:length(lon)
                lon(i) = lon(i) + 360;
            end

            Lat = lat; Lon = lon;  
            [LAT, LON] = meshgrid(lat,lon);
            
            
            AssetValuebyCountry = zeros(720,360,4);
            populationbyCountry = zeros(720,360);
            
            CountryNamesShapeFile = cell(length(CountryBorder),1);
            for i = 1:length(CountryBorder)
                CountryNamesShapeFile{i,1} = upper(CounBorder{i,6});
            end
            
            for country = 1:length(PowerPlantString_ByCountry)
                if strcmpi(PowerPlantString_ByCountry{country,1},'ENGLAND & WALES')
                    PowerPlantString_ByCountry{country,1} = 'UNITED KINGDOM';
                elseif strcmpi(PowerPlantString_ByCountry{country,1},'United States')
                    PowerPlantString_ByCountry{country,1} = 'UNITED STATES';
                elseif strcmpi(PowerPlantString_ByCountry{country,1},'RUSSIA')
                    PowerPlantString_ByCountry{country,1} = 'RUSSIAN FEDERATION'; 
                elseif strcmpi(PowerPlantString_ByCountry{country,1},'BOSNIA-HERZEGOVINA')
                    PowerPlantString_ByCountry{country,1} = 'BOSNIA AND HERZEGOVINA';
                end
            end
            
            for country = 1:length(PowerPlantString_ByCountry)
                for countrycompare = 1:length(CountryBorder)
                    for i = 1:4
                        if strcmpi(PowerPlantString_ByCountry{country,1},CountryNamesShapeFile{countrycompare,1})
                             CountryShape = inpolygon(LAT,LON,CountryBorder(countrycompare).Lat,CountryBorder(countrycompare).Lon);

                             AssetValuebyCountry(:,:,i) = AssetValuebyCountry(:,:,i) + StrandedAssetsbyCountry(country).*CountryShape;
                        end
                    end
                end
            end
            
            
         for country = 1:length(pop_strings)
            for countrycompare = 1:length(CountryBorder)
                if strcmpi(pop_strings{country,1},CountryNamesShapeFile{countrycompare,1})
                     CountryShape = inpolygon(LAT,LON,CountryBorder(countrycompare).Lat,CountryBorder(countrycompare).Lon);
                     populationbyCountry = populationbyCountry + population(country).*CountryShape;
                end
            end
         end
         
         
   
          for i = 1:4  
            AssetVal = AssetValuebyCountry(:,:,i);
            AssetVal(AssetVal<=0) = nan;
%             AssetValuebyCountry = AssetValuebyCountry.*-1;
            Autumnworldmap(AssetVal,latlim,lonlim, '','RdBu');
            caxis([-10e10 0])
             ax = gca;
                
            if i == 1
                exportgraphics(ax,['../Plots/Figure X [Stranded asset maps]/Global carbon prices Stranded Assets rcp 19.eps'],'ContentType','vector');    
            elseif i == 2
                exportgraphics(ax,['../Plots/Figure X [Stranded asset maps]/regional carbon prices Stranded Assets rcp 19.eps'],'ContentType','vector');
            elseif i == 3
                exportgraphics(ax,['../Plots/Figure X [Stranded asset maps]/Global carbon prices Stranded Assets rcp 26.eps'],'ContentType','vector'); 
            elseif i == 4
                exportgraphics(ax,['../Plots/Figure X [Stranded asset maps]/regional carbon prices Stranded Assets rcp 26.eps'],'ContentType','vector');
            end
            
%             Hotworldmap(AssetValuebyCountry,latlim,lonlim, '','RdBu');
%             caxis([nanmin(nanmin(AssetValuebyCountry)) -1.5e10])
            
            StrandedAsset_perCapita = AssetVal./populationbyCountry;
            Autumnworldmap(StrandedAsset_perCapita,latlim,lonlim, '','RdBu');
            caxis([0 50])
            ax = gca;
            if i == 1
                exportgraphics(ax,['../Plots/Figure X [Stranded asset maps]/Global carbon prices Stranded Assets per capita 19.eps'],'ContentType','vector');    
            elseif i == 2
                exportgraphics(ax,['../Plots/Figure X [Stranded asset maps]/regional carbon prices Stranded Assets per capita 19.eps'],'ContentType','vector');
            elseif i == 3
                exportgraphics(ax,['../Plots/Figure X [Stranded asset maps]/Global carbon prices Stranded Assets per capita 26.eps'],'ContentType','vector');    
            elseif i == 4
                exportgraphics(ax,['../Plots/Figure X [Stranded asset maps]/regional carbon prices Stranded Assets per capita 26.eps'],'ContentType','vector');
            end
            
            

          end
    end

elseif section == 8
        FuelComposition = readcell('../Data/CompanyFuelComposition.xlsx');
        Composition = xlsread('../Data/CompanyFuelComposition.xlsx');
    
        Companies  = FuelComposition(2:end,1);
    
        for i = 1:length(Companies) 
            Name = Companies{(i)};
    
            CompanyName = string(Companies(i,1));
            Capacity = Composition(i,:);
    
            figure()
            pie(Capacity)
            legend('Coal','Gas','Oil')
            ax = gca;
            exportgraphics(ax,['../Plots/' Name 'Fuel composition pie.eps'],'ContentType','vector');
        end

elseif section == 9
    load(['../Data/Results/DecommissionYear' PowerPlantFuel{FUEL} ''])
    if FUEL == 1
        load '../Data/Results/PowerPlantFinances_byCompany_Coal'
        load '../Data/Results/PowerPlantFinances_byCountry_Coal'
        load '../Data/Results/CoalAnnualEmissions.mat'
        load ../Data/Results/CoalCompanyCapacity.mat
        load ../Data/Results/CoalRevenue.mat 
        load ../Data/Results/CoalStrandedAssets.mat
        load '../Data/Results/colorschemecategoryCoal2'

        RegionList = {'United States','Latin America','China','Europe',...
            'Middle East and Africa','Asia','Former Soviet','Australia, Canada, New Zealand','India'};
        
        RGB_colors = [1 0 0; 0 1 0; 0 0 1; 0 1 1; 1 0 1; 1 1 0; 0 0 0; 0 0.4470 0.7410; 0.8500 0.3250 0.0980];
        Coal_company_country_strings = strings(length(CoalAnnualEmissions_Company),1);
        Company_RGB_colors = zeros(length(CoalAnnualEmissions_Company),3);

        for i = 1:length(CoalAnnualEmissions_Company)
            for j = 1:length(RegionList)
                if colorschemecategory(i) == j
                    Coal_company_country_strings(i) = RegionList(j);
                    Company_RGB_colors(i,:) = RGB_colors(j,:);
                end
            end
        end

        mean_Life = mean_Life_coal;


        Unknown_companies = {'other', 'others', 'other states','other unknownmixed entity types'};
        Unknown_companies_index = find(ismember(PowerPlantString_ByCompany, Unknown_companies));
        Unknown_companies_emissions = CoalAnnualEmissions_Company(Unknown_companies_index);
        Unknown_companies_capacity = TotalPowerPlantCapacitybyCompany(Unknown_companies_index,:);
        Unknown_companies_stranded_assets = StrandedAssetValuebyCompany(Unknown_companies_index,:);

        StrandedAssetValuebyCompany(Unknown_companies_index,:) = 0;%removes unknown companies after extracting them above
        TotalPowerPlantCapacitybyCompany(Unknown_companies_index,:) = 0;
        CoalAnnualEmissions_Company(Unknown_companies_index) = 0;

        ProfitsByCompany_CarbonTax = squeeze(sum(PowerPlantFinances_byCompany(:,1:40,2),2));%company,year,variable
        % StrandedAssetsbyCompany = squeeze(sum(StrandedAssetValuebyCompany(:,1:40),2));
        StrandedAssetsbyCompany = StrandedAssetValuebyCompany(:,2);
        EmissionsbyCompany = squeeze(CoalAnnualEmissions_Company(:,1));
        AnnualCapacityByCompany = squeeze(TotalPowerPlantCapacitybyCompany(:,1));
        NumberofPlantsperCompanyperYear = squeeze(NumberofPlantsperCompanyperYear(:,1));
        Lifeleft = mean_Life - PowerPlantLife_byCompany(:,1);

        AnnualEmissionsByCompany_Coal_strings(EmissionsbyCompany==0)=[];
        CommittedEmissions(EmissionsbyCompany==0)=[];
        StrandedAssetsbyCompany(EmissionsbyCompany == 0)=[];
        ProfitsByCompany_CarbonTax(EmissionsbyCompany ==0)=[];
        RevenuebyCompany(EmissionsbyCompany == 0)= [];
        colorschemecategory(EmissionsbyCompany==0)=[];
        AnnualCapacityByCompany(EmissionsbyCompany==0)=[];
        NumberofPlantsperCompanyperYear(EmissionsbyCompany==0)=[];
        Coal_company_country_strings(EmissionsbyCompany==0)=[];
        Company_RGB_colors(EmissionsbyCompany==0,:)=[];
        Lifeleft(EmissionsbyCompany==0)=[];
        EmissionsbyCompany(EmissionsbyCompany ==0)=[];

        CommittedEmissions(ProfitsByCompany_CarbonTax==0)=[];
        AnnualEmissionsByCompany_Coal_strings(ProfitsByCompany_CarbonTax==0)=[];
        StrandedAssetsbyCompany(ProfitsByCompany_CarbonTax==0)=[];
        RevenuebyCompany(ProfitsByCompany_CarbonTax == 0) = [];
        EmissionsbyCompany(ProfitsByCompany_CarbonTax==0)=[];
        colorschemecategory(ProfitsByCompany_CarbonTax==0)=[];
        Coal_company_country_strings(ProfitsByCompany_CarbonTax==0)=[];
        AnnualCapacityByCompany(ProfitsByCompany_CarbonTax==0)=[];
        NumberofPlantsperCompanyperYear(ProfitsByCompany_CarbonTax==0)=[];
        Company_RGB_colors(ProfitsByCompany_CarbonTax==0,:)=[];
        Lifeleft(ProfitsByCompany_CarbonTax==0)=[];
        ProfitsByCompany_CarbonTax(ProfitsByCompany_CarbonTax==0)=[];


        [StrandedAssetsbyCompany,Indx] = maxk(StrandedAssetsbyCompany,100);
        AnnualEmissionsByCompany_Coal_strings = AnnualEmissionsByCompany_Coal_strings(Indx);
        RevenuebyCompany = RevenuebyCompany(Indx);
        ProfitsByCompany_CarbonTax = ProfitsByCompany_CarbonTax(Indx);
        colorschemecategory = colorschemecategory(Indx);
        AnnualCapacityByCompany = AnnualCapacityByCompany(Indx);
        NumberofPlantsperCompanyperYear = NumberofPlantsperCompanyperYear(Indx);
        EmissionsbyCompany = EmissionsbyCompany(Indx);
        CommittedEmissions = CommittedEmissions(Indx);
        Coal_company_country_strings = Coal_company_country_strings(Indx);
        Company_RGB_colors = Company_RGB_colors(Indx,:);
        Lifeleft = Lifeleft(Indx,:);

        EmissionsbyCompany = EmissionsbyCompany/(1e6); %converts to Mt CO2
        StrandedAssetsbyCompany = StrandedAssetsbyCompany/(1e9); %converts to billions of $
        RevenuebyCompany = RevenuebyCompany/(1e9); %converts to billions of $
        

        % OilRevenue = cell2mat(struct2cell(load('revenuebycompany_oil.mat')));
        % GasRevenue = cell2mat(struct2cell(load('revenuebycompany_gas.mat')));
        % CoalRevenue = cell2mat(struct2cell(load('revenuebycompany_coal.mat')));
        % Revenue = [OilRevenue CoalRevenue GasRevenue];
        save('revenuebycompany_coal.mat','RevenuebyCompany')

        stranded_marker_size = (StrandedAssetsbyCompany-min(StrandedAssetsbyCompany))/(max(StrandedAssetsbyCompany)-min(StrandedAssetsbyCompany));%normalized data between 0 and 1 for plotting
        stranded_scaled_size = min_marker_size + (max_marker_size - min_marker_size) * stranded_marker_size;

        Emission_marker_sizes = (EmissionsbyCompany-min(EmissionsbyCompany))/(max(EmissionsbyCompany)-min(EmissionsbyCompany));%normalized data between 0 and 1 for plotting
        Emission_scaled_sizes = min_marker_size + (max_marker_size - min_marker_size) * Emission_marker_sizes;

        Standardized_marker_size = (StrandedAssetsbyCompany./RevenuebyCompany)*100;
        Standardized_scaled_size = min_marker_size + (max_marker_size - min_marker_size) * Standardized_marker_size;

        profits_marker_size = (ProfitsByCompany_CarbonTax-min(ProfitsByCompany_CarbonTax))/(max(ProfitsByCompany_CarbonTax)-min(ProfitsByCompany_CarbonTax));%normalized data between 0 and 1 for plotting
        Profits_scaled_size = min_marker_size + (max_marker_size - min_marker_size) * profits_marker_size;

        AnnualCapacityByCompany = AnnualCapacityByCompany/1000;
        capacity_marker_size = (AnnualCapacityByCompany-min(AnnualCapacityByCompany))/(max(AnnualCapacityByCompany)-min(AnnualCapacityByCompany));%normalized data between 0 and 1 for plotting
        capacity_scaled_sizes = min_marker_size + (max_marker_size - min_marker_size) * capacity_marker_size;


        figure()
        scatter(EmissionsbyCompany,StrandedAssetsbyCompany,capacity_scaled_sizes,Company_RGB_colors,'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        xlabel('Emissions')
        ylabel('Stranded assets')
        title('Size by revenue')
        % xlim([min(EmissionsbyCompany)-1000,max(EmissionsbyCompany)+1000])
        % ylim([1e10,1.3e12])
        

        figure()
        scatter(RevenuebyCompany,StrandedAssetsbyCompany,Emission_scaled_sizes,Company_RGB_colors,'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        xlabel('Revenue')
        ylabel('Stranded assets')
        title('Size by emissions')
        % ylim([1e10,1.3e12])
        

        figure()
        scatter(EmissionsbyCompany,StrandedAssetsbyCompany,capacity_scaled_sizes,Company_RGB_colors,'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('CO2 emissions')
        ylabel('Stranded assets')
        % xlim([1e6,1.5e9])
        % ylim([1e10,1.3e12])
%         legend(RegionList)
        ax = gca;
        exportgraphics(ax,['../Plots/coal scatter emissions.eps'],'ContentType','vector');
        % save('../Data/Results/CoalEmissionsbyCompany.mat','Profits_size','EmissionsbyCompany','StrandedAssetsbyCompany')

        Capacity_sizes=AnnualCapacityByCompany*500/(max(AnnualCapacityByCompany)/2);

        figure()
        scatter(AnnualCapacityByCompany,StrandedAssetsbyCompany,Profits_scaled_size,Company_RGB_colors,'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('Installed capacity')
        ylabel('Stranded assets')
        % xlim([min(AnnualCapacityByCompany), 1500000])
        % ylim([1e10,1.3e12])
        ax = gca;
        exportgraphics(ax,['../Plots/coal scatter installed capacity.eps'],'ContentType','vector');
        % save('../Data/Results/CoalAnnualCapacityByCompany.mat','Profits_size','AnnualCapacityByCompany','StrandedAssetsbyCompany')

        Plant_sizes=NumberofPlantsperCompanyperYear*5000/(max(NumberofPlantsperCompanyperYear)/2);

        figure()
        scatter(NumberofPlantsperCompanyperYear,StrandedAssetsbyCompany,Profits_scaled_size,Company_RGB_colors,'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('Number of plants')
        ylabel('Stranded assets')
        % xlim([min(NumberofPlantsperCompanyperYear),max(NumberofPlantsperCompanyperYear)+3000])
        % ylim([1e10,1.3e12])
        ax = gca;
        exportgraphics(ax,['../Plots/coal scatter number of plants.eps'],'ContentType','vector');
        % save('../Data/Results/CoalNumberofPlantsperCompanyperYear.mat','Profits_size','NumberofPlantsperCompanyperYear','StrandedAssetsbyCompany')

        Lifeleft(Lifeleft<=0)=randi(5);
        Lifeleft_size =Lifeleft*500/40;

        figure()
        scatter(Lifeleft,StrandedAssetsbyCompany,capacity_scaled_sizes,Company_RGB_colors,'filled')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('Years to retirement')
        ylabel('Stranded assets')
        % ylim([1e10,1.3e12])
        ax = gca;
        exportgraphics(ax,['../Plots/coal scatter years to retirement.eps'],'ContentType','vector');
        % save('../Data/Results/CoalLifeleft.mat','Profits_size','Lifeleft','StrandedAssetsbyCompany')

        LegendColor = 1:1:9;

        figure()
        scatter(LegendColor',LegendColor',LegendColor*100,RGB_colors,'filled')
        text(LegendColor,LegendColor,RegionList)
        legend(RegionList{:})

        figure()
        scatter(Lifeleft,StrandedAssetsbyCompany,AnnualCapacityByCompany*25,Company_RGB_colors,'filled')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('Years to retirement')
        ylabel('Stranded assets')
        % ylim([1e10,1e12])
        xlim([0, 40])
        ax = gca;
        exportgraphics(ax,'../Plots/coal scatter stranded assets remaining life standardized size.eps','ContentType','vector');

        figure()
        scatter(EmissionsbyCompany,StrandedAssetsbyCompany,AnnualCapacityByCompany*25,Company_RGB_colors,'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('CO2 emissions')
        ylabel('Stranded assets')
        % xlim([1e7,1e8])
        % ylim([1e1,1e3])
%         legend(RegionList)
        ax = gca;
        exportgraphics(ax,'../Plots/coal scatter stranded assets EmissionsbyCompany standardized size.eps','ContentType','vector');

        EmissionsbyCompany = EmissionsbyCompany*1e6;
        EmissionsPerStrandedAssets = ((CommittedEmissions)./(StrandedAssetsbyCompany*1e9)); %converts stranded assets back to $ instead of billions of dollar
        save('../Data/Results/EmissionsPerStrandedAssets_coal.mat','EmissionsPerStrandedAssets','EmissionsbyCompany','CommittedEmissions','StrandedAssetsbyCompany','Company_RGB_colors','AnnualEmissionsByCompany_Coal_strings')


        figure()
        scatter((EmissionsbyCompany),EmissionsPerStrandedAssets,100,Company_RGB_colors)
        set(gca,'xscale','log')
        xlabel('Annual emissions (t CO2)')
        ylabel('Annual emissions per dollar (tons CO2 per $)')
        % xlim([1.5e6,1e9])
        % ylim([0,60])
        ax = gca;
        exportgraphics(ax,'../Plots/Emissions per stranded assets coal.eps','ContentType','vector');

        
    elseif FUEL == 2


        if FUEL == 1
            mean_Life = mean_Life_coal;
        elseif FUEL == 2
            mean_Life = mean_Life_gas;
        end

        load '../Data/Results/PowerPlantFinances_byCompany_Gas'
        load '../Data/Results/PowerPlantFinances_byCountry_Gas'
        load '../Data/Results/GasAnnualEmissions.mat'
        load ../Data/Results/GasCompanyCapacity.mat
        load ../Data/Results/GasStrandedAssets.mat
        load ../Data/Results/GasRevenue.mat
        load '../Data/Results/colorschemecategoryGas2'

        RegionList = {'United States','Latin America','China','Europe',...
            'Middle East and Africa','Asia','Former Soviet','Australia, Canada, New Zealand','India'};
        
        RGB_colors = [1 0 0; 0 1 0; 0 0 1; 0 1 1; 1 0 1; 1 1 0; 0 0 0; 0 0.4470 0.7410; 0.8500 0.3250 0.0980];
        Gas_company_country_strings = strings(length(GasAnnualEmissions_Company),1);
        Company_RGB_colors = zeros(length(GasAnnualEmissions_Company),3);

        for i = 1:length(GasAnnualEmissions_Company)
            for j = 1:length(RegionList)
                if colorschemecategory(i) == j
                    Gas_company_country_strings(i) = RegionList(j);
                    Company_RGB_colors(i,:) = RGB_colors(j,:);
                end
            end
        end


        Unknown_companies = {'other', 'others', 'other states','other unknownmixed entity types'};
        Unknown_companies_index = find(ismember(PowerPlantString_ByCompany, Unknown_companies));
        Unknown_companies_emissions = GasAnnualEmissions_Company(Unknown_companies_index);
        Unknown_companies_capacity = TotalPowerPlantCapacitybyCompany(Unknown_companies_index,:);
        Unknown_companies_stranded_assets = StrandedAssetValuebyCompany(Unknown_companies_index,:);

        StrandedAssetValuebyCompany(Unknown_companies_index,:) = 0;%removes unknown companies after extracting them above
        TotalPowerPlantCapacitybyCompany(Unknown_companies_index,:) = 0;
        GasAnnualEmissions_Company(Unknown_companies_index) = 0;



        ProfitsByCompany_CarbonTax = squeeze(sum(PowerPlantFinances_byCompany(:,1:30,2),2));%company,year,variable
        % StrandedAssetsbyCompany = squeeze(sum(StrandedAssetValuebyCompany(:,1:40),2));
        StrandedAssetsbyCompany = StrandedAssetValuebyCompany(:,2);
        EmissionsbyCompany = squeeze(GasAnnualEmissions_Company(:,1));
        AnnualCapacityByCompany = squeeze(TotalPowerPlantCapacitybyCompany(:,1));
        NumberofPlantsperCompanyperYear = squeeze(NumberofPlantsperCompanyperYear(:,1));
        Lifeleft = mean_Life - PowerPlantLife_byCompany(:,1);

        CommittedEmissions(EmissionsbyCompany==0)=[];
        AnnualEmissionsByCompany_Gas_strings(EmissionsbyCompany==0)=[];
        StrandedAssetsbyCompany(EmissionsbyCompany == 0)=[];
        ProfitsByCompany_CarbonTax(EmissionsbyCompany ==0)=[];
        RevenuebyCompany(EmissionsbyCompany == 0)= [];
        colorschemecategory(EmissionsbyCompany==0)=[];
        AnnualCapacityByCompany(EmissionsbyCompany==0)=[];
        NumberofPlantsperCompanyperYear(EmissionsbyCompany==0)=[];
        Gas_company_country_strings(EmissionsbyCompany==0)=[];
        Company_RGB_colors(EmissionsbyCompany==0,:)=[];
        Lifeleft(EmissionsbyCompany==0)=[];
        EmissionsbyCompany(EmissionsbyCompany ==0)=[];

        CommittedEmissions(ProfitsByCompany_CarbonTax==0)=[];
        AnnualEmissionsByCompany_Gas_strings(ProfitsByCompany_CarbonTax==0)=[];
        StrandedAssetsbyCompany(ProfitsByCompany_CarbonTax==0)=[];
        RevenuebyCompany(ProfitsByCompany_CarbonTax == 0) = [];
        EmissionsbyCompany(ProfitsByCompany_CarbonTax==0)=[];
        colorschemecategory(ProfitsByCompany_CarbonTax==0)=[];
        Gas_company_country_strings(ProfitsByCompany_CarbonTax==0)=[];
        AnnualCapacityByCompany(ProfitsByCompany_CarbonTax==0)=[];
        NumberofPlantsperCompanyperYear(ProfitsByCompany_CarbonTax==0)=[];
        Company_RGB_colors(ProfitsByCompany_CarbonTax==0,:)=[];
        Lifeleft(ProfitsByCompany_CarbonTax==0)=[];
        ProfitsByCompany_CarbonTax(ProfitsByCompany_CarbonTax==0)=[];


        [StrandedAssetsbyCompany,Indx] = maxk(StrandedAssetsbyCompany,100);
        CommittedEmissions = CommittedEmissions(Indx);
        AnnualEmissionsByCompany_Gas_strings = AnnualEmissionsByCompany_Gas_strings(Indx);
        RevenuebyCompany = RevenuebyCompany(Indx);
        ProfitsByCompany_CarbonTax = ProfitsByCompany_CarbonTax(Indx);
        colorschemecategory = colorschemecategory(Indx);
        AnnualCapacityByCompany = AnnualCapacityByCompany(Indx);
        NumberofPlantsperCompanyperYear = NumberofPlantsperCompanyperYear(Indx);
        EmissionsbyCompany = EmissionsbyCompany(Indx);
        Gas_company_country_strings =Gas_company_country_strings(Indx);
        Company_RGB_colors = Company_RGB_colors(Indx,:);
        Lifeleft = Lifeleft(Indx,:);

        EmissionsbyCompany = EmissionsbyCompany/(1e6); %converts to Mt CO2
        StrandedAssetsbyCompany = StrandedAssetsbyCompany/(1e9); %converts to billions of $
        RevenuebyCompany = RevenuebyCompany/(1e9); %converts to billions of $

        % OilRevenue = cell2mat(struct2cell(load('revenuebycompany_oil.mat')));
        % GasRevenue = cell2mat(struct2cell(load('revenuebycompany_gas.mat')));
        % CoalRevenue = cell2mat(struct2cell(load('revenuebycompany_coal.mat')));
        % Revenue = [OilRevenue CoalRevenue GasRevenue];
              
        stranded_marker_size = (StrandedAssetsbyCompany-min(StrandedAssetsbyCompany))/(max(StrandedAssetsbyCompany)-min(StrandedAssetsbyCompany));%normalized data between 0 and 1 for plotting
        stranded_scaled_size = min_marker_size + (max_marker_size - min_marker_size) * stranded_marker_size;

        Emission_marker_sizes = (EmissionsbyCompany-min(EmissionsbyCompany))/(max(EmissionsbyCompany)-min(EmissionsbyCompany));%normalized data between 0 and 1 for plotting
        Emission_scaled_sizes = min_marker_size + (max_marker_size - min_marker_size) * Emission_marker_sizes;

        Standardized_marker_size = (StrandedAssetsbyCompany./RevenuebyCompany)*100;
        Standardized_scaled_size = min_marker_size + (max_marker_size - min_marker_size) * Standardized_marker_size;

        profits_marker_size = (ProfitsByCompany_CarbonTax-min(ProfitsByCompany_CarbonTax))/(max(ProfitsByCompany_CarbonTax)-min(ProfitsByCompany_CarbonTax));%normalized data between 0 and 1 for plotting
        Profits_scaled_size = min_marker_size + (max_marker_size - min_marker_size) * profits_marker_size;

        AnnualCapacityByCompany = AnnualCapacityByCompany/1e3;
        capacity_marker_size = (RevenuebyCompany-min(RevenuebyCompany))/(max(RevenuebyCompany)-min(RevenuebyCompany));%normalized data between 0 and 1 for plotting
        capacity_scaled_sizes = min_marker_size + (max_marker_size - min_marker_size) * capacity_marker_size;
        save('revenuebycompany_gas.mat','RevenuebyCompany')

        figure()
        scatter(EmissionsbyCompany/1e6,StrandedAssetsbyCompany,capacity_scaled_sizes,Company_RGB_colors,'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        xlabel('Emissions')
        ylabel('Stranded assets')
        title('Size by revenue')
        % xlim([min(EmissionsbyCompany)-1000,max(EmissionsbyCompany)+1000])
        ylim([min(StrandedAssetsbyCompany),60])

        figure()
        scatter(RevenuebyCompany,StrandedAssetsbyCompany,Emission_scaled_sizes,Company_RGB_colors,'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        xlabel('Revenue')
        ylabel('Stranded assets')
        title('Size by emissions')
        % ylim([min(StrandedAssetsbyCompany),1.75e11])

        figure()
        scatter(EmissionsbyCompany,StrandedAssetsbyCompany,capacity_scaled_sizes,[Company_RGB_colors],'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('CO2 emissions')
        ylabel('Stranded assets')
        % xlim([1e6,1.75e8])
        % ylim([min(StrandedAssetsbyCompany),1.75e11])
%         legend(RegionList)
        ax = gca;
        % exportgraphics(ax,['../Plots/Gas scatter emissions.eps'],'ContentType','vector');

        Capacity_sizes=AnnualCapacityByCompany*500/(max(AnnualCapacityByCompany)/2);

        figure()
        scatter(AnnualCapacityByCompany,StrandedAssetsbyCompany,Profits_scaled_size,[Company_RGB_colors],'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('Installed capacity')
        ylabel('Stranded assets')
        % xlim([min(AnnualCapacityByCompany), 1e5])
        ylim([0,60])
        ax = gca;
        % exportgraphics(ax,['../Plots/Gas scatter installed capacity.eps'],'ContentType','vector');

        Plant_sizes=NumberofPlantsperCompanyperYear*5000/(max(NumberofPlantsperCompanyperYear)/2);

        figure()
        scatter(NumberofPlantsperCompanyperYear,StrandedAssetsbyCompany,Profits_scaled_size,[Company_RGB_colors],'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('Number of plants')
        ylabel('Stranded assets')
        % xlim([min(NumberofPlantsperCompanyperYear),1e3])
        % ylim([min(StrandedAssetsbyCompany),1.75e11])
        ax = gca;
        % exportgraphics(ax,['../Plots/Gas scatter number of plants.eps'],'ContentType','vector');

        Lifeleft(Lifeleft<=0)=1;
        Lifeleft_size =Lifeleft*500/40;

        figure()
        scatter(Lifeleft,StrandedAssetsbyCompany,capacity_scaled_sizes,[Company_RGB_colors],'filled')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('Years to retirement')
        ylabel('Stranded assets')
        % ylim([min(StrandedAssetsbyCompany),1.75e11])
        ax = gca;
        % exportgraphics(ax,['../Plots/Gas scatter years to retirement.eps'],'ContentType','vector');

        LegendColor = 1:1:9;

        figure()
        scatter(LegendColor',LegendColor',LegendColor*100,RGB_colors,'filled')
        text(LegendColor,LegendColor,RegionList)
        legend(RegionList{:})


        figure()
        scatter(Lifeleft,StrandedAssetsbyCompany,AnnualCapacityByCompany*25,Company_RGB_colors,'filled')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('Years to retirement')
        ylabel('Stranded assets')
        % ylim([min(StrandedAssetsbyCompany),1.2e11])
        xlim([0, 30])
        ylim([0, 200])
        ax = gca;
        exportgraphics(ax,'../Plots/gas scatter stranded assets remaining life standardized size.eps','ContentType','vector');

        figure()
        scatter(EmissionsbyCompany,StrandedAssetsbyCompany,AnnualCapacityByCompany*25,Company_RGB_colors,'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('CO2 emissions')
        ylabel('Stranded assets')
        % xlim([(min(EmissionsbyCompany)-10000000),max(EmissionsbyCompany)+2000])
        ylim([0, 200])
%         legend(RegionList)
        ax = gca;
        exportgraphics(ax,'../Plots/gas scatter stranded assets EmissionsbyCompany standardized size.eps','ContentType','vector');


        EmissionsbyCompany = EmissionsbyCompany*1e6;
        EmissionsPerStrandedAssets = ((CommittedEmissions)./(StrandedAssetsbyCompany*1e9)); %converts stranded assets back to $ instead of billions of dollar
        save('../Data/Results/EmissionsPerStrandedAssets_gas.mat','EmissionsPerStrandedAssets','EmissionsbyCompany','CommittedEmissions','StrandedAssetsbyCompany','Company_RGB_colors','AnnualEmissionsByCompany_Gas_strings')


        figure()
        scatter((EmissionsbyCompany*1e6),EmissionsPerStrandedAssets,100,Company_RGB_colors)
        set(gca,'xscale','log')
        xlabel('Annual emissions (t CO2)')
        ylabel('Annual emissions per dollar (t CO2 per $)')
        % xlim([1.5e6,1e9])
        ylim([0, 200])
        ax = gca;
        exportgraphics(ax,'../Plots/Emissions per stranded assets gas.eps','ContentType','vector');

    elseif FUEL == 3

        load '../Data/Results/PowerPlantFinances_byCompany_Oil'
        load '../Data/Results/PowerPlantFinances_byCountry_Oil'
        load '../Data/Results/OilAnnualEmissions.mat'
        load ../Data/Results/OilCompanyCapacity.mat
        load ../Data/Results/OilRevenue.mat
        load '../Data/Results/colorschemecategoryOil2'

        RegionList = {'United States','Latin America','China','Europe',...
            'Middle East and Africa','Asia','Former Soviet','Australia, Canada, New Zealand','India'};

        Symbol_list = {'diamond', 'x', '+', '*', 'x', 'x','*','x', 'x','x','square'};
        Region_symbols = strings(length(OilAnnualEmissions_Company),1);
        
        RGB_colors = [1 0 0; 0 1 0; 0 0 1; 0 1 1; 1 0 1; 1 1 0; 0 0 0; 0 0.4470 0.7410; 0.8500 0.3250 0.0980];
        Oil_company_country_strings = strings(length(OilAnnualEmissions_Company),1);
        
        Company_RGB_colors = zeros(length(OilAnnualEmissions_Company),3);

        for i = 1:length(OilAnnualEmissions_Company)
            for j = 1:length(RegionList)
                if colorschemecategory(i) == j
                    Oil_company_country_strings(i) = RegionList(j);
                    Company_RGB_colors(i,:) = RGB_colors(j,:);
                    Region_symbols(i) = Symbol_list(j);
                end
            end
        end



        ProfitsByCompany_CarbonTax = squeeze(PowerPlantFinances_byCompany(:,1,2));%company,year,variable
        StrandedAssetsbyCompany = squeeze(PowerPlantFinances_byCompany(:,1,5));
        EmissionsbyCompany = squeeze(OilAnnualEmissions_Company(:,1));
        AnnualCapacityByCompany = squeeze(AnnualCapacityByCompany(:,1));
        NumberofPlantsperCompanyperYear = squeeze(NumberofPlantsperCompanyperYear(:,1));
        Lifeleft = mean_Life - PowerPlantLife_byCompany(:,1);

        CommittedEmissions(EmissionsbyCompany==0)=[];
        AnnualEmissionsByCompany_Oil_strings(EmissionsbyCompany==0)=[];
        StrandedAssetsbyCompany(EmissionsbyCompany == 0)=[];
        ProfitsByCompany_CarbonTax(EmissionsbyCompany ==0)=[];
        RevenuebyCompany(EmissionsbyCompany == 0)= [];
        colorschemecategory(EmissionsbyCompany==0)=[];
        AnnualCapacityByCompany(EmissionsbyCompany==0)=[];
        NumberofPlantsperCompanyperYear(EmissionsbyCompany==0)=[];
        Oil_company_country_strings(EmissionsbyCompany==0)=[];
        Company_RGB_colors(EmissionsbyCompany==0,:)=[];
        Lifeleft(EmissionsbyCompany==0)=[];
        EmissionsbyCompany(EmissionsbyCompany ==0)=[];
        
        CommittedEmissions(ProfitsByCompany_CarbonTax==0)=[];
        AnnualEmissionsByCompany_Oil_strings(ProfitsByCompany_CarbonTax==0)=[];
        StrandedAssetsbyCompany(ProfitsByCompany_CarbonTax==0)=[];
        RevenuebyCompany(ProfitsByCompany_CarbonTax == 0) = [];
        EmissionsbyCompany(ProfitsByCompany_CarbonTax==0)=[];
        colorschemecategory(ProfitsByCompany_CarbonTax==0)=[];
        Oil_company_country_strings(ProfitsByCompany_CarbonTax==0)=[];
        AnnualCapacityByCompany(ProfitsByCompany_CarbonTax==0)=[];
        NumberofPlantsperCompanyperYear(ProfitsByCompany_CarbonTax==0)=[];
        Company_RGB_colors(ProfitsByCompany_CarbonTax==0,:)=[];
        Lifeleft(ProfitsByCompany_CarbonTax==0)=[];
        ProfitsByCompany_CarbonTax(ProfitsByCompany_CarbonTax==0)=[];


        [StrandedAssetsbyCompany,Indx] = maxk(StrandedAssetsbyCompany,100);
        CommittedEmissions = CommittedEmissions(Indx);
        AnnualEmissionsByCompany_Oil_strings = AnnualEmissionsByCompany_Oil_strings(Indx);
        RevenuebyCompany = RevenuebyCompany(Indx);
        ProfitsByCompany_CarbonTax = ProfitsByCompany_CarbonTax(Indx);
        colorschemecategory = colorschemecategory(Indx);
        AnnualCapacityByCompany = AnnualCapacityByCompany(Indx);
        NumberofPlantsperCompanyperYear = NumberofPlantsperCompanyperYear(Indx);
        EmissionsbyCompany = EmissionsbyCompany(Indx);
        Oil_company_country_strings =Oil_company_country_strings(Indx);
        Company_RGB_colors = Company_RGB_colors(Indx,:);
        Lifeleft = Lifeleft(Indx,:);
              
        Emission_scaled_sizes=EmissionsbyCompany*5000/(max(EmissionsbyCompany)/2);
        stranded_scaled_size = StrandedAssetsbyCompany*500/(max(StrandedAssetsbyCompany)/2);

        % OilRevenue = cell2mat(struct2cell(load('revenuebycompany_oil.mat')));
        % GasRevenue = cell2mat(struct2cell(load('revenuebycompany_gas.mat')));
        % CoalRevenue = cell2mat(struct2cell(load('revenuebycompany_coal.mat')));
        % Revenue = [OilRevenue CoalRevenue GasRevenue];


        Profits_scaled_size = ProfitsByCompany_CarbonTax*5000/(max(ProfitsByCompany_CarbonTax)/2);
        capacity_marker_size = RevenuebyCompany*5000/(max(Revenue(:))/2);
        save('revenuebycompany_oil.mat','RevenuebyCompany')
        Standardized_scaled_size = (StrandedAssetsbyCompany./RevenuebyCompany)*100;

        figure()
        scatter(EmissionsbyCompany,StrandedAssetsbyCompany,capacity_marker_size,Company_RGB_colors,'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        xlabel('Emissions')
        ylabel('Stranded assets')
        title('Size by revenue')
        xlim([min(EmissionsbyCompany)-1000,max(EmissionsbyCompany)+1000])
        ylim([min(StrandedAssetsbyCompany),2.5e11])

        figure()
        scatter(RevenuebyCompany,StrandedAssetsbyCompany,Emission_scaled_sizes,Company_RGB_colors,'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        xlabel('Revenue')
        ylabel('Stranded assets')
        title('Size by emissions')
        ylim([min(StrandedAssetsbyCompany),2.5e11])

        figure()
        scatter(EmissionsbyCompany,StrandedAssetsbyCompany,capacity_marker_size,[Company_RGB_colors],'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('CO2 emissions')
        ylabel('Stranded assets')
%         xlim([min(EmissionsbyCompany),1e10])
        ylim([min(StrandedAssetsbyCompany),2.5e11])
%         legend(RegionList)
        ax = gca;
        % exportgraphics(ax,['../Plots/Oil scatter emissions.eps'],'ContentType','vector');

        Capacity_sizes=AnnualCapacityByCompany*500/(max(AnnualCapacityByCompany)/2);

        figure()
        scatter(AnnualCapacityByCompany,StrandedAssetsbyCompany,Profits_scaled_size,[Company_RGB_colors],'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('Installed capacity')
        ylabel('Stranded assets')
        xlim([min(AnnualCapacityByCompany), 1500000])
        ylim([min(StrandedAssetsbyCompany),2.5e11])
        ax = gca;
        % exportgraphics(ax,['../Plots/Oil scatter installed capacity.eps'],'ContentType','vector');

        Plant_sizes=NumberofPlantsperCompanyperYear*5000/(max(NumberofPlantsperCompanyperYear)/2);

        figure()
        scatter(NumberofPlantsperCompanyperYear,StrandedAssetsbyCompany,Profits_scaled_size,[Company_RGB_colors],'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('Number of plants')
        ylabel('Stranded assets')
        xlim([min(NumberofPlantsperCompanyperYear),max(NumberofPlantsperCompanyperYear)+3000])
        ylim([min(StrandedAssetsbyCompany),2.5e11])
        ax = gca;
%         exportgraphics(ax,['../Plots/Oil scatter number of plants.eps'],'ContentType','vector');

        Lifeleft(Lifeleft<=0)=1;
        Lifeleft_size =Lifeleft*500/40;

        figure()
        scatter(Lifeleft,StrandedAssetsbyCompany,capacity_marker_size,[Company_RGB_colors],'filled')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('Years to retirement')
        ylabel('Stranded assets')
        ylim([min(StrandedAssetsbyCompany),2.5e11])
        ax = gca;
        % exportgraphics(ax,['../Plots/Oil scatter years to retirement.eps'],'ContentType','vector');

        LegendColor = 1:1:9;

        figure()
        scatter(LegendColor',LegendColor',LegendColor*100,RGB_colors,'filled')
        text(LegendColor,LegendColor,RegionList)
        legend(RegionList{:})


        figure()
        scatter(Lifeleft,StrandedAssetsbyCompany,Standardized_scaled_size,Company_RGB_colors,'filled')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('Years to retirement')
        ylabel('Stranded assets')
        ylim([min(StrandedAssetsbyCompany),1.1e11])
        ax = gca;
        exportgraphics(ax,'../Plots/oil scatter stranded assets remaining life standardized size.eps','ContentType','vector');


        figure()
        scatter(EmissionsbyCompany,StrandedAssetsbyCompany,Standardized_scaled_size,Company_RGB_colors,'filled')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        set(gca,'zscale','log')
        xlabel('CO2 emissions')
        ylabel('Stranded assets')
%         xlim([min(EmissionsbyCompany),1e10])
        ylim([min(StrandedAssetsbyCompany),1.1e11])
        legend show
        ax = gca;
        exportgraphics(ax,'../Plots/oil scatter stranded assets EmissionsbyCompany standardized size.eps','ContentType','vector');
    

        EmissionsPerStrandedAssets = ((CommittedEmissions)./(StrandedAssetsbyCompany*1e12)); %converts stranded assets back to $ instead of trillion of dollar
        save('../Data/Results/EmissionsPerStrandedAssets_oil.mat','EmissionsPerStrandedAssets','EmissionsbyCompany','Company_RGB_colors')


        figure()
        scatter((EmissionsbyCompany),EmissionsPerStrandedAssets,100,Company_RGB_colors)
        set(gca,'xscale','log')
        xlabel('Annual emissions (Gt CO2)')
        ylabel('Annual emissions per dollar (kg CO2 per $)')
        xlim([10e3,1e8])
        ylim([0,70])
        ax = gca;
        exportgraphics(ax,'../Plots/Emissions per stranded assets oil.eps','ContentType','vector');




        Standardized_size_sorted = sort(Standardized_scaled_size);
        figure(); % calculates the marker values for the legend below
        binEdges = linspace(min(Standardized_size_sorted), max(Standardized_size_sorted), 6); % Create 5 equally spaced bin edges
        histcounts(Standardized_size_sorted, binEdges);
        histogram('BinEdges', binEdges, 'BinCounts', histcounts(Standardized_size_sorted, binEdges));

        
        legentry=cell(size(binEdges));
        figure,hold on
        for ind = 1:numel(binEdges)
           bubleg(ind) = plot(0,0,'ro','markersize',sqrt(binEdges(ind)),'MarkerFaceColor','red');
           set(bubleg(ind),'visible','off')
           legentry{ind} = num2str(round(binEdges(ind)/100,2));
        end
        h = scatter(EmissionsbyCompany,StrandedAssetsbyCompany,Standardized_scaled_size,Company_RGB_colors,'filled');
        legend(legentry)


figure; hold on
plot(1,1,'ko', 'MarkerSize', 12)
plot(1,2,'k+', 'MarkerSize', 12)
plot(2,1,'kx', 'MarkerSize', 12)
h = legend('Circle', 'Plus', 'X', 'Location', 'NorthEast');
set(h, 'FontSize', 14)
axis([0 3 0 3])

    end

elseif section == 10
    if FUEL == 1
        load '../Data/Results/PowerPlantFinances_byCompany_Coal'
        load '../Data/Results/CoalAnnualEmissions.mat'
        load '../Data/Results/colorschemecategoryCoal2'
        load ../Data/Results/CoalCompanyCapacity.mat
    
        RegionList = {'United States','Latin America','China','Europe',...
                'Middle East and Africa','Asia','Former Soviet','Australia, Canada, New Zealand','India'};
            
        RGB_colors = [1 0 0; 0 1 0; 0 0 1; 0 1 1; 1 0 1; 1 1 0; 0 0 0; 0 0.4470 0.7410; 0.8500 0.3250 0.0980];
            
    
        Company_RGB_colors = zeros(length(CoalAnnualEmissions_Company),3);
    
        for i = 1:length(CoalAnnualEmissions_Company)
            for j = 1:length(RegionList)
                if colorschemecategory(i) == j
                    Coal_company_country_strings(i) = RegionList(j);
                    Company_RGB_colors(i,:) = RGB_colors(j,:);
                end
            end
        end
    
        StrandedAssetsbyCompany = squeeze(PowerPlantFinances_byCompany(:,1,5));
        CommittedEmissions_Company = sum(CoalAnnualEmissions_Company,2);
        % NPV_CT = PowerPlantFinances_byCompany(:,1,4);
        % Installed_Capacity = AnnualCapacityByCompany(:,1);
        % Company_RGB_colors_NPV = Company_RGB_colors;
    
        % 
        % NPV_CT(Installed_Capacity==0)=0;
        % Installed_Capacity(NPV_CT==0)=0;

        % [Sorted_for_strings_NPV,String_Indx_NPV] = sort(NPV_CT,"descend");
        % Sorted_Company_strings_NPV = AnnualEmissionsByCompany_Coal_strings(String_Indx_NPV);

        % Company_RGB_colors_NPV(NPV_CT==0,:)=[];
        % NPV_CT(NPV_CT==0)=[]; Installed_Capacity(Installed_Capacity==0)=[];

        CommittedEmissions_Company(StrandedAssetsbyCompany==0) = 0;
        StrandedAssetsbyCompany(CommittedEmissions_Company==0) = 0;

        [Sorted_for_strings,String_Indx] = sort(StrandedAssetsbyCompany,"descend");
        Sorted_Company_strings = AnnualEmissionsByCompany_Coal_strings(String_Indx);

        CommittedEmissions_Company(CommittedEmissions_Company==0)=[];
        Company_RGB_colors(StrandedAssetsbyCompany==0,:)=[];
        StrandedAssetsbyCompany(StrandedAssetsbyCompany==0)=[];
    
        CDF_Share_Company_Emissions = zeros(length(CommittedEmissions_Company),1);
        % CDF_Share_Company_Capacity = zeros(length(Installed_Capacity),1);
    
        [Sorted_SA,Indx] = sort(StrandedAssetsbyCompany,"descend");
        Sorted_Emissions = CommittedEmissions_Company(Indx);
        Company_RGB_colors = Company_RGB_colors(Indx,:);


        % [Sorted_NPV,Indx] = sort(NPV_CT,"descend");
        % Sorted_Installed_Capacity = Installed_Capacity(Indx);
        % Company_RGB_colors_NPV = Company_RGB_colors_NPV(Indx,:);
        % 
        % for i = 1:length(CDF_Share_Company_Capacity)
        %     if i==1
        %         CDF_Share_Company_Capacity(i,1) = Sorted_Installed_Capacity(i,1);
        %     else
        %         CDF_Share_Company_Capacity(i,1) = Sorted_Installed_Capacity(i,1) + CDF_Share_Company_Capacity(i-1,1);
        %     end
        % end


        for i = 1:length(CDF_Share_Company_Emissions)
            if i==1
                CDF_Share_Company_Emissions(i,1) = Sorted_Emissions(i,1);
            else
                CDF_Share_Company_Emissions(i,1) = Sorted_Emissions(i,1) + CDF_Share_Company_Emissions(i-1,1);
            end
        end
        
    
        edges = zeros(length(CDF_Share_Company_Emissions)+1,1);
        edges(2:end,1) = CDF_Share_Company_Emissions;
        vals = Sorted_SA;
    

    
        center = (edges(1:end-1) + edges(2:end))/2;
        width = diff(edges);

        figure()
        hold on
        for i=1:length(center)
            bar(center(i),vals(i),width(i),'FaceColor', Company_RGB_colors(i,:))
        end
        hold off
        set(gca,'yscale','log')
        ylim([0 1e12])
        cx = gca;
        exportgraphics(cx,['../Plots/Coal_CDF.eps'],'ContentType','vector');   


%         figure()
%         hold on
%         for i=1:length(center_NPV)
%             bar(center_NPV(i),vals_NPV(i),width_NPV(i),'FaceColor', Company_RGB_colors_NPV(i,:))
%         end
%         hold off
%         set(gca,'yscale','log')
% %         ylim([0 1e12])
%         cx = gca;
%         exportgraphics(cx,['../Plots/Coal_CDF_NPV.eps'],'ContentType','vector');

    elseif FUEL == 2

        load '../Data/Results/PowerPlantFinances_byCompany_Gas'
        load '../Data/Results/GasAnnualEmissions.mat'
        load '../Data/Results/colorschemecategoryGas2'
        load ../Data/Results/GasCompanyCapacity.mat
    
        RegionList = {'United States','Latin America','China','Europe',...
                'Middle East and Africa','Asia','Former Soviet','Australia, Canada, New Zealand','India'};
            
        RGB_colors = [1 0 0; 0 1 0; 0 0 1; 0 1 1; 1 0 1; 1 1 0; 0 0 0; 0 0.4470 0.7410; 0.8500 0.3250 0.0980];
            
    
        Company_RGB_colors = zeros(length(GasAnnualEmissions_Company),3);
    
        for i = 1:length(GasAnnualEmissions_Company)
            for j = 1:length(RegionList)
                if colorschemecategory(i) == j
                    Gas_company_country_strings(i) = RegionList(j);
                    Company_RGB_colors(i,:) = RGB_colors(j,:);
                end
            end
        end
    
        StrandedAssetsbyCompany = squeeze(PowerPlantFinances_byCompany(:,1,5));
        CommittedEmissions_Company = sum(GasAnnualEmissions_Company,2);
        NPV_CT = PowerPlantFinances_byCompany(:,1,4);
        Installed_Capacity = AnnualCapacityByCompany(:,1);
        Company_RGB_colors_NPV = Company_RGB_colors;
    

        NPV_CT(Installed_Capacity==0)=0;
        Installed_Capacity(NPV_CT==0)=0;

        [Sorted_for_strings_NPV,String_Indx_NPV] = sort(NPV_CT,"descend");
        Sorted_Company_strings_NPV = AnnualEmissionsByCompany_Gas_strings(String_Indx_NPV);

        Company_RGB_colors_NPV(NPV_CT==0,:)=[];
        NPV_CT(NPV_CT==0)=[]; Installed_Capacity(Installed_Capacity==0)=[];

        CommittedEmissions_Company(StrandedAssetsbyCompany==0) = 0;
        StrandedAssetsbyCompany(CommittedEmissions_Company==0) = 0;

        [Sorted_for_strings,String_Indx] = sort(StrandedAssetsbyCompany,"descend");
        Sorted_Company_strings = AnnualEmissionsByCompany_Gas_strings(String_Indx);

        CommittedEmissions_Company(CommittedEmissions_Company==0)=[];
        Company_RGB_colors(StrandedAssetsbyCompany==0,:)=[];
        StrandedAssetsbyCompany(StrandedAssetsbyCompany==0)=[];
    
        CDF_Share_Company_Emissions = zeros(length(CommittedEmissions_Company),1);
        CDF_Share_Company_Capacity = zeros(length(Installed_Capacity),1);
    
        [Sorted_SA,Indx] = sort(StrandedAssetsbyCompany,"descend");
        Sorted_Emissions = CommittedEmissions_Company(Indx);
        Company_RGB_colors = Company_RGB_colors(Indx,:);


        [Sorted_NPV,Indx] = sort(NPV_CT,"descend");
        Sorted_Installed_Capacity = Installed_Capacity(Indx);
        Company_RGB_colors_NPV = Company_RGB_colors_NPV(Indx,:);
    
        for i = 1:length(CDF_Share_Company_Capacity)
            if i==1
                CDF_Share_Company_Capacity(i,1) = Sorted_Installed_Capacity(i,1);
            else
                CDF_Share_Company_Capacity(i,1) = Sorted_Installed_Capacity(i,1) + CDF_Share_Company_Capacity(i-1,1);
            end
        end


        for i = 1:length(CDF_Share_Company_Emissions)
            if i==1
                CDF_Share_Company_Emissions(i,1) = Sorted_Emissions(i,1);
            else
                CDF_Share_Company_Emissions(i,1) = Sorted_Emissions(i,1) + CDF_Share_Company_Emissions(i-1,1);
            end
        end
        
    
        edges = zeros(length(CDF_Share_Company_Emissions)+1,1);
        edges(2:end,1) = CDF_Share_Company_Emissions;
        vals = Sorted_SA;
    
        edges_NPV = zeros(length(CDF_Share_Company_Capacity)+1,1);
        edges_NPV(2:end,1) = CDF_Share_Company_Capacity;
        vals_NPV = Sorted_NPV;
    
    
        center = (edges(1:end-1) + edges(2:end))/2;
        width = diff(edges);

        center_NPV = (edges_NPV(1:end-1) + edges_NPV(2:end))/2;
        width_NPV = diff(edges_NPV);
    
        figure()
        hold on
        for i=1:length(center)
            bar(center(i),vals(i),width(i),'FaceColor', Company_RGB_colors(i,:))
        end
        hold off
        set(gca,'yscale','log')
        ylim([0 1e12])
        cx = gca;
        exportgraphics(cx,['../Plots/Gas_CDF.eps'],'ContentType','vector');   

% 
%         figure()
%         hold on
%         for i=1:length(center_NPV)
%             bar(center_NPV(i),vals_NPV(i),width_NPV(i),'FaceColor', Company_RGB_colors_NPV(i,:))
%         end
%         hold off
%         set(gca,'yscale','log')
% %         ylim([0 1e12])
%         cx = gca;
%         exportgraphics(cx,['../Plots/Gas_CDF_NPV.eps'],'ContentType','vector');

        
    elseif FUEL == 3

        load '../Data/Results/PowerPlantFinances_byCompany_Oil'
        load '../Data/Results/OilAnnualEmissions.mat'
        load '../Data/Results/colorschemecategoryOil2'
        load ../Data/Results/OilCompanyCapacity.mat
    
        RegionList = {'United States','Latin America','China','Europe',...
                'Middle East and Africa','Asia','Former Soviet','Australia, Canada, New Zealand','India'};
            
        RGB_colors = [1 0 0; 0 1 0; 0 0 1; 0 1 1; 1 0 1; 1 1 0; 0 0 0; 0 0.4470 0.7410; 0.8500 0.3250 0.0980];
            
    
        Company_RGB_colors = zeros(length(OilAnnualEmissions_Company),3);
    
        for i = 1:length(OilAnnualEmissions_Company)
            for j = 1:length(RegionList)
                if colorschemecategory(i) == j
                    Oil_company_country_strings(i) = RegionList(j);
                    Company_RGB_colors(i,:) = RGB_colors(j,:);
                end
            end
        end
    
        StrandedAssetsbyCompany = squeeze(PowerPlantFinances_byCompany(:,1,5));
        CommittedEmissions_Company = sum(OilAnnualEmissions_Company,2);
        NPV_CT = PowerPlantFinances_byCompany(:,1,4);
        Installed_Capacity = AnnualCapacityByCompany(:,1);
        Company_RGB_colors_NPV = Company_RGB_colors;
    

        NPV_CT(Installed_Capacity==0)=0;
        Installed_Capacity(NPV_CT==0)=0;

        [Sorted_for_strings_NPV,String_Indx_NPV] = sort(NPV_CT,"descend");
        Sorted_Company_strings_NPV = AnnualEmissionsByCompany_Oil_strings(String_Indx_NPV);

        Company_RGB_colors_NPV(NPV_CT==0,:)=[];
        NPV_CT(NPV_CT==0)=[]; Installed_Capacity(Installed_Capacity==0)=[];

        CommittedEmissions_Company(StrandedAssetsbyCompany==0) = 0;
        StrandedAssetsbyCompany(CommittedEmissions_Company==0) = 0;

        [Sorted_for_strings,String_Indx] = sort(StrandedAssetsbyCompany,"descend");
        Sorted_Company_strings = AnnualEmissionsByCompany_Oil_strings(String_Indx);

        CommittedEmissions_Company(CommittedEmissions_Company==0)=[];
        Company_RGB_colors(StrandedAssetsbyCompany==0,:)=[];
        StrandedAssetsbyCompany(StrandedAssetsbyCompany==0)=[];
    
        CDF_Share_Company_Emissions = zeros(length(CommittedEmissions_Company),1);
        CDF_Share_Company_Capacity = zeros(length(Installed_Capacity),1);
    
        [Sorted_SA,Indx] = sort(StrandedAssetsbyCompany,"descend");
        Sorted_Emissions = CommittedEmissions_Company(Indx);
        Company_RGB_colors = Company_RGB_colors(Indx,:);


        [Sorted_NPV,Indx] = sort(NPV_CT,"descend");
        Sorted_Installed_Capacity = Installed_Capacity(Indx);
        Company_RGB_colors_NPV = Company_RGB_colors_NPV(Indx,:);
    
        for i = 1:length(CDF_Share_Company_Capacity)
            if i==1
                CDF_Share_Company_Capacity(i,1) = Sorted_Installed_Capacity(i,1);
            else
                CDF_Share_Company_Capacity(i,1) = Sorted_Installed_Capacity(i,1) + CDF_Share_Company_Capacity(i-1,1);
            end
        end


        for i = 1:length(CDF_Share_Company_Emissions)
            if i==1
                CDF_Share_Company_Emissions(i,1) = Sorted_Emissions(i,1);
            else
                CDF_Share_Company_Emissions(i,1) = Sorted_Emissions(i,1) + CDF_Share_Company_Emissions(i-1,1);
            end
        end
        
    
        edges = zeros(length(CDF_Share_Company_Emissions)+1,1);
        edges(2:end,1) = CDF_Share_Company_Emissions;
        vals = Sorted_SA;
    
        edges_NPV = zeros(length(CDF_Share_Company_Capacity)+1,1);
        edges_NPV(2:end,1) = CDF_Share_Company_Capacity;
        vals_NPV = Sorted_NPV;
    
    
        center = (edges(1:end-1) + edges(2:end))/2;
        width = diff(edges);

        center_NPV = (edges_NPV(1:end-1) + edges_NPV(2:end))/2;
        width_NPV = diff(edges_NPV);
    
        figure()
        hold on
        for i=1:length(center)
            bar(center(i),vals(i),width(i),'FaceColor', Company_RGB_colors(i,:))
        end
        hold off
        set(gca,'yscale','log')
        ylim([0 1e14])
        cx = gca;
        exportgraphics(cx,['../Plots/Oil_CDF.eps'],'ContentType','vector');   

% 
%         figure()
%         hold on
%         for i=1:length(center_NPV)
%             bar(center_NPV(i),vals_NPV(i),width_NPV(i),'FaceColor', Company_RGB_colors_NPV(i,:))
%         end
%         hold off
%         set(gca,'yscale','log')
% %         ylim([0 1e12])
%         cx = gca;
%         exportgraphics(cx,['../Plots/Oil_CDF_NPV.eps'],'ContentType','vector');



    end

elseif section == 11
    for gentype = FUEL
        if gentype == 1

            %vary profits and costs....
            %plot profits(y-axis) and costs(x-axis), stranded
            %assets(z-axis)
            load('../Data/Results/Coal_Plants');
            load('../Data/Results/Coal_Plants_strings');
            load('../Data/Results/CoalCostbyCountry')
            load('../Data/WholeSaleCostofElectricityCoal');
            CarbonTax19 = xlsread('../Data/CarbonTax1_9.xlsx','standard');
            CarbonTax26 = xlsread('../Data/CarbonTax2_6.xlsx','standard');
            load '../Data/Results/CoalColors'
            load('../Data/Results/DecommissionYearCoal')
            load('../Data/Results/OM_Costs_Coal.mat');
            load(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''])
            
            matrixsize = 61;

            if randomsave == 1
                MC_values_1 = randi(matrixsize,10000,1);
                MC_values_2 = randi(matrixsize,10000,1);
                MC_values_3 = randi(matrixsize,10000,1);
                save("MC_values.mat","MC_values_1","MC_values_2","MC_values_3")
            elseif randomsave == 0 
                load("MC_values.mat");
            end
               

            
            FuelCosts = F_Costs;
            LifeLeft = mean_Life_coal - Plants(:,2);

            % Plants(Plants==0)=nan;
            
            sensitivity_range_fuel_costs = min(F_Costs(:)):(max(F_Costs(:))-min(F_Costs(:)))/(matrixsize-1):max(F_Costs(:));
            sensitivity_range_capital_costs = min(Plants(:,6)):(max(Plants(:,6))-min(Plants(:,6)))/(matrixsize-1):max(Plants(:,6));
            sensitivity_range_CT = 1:(500-1)/(matrixsize-1):500;%$dollars
            sensitivity_range_WS = 0:(200-0)/(matrixsize-1):200;%min to max with 100 steps $dollars/kwh
            CF_range = .2:(.9-.2)/(matrixsize-1):.9;


%             PowerPlantProfits = zeros(length(Plants),length(sensitivity_range_WS));
%             PowerPlantProfits_CarbonTax = zeros(length(Plants),length(sensitivity_range_CT),length(sensitivity_range_WS));
            
            PowerPlantCosts_CT = zeros(length(Plants),length(sensitivity_range_fuel_costs),length(sensitivity_range_capital_costs),length(sensitivity_range_CT));

            Plants(isnan(Plants))=0;


            % for generator = 1:length(Plants)
            %     for sensitivity_range = 1:matrixsize
            %         PowerPlantRevenue(generator,sensitivity_range) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*sensitivity_range_WS(sensitivity_range));
            %     end
            % end
            % 
            % TotalPowerSectorRevenue = squeeze(nansum(PowerPlantRevenue,1));
            % 
            % 
            % for generator = 1:length(Plants)
            %    for fuel_costs = 1:matrixsize
            %        for capital_range = 1:matrixsize
            %             PowerPlantCosts(generator,fuel_costs,capital_range) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*(sensitivity_range_fuel_costs(fuel_costs)./Plants(generator,7)))...%costs
            %             + Plants(generator,8)*Plants(generator,1) + sensitivity_range_capital_costs(capital_range)*Plants(generator,1).*DiscountRate;
            %        end
            %    end
            % end
            % 
            % TotalPowerSectorCosts = squeeze(nansum(PowerPlantCosts,1));
            % 
            % 
            % for generator = 1:length(Plants)
            %    for fuel_costs = 1:matrixsize
            %        for capital_range = 1:matrixsize
            %            for CT = 1:matrixsize
            %                 PowerPlantCosts_CT(generator,fuel_costs,capital_range,CT) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*(sensitivity_range_fuel_costs(fuel_costs)./Plants(generator,7))+Plants(generator,4)*(sensitivity_range_CT(CT)))...%costs
            %                 + Plants(generator,8)*Plants(generator,1) + sensitivity_range_capital_costs(capital_range)*Plants(generator,1).*DiscountRate;
            %            end
            %        end
            %    end
            % end

            
            % TotalPowerSectorCosts_CT = squeeze(nansum(PowerPlantCosts_CT,1));
            % PowerSectorStrandedAssets = zeros(matrixsize,matrixsize,matrixsize,matrixsize);%wholesale price of electricity, fuel costs, capital costs, carbon tax
            % 
            % 
            % 
            % for WS = 1:matrixsize
            %     for fuel_costs = 1:matrixsize
            %         for capital = 1:matrixsize
            %             for CT = 1:matrixsize
            %                 PowerSectorStrandedAssets(WS,fuel_costs,capital,CT) = TotalPowerSectorRevenue(WS) - ...
            %                     (TotalPowerSectorCosts(fuel_costs,capital) - TotalPowerSectorCosts_CT(fuel_costs,capital,CT))./(1 + DiscountRate).^1;
            %             end
            %         end
            %     end
            % end

            max_Life = nanmax(LifeLeft);

            % PowerPlantProfits_CarbonTax = zeros(length(PowerPlantProfits),max_Life,4);
            Stranded_Assets_based_on_added_costs = zeros(length(Plants),max_Life,length(CF_range),length(sensitivity_range_CT));
            for generator = 1:length(Plants)%%add in carbon tax portion
                for yr = 1:max_Life
                    for CF = 1:length(CF_range)
                        for tax = 1:length(sensitivity_range_CT)
                            Stranded_Assets_based_on_added_costs(generator,yr,CF,tax) = sensitivity_range_CT(tax)*(Plants(generator,1).*CF_range(CF).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                        end
                    end
                end
            end

            for generator = 1:length(Plants)%%add in carbon tax portion
                for yr = 1:max_Life
                    for CF = 1:length(CF_range)
                        for tax = 1:length(sensitivity_range_CT)
                            Stranded_Assets_based_on_added_costs(generator,yr,CF,tax) = Stranded_Assets_based_on_added_costs(generator,yr,CF,tax)./((1 + DiscountRate).^yr);
                        end
                    end
                end
            end

            


            % StrandedAssets = zeros(matrixsize,matrixsize);%profits and costs
            % 
            % StrandedAssets(:,1) = PowerSectorStrandedAssets(:,1);
            % 
            % for i = 1:matrixsize
            %     for MC = 1:MC_values_1
            %         StrandedAssets(:,i) = (StrandedAssets(:,i) + PowerSectorStrandedAssets(:,MC_values_1(MC),MC_values_2(MC),MC_values_3(MC)))/2;%takes the mean of a monte carlo
            %     end
            % end
            
            [CarbonTax, Capacity_Factor] = meshgrid(sensitivity_range_CT, CF_range);
            vals = squeeze(nansum(nansum(Stranded_Assets_based_on_added_costs,1),2))/1e12; % converts to trillions of dollars
            
            contourrange = 0:.05:1000;
            
            figure()
            CF = contourf(Capacity_Factor, CarbonTax, vals, contourrange);
            % clabel(CF); % Add contour labels
            xlabel('Capacity Factor');
            ylabel('Carbon Tax');
            colormap(flip(brewermap(length(contourrange),'Spectral'))); % Ensure correct colormap usage
            c = colorbar;
            clim([0 80])
            c.Label.String = 'Stranded Assets (Trillions of Dollars)'; % Label the colorbar

            hold on;
            whiteContours = contour(Capacity_Factor, CarbonTax, vals, [5, 10,20, 30, 50, 70], 'LineColor', 'white', 'LineWidth', 1.5); % Example levels
            clabel(whiteContours);

            ax = gca;
            exportgraphics(ax,['../Plots/coal_sensitivity_plot.eps'],'ContentType','vector');

        elseif gentype == 2 
            
            load('../Data/Results/Gas_Plants');
            load('../Data/Results/Gas_Plants_strings');
            load('../Data/Results/GasCostbyCountry')
            load('../Data/WholeSaleCostofElectricityGas');
            CarbonTax19 = xlsread('../Data/CarbonTax1_9.xlsx');
            CarbonTax26 = xlsread('../Data/CarbonTax2_6.xlsx');
            load '../Data/Results/GasColors'
            load('../Data/Results/DecommissionYearGas')
            load('../Data/Results/OM_Costs_Gas.mat');
            
            matrixsize = 31;

            if randomsave == 1
                MC_values_1 = randi(matrixsize,10000,1);
                MC_values_2 = randi(matrixsize,10000,1);
                MC_values_3 = randi(matrixsize,10000,1);
                save("MC_values_Gas.mat","MC_values_1","MC_values_2","MC_values_3")
            elseif randomsave == 0 
                load("MC_values_Gas.mat");
            end
               

            
            FuelCosts = F_Costs;
            LifeLeft = mean_Life_gas - Plants(:,2);

            sensitivity_range_fuel_costs = min(F_Costs(:)):(max(F_Costs(:))-min(F_Costs(:)))/(matrixsize-1):max(F_Costs(:));
            sensitivity_range_capital_costs = min(Plants(:,6)):(max(Plants(:,6))-min(Plants(:,6)))/(matrixsize-1):max(Plants(:,6));
            sensitivity_range_CT = 1:(500-1)/(matrixsize-1):500;%$dollars
            sensitivity_range_WS = 0:(200-0)/(matrixsize-1):200;%min to max with 100 steps $dollars/kwh
            CF_range = .2:(.9-.2)/(matrixsize-1):.9;


%             PowerPlantProfits = zeros(length(Plants),length(sensitivity_range_WS));
%             PowerPlantProfits_CarbonTax = zeros(length(Plants),length(sensitivity_range_CT),length(sensitivity_range_WS));
            
            PowerPlantCosts_CT = zeros(length(Plants),length(sensitivity_range_fuel_costs),length(sensitivity_range_capital_costs),length(sensitivity_range_CT));

            Plants(isnan(Plants))=0;


            % for generator = 1:length(Plants)
            %     for sensitivity_range = 1:matrixsize
            %         PowerPlantRevenue(generator,sensitivity_range) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*sensitivity_range_WS(sensitivity_range));
            %     end
            % end
            % 
            % TotalPowerSectorRevenue = squeeze(nansum(PowerPlantRevenue,1));
            % 
            % 
            % for generator = 1:length(Plants)
            %    for fuel_costs = 1:matrixsize
            %        for capital_range = 1:matrixsize
            %             PowerPlantCosts(generator,fuel_costs,capital_range) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*(sensitivity_range_fuel_costs(fuel_costs)./Plants(generator,7)))...%costs
            %             + Plants(generator,8)*Plants(generator,1) + sensitivity_range_capital_costs(capital_range)*Plants(generator,1).*DiscountRate;
            %        end
            %    end
            % end
            % 
            % TotalPowerSectorCosts = squeeze(nansum(PowerPlantCosts,1));
            % 
            % 
            % for generator = 1:length(Plants)
            %    for fuel_costs = 1:matrixsize
            %        for capital_range = 1:matrixsize
            %            for CT = 1:matrixsize
            %                 PowerPlantCosts_CT(generator,fuel_costs,capital_range,CT) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*(sensitivity_range_fuel_costs(fuel_costs)./Plants(generator,7))+Plants(generator,4)*(sensitivity_range_CT(CT)))...%costs
            %                 + Plants(generator,8)*Plants(generator,1) + sensitivity_range_capital_costs(capital_range)*Plants(generator,1).*DiscountRate;
            %            end
            %        end
            %    end
            % end

            
            % TotalPowerSectorCosts_CT = squeeze(nansum(PowerPlantCosts_CT,1));
            % PowerSectorStrandedAssets = zeros(matrixsize,matrixsize,matrixsize,matrixsize);%wholesale price of electricity, fuel costs, capital costs, carbon tax
            % 
            % 
            % 
            % for WS = 1:matrixsize
            %     for fuel_costs = 1:matrixsize
            %         for capital = 1:matrixsize
            %             for CT = 1:matrixsize
            %                 PowerSectorStrandedAssets(WS,fuel_costs,capital,CT) = TotalPowerSectorRevenue(WS) - ...
            %                     (TotalPowerSectorCosts(fuel_costs,capital) - TotalPowerSectorCosts_CT(fuel_costs,capital,CT))./(1 + DiscountRate).^1;
            %             end
            %         end
            %     end
            % end

            max_Life = nanmax(LifeLeft);

            % PowerPlantProfits_CarbonTax = zeros(length(PowerPlantProfits),max_Life,4);
            Stranded_Assets_based_on_added_costs = zeros(length(Plants),max_Life,length(CF_range),length(sensitivity_range_CT));
            for generator = 1:length(Plants)%%add in carbon tax portion
                for yr = 1:max_Life
                    for CF = 1:length(CF_range)
                        for tax = 1:length(sensitivity_range_CT)
                            Stranded_Assets_based_on_added_costs(generator,yr,CF,tax) = sensitivity_range_CT(tax)*Plants(generator,1).*CF_range(CF).*AnnualHours.*(Emission_factor(generator))* (Plants(generator,5)/100); 
                        end
                    end
                end
            end

            for generator = 1:length(Plants)%%add in carbon tax portion
                for yr = 1:max_Life
                    for CF = 1:length(CF_range)
                        for tax = 1:length(sensitivity_range_CT)
                            Stranded_Assets_based_on_added_costs(generator,yr,CF,tax) = Stranded_Assets_based_on_added_costs(generator,yr,CF,tax)./((1 + DiscountRate).^yr);
                        end
                    end
                end
            end


            % StrandedAssets = zeros(matrixsize,matrixsize);%profits and costs
            % 
            % StrandedAssets(:,1) = PowerSectorStrandedAssets(:,1);
            % 
            % for i = 1:matrixsize
            %     for MC = 1:MC_values_1
            %         StrandedAssets(:,i) = (StrandedAssets(:,i) + PowerSectorStrandedAssets(:,MC_values_1(MC),MC_values_2(MC),MC_values_3(MC)))/2;%takes the mean of a monte carlo
            %     end
            % end
            
            [CarbonTax, Capacity_Factor] = meshgrid(sensitivity_range_CT, CF_range);
            vals = squeeze(nansum(nansum(Stranded_Assets_based_on_added_costs,1),2))/1e12; % converts to trillions of dollars
            
            contourrange = 0:.05:1000;
            
            figure()
            CF = contourf(Capacity_Factor, CarbonTax, vals, contourrange);
            % clabel(CF); % Add contour labels
            xlabel('Capacity Factor');
            ylabel('Carbon Tax');
            colormap(flip(brewermap(length(contourrange),'Spectral'))); % Ensure correct colormap usage
            c = colorbar;
            clim([0 80])
            c.Label.String = 'Stranded Assets (Trillions of Dollars)'; % Label the colorbar
            hold on;
            whiteContours = contour(Capacity_Factor, CarbonTax, vals, [3, 7, 11, 17, 24, 36, 50, 67, 87], 'LineColor', 'white', 'LineWidth', 1.5); % Example levels
            clabel(whiteContours);

            ax = gca;
            exportgraphics(ax,['../Plots/gas_sensitivity_plot.eps'],'ContentType','vector');


        elseif gentype == 3
% 
%             load('../Data/Results/Oil_Plants');
%             load('../Data/Results/Oil_Plants_strings');
%             load('../Data/Results/OilCostbyCountry')
%             load('../Data/WholeSaleCostofElectricityOil');
%             CarbonTax19 = xlsread('../Data/CarbonTax1_9.xlsx');
%             CarbonTax26 = xlsread('../Data/CarbonTax2_6.xlsx');
%             load '../Data/Results/OilColors'
%             load('../Data/Results/DecommissionYearOil')
%             load('../Data/Results/OM_Costs_Oil.mat');
% 
%             matrixsize = 31;
% 
%             if randomsave == 1
%                 MC_values_1 = randi(matrixsize,10000,1);
%                 MC_values_2 = randi(matrixsize,10000,1);
%                 MC_values_3 = randi(matrixsize,10000,1);
%                 save("MC_values_Oil.mat","MC_values_1","MC_values_2","MC_values_3")
%             elseif randomsave == 0 
%                 load("MC_values_Oil.mat");
%             end
% 
% 
% 
%             FuelCosts = F_Costs;
%             LifeLeft = mean_Life - Plants(:,2);
% 
%             % Plants(Plants==0)=nan;
% 
%             sensitivity_range_fuel_costs = 20:(300-20)/(matrixsize-1):300;
%             sensitivity_range_capital_costs = min(Plants(:,6)):(max(Plants(:,6))-min(Plants(:,6)))/(matrixsize-1):max(Plants(:,6));
%             sensitivity_range_CT = 0:(1000-0)/(matrixsize-1):1000;%$dollars
%             sensitivity_range_WS = 0:(400-0)/(matrixsize-1):400;%min to max with 100 steps $dollars/kwh
%             CF_range = .4:(.9-.4)/(matrixsize-1):.9;
% 
% %             PowerPlantProfits = zeros(length(Plants),length(sensitivity_range_WS));
% %             PowerPlantProfits_CarbonTax = zeros(length(Plants),length(sensitivity_range_CT),length(sensitivity_range_WS));
% 
%             PowerPlantRevenue = zeros(length(Plants),length(sensitivity_range_WS));
%             PowerPlantCosts = zeros(length(Plants),length(sensitivity_range_fuel_costs),length(sensitivity_range_capital_costs));
%             PowerPlantCosts_CT = zeros(length(Plants),length(sensitivity_range_fuel_costs),length(sensitivity_range_capital_costs),length(sensitivity_range_CT));
% 
%             Plants(isnan(Plants))=0;
% 
% 
%             for generator = 1:length(Plants)
%                 for sensitivity_range = 1:matrixsize
%                     PowerPlantRevenue(generator,sensitivity_range) = (Plants(generator,1).*mean_OilCF.*AnnualHours.*sensitivity_range_WS(sensitivity_range));
%                 end
%             end
% 
%             TotalPowerSectorRevenue = squeeze(nansum(PowerPlantRevenue,1));
% 
% 
%             for generator = 1:length(Plants)
%                for fuel_costs = 1:matrixsize
%                    for capital_range = 1:matrixsize
%                         PowerPlantCosts(generator,fuel_costs,capital_range) = (Plants(generator,1).*mean_OilCF.*AnnualHours.*(sensitivity_range_fuel_costs(fuel_costs)./Plants(generator,7)))...%costs
%                         + Plants(generator,8)*Plants(generator,1) + sensitivity_range_capital_costs(capital_range)*Plants(generator,1).*DiscountRate;
%                    end
%                end
%             end
% 
%             TotalPowerSectorCosts = squeeze(nansum(PowerPlantCosts,1));
% 
% 
%             for generator = 1:length(Plants)
%                for fuel_costs = 1:matrixsize
%                    for capital_range = 1:matrixsize
%                        for CT = 1:matrixsize
%                             PowerPlantCosts_CT(generator,fuel_costs,capital_range,CT) = (Plants(generator,1).*mean_OilCF.*AnnualHours.*(sensitivity_range_fuel_costs(fuel_costs)./Plants(generator,7))+Plants(generator,4)*(sensitivity_range_CT(CT)))...%costs
%                             + Plants(generator,8)*Plants(generator,1) + sensitivity_range_capital_costs(capital_range)*Plants(generator,1).*DiscountRate;
%                        end
%                    end
%                end
%             end
% 
% 
%             TotalPowerSectorCosts_CT = squeeze(nansum(PowerPlantCosts_CT,1));
%             PowerSectorStrandedAssets = zeros(matrixsize,matrixsize,matrixsize,matrixsize);%wholesale price of electricity, fuel costs, capital costs, carbon tax
% 
% 
% 
%             for WS = 1:matrixsize
%                 for fuel_costs = 1:matrixsize
%                     for capital = 1:matrixsize
%                         for CT = 1:matrixsize
%                             PowerSectorStrandedAssets(WS,fuel_costs,capital,CT) = TotalPowerSectorRevenue(WS) - ...
%                                 (TotalPowerSectorCosts(fuel_costs,capital) - TotalPowerSectorCosts_CT(fuel_costs,capital,CT))./(1 + DiscountRate).^1;
%                         end
%                     end
%                 end
%             end
% 
%             StrandedAssets = zeros(matrixsize,matrixsize);%profits and costs
% 
%             StrandedAssets(:,1) = PowerSectorStrandedAssets(:,1);
% 
%             MC_values_1 = MC_values_1(1:matrixsize,:);MC_values_2 = MC_values_2(1:matrixsize,:);MC_values_3 = MC_values_3(1:matrixsize,:);
% 
%             for i = 1:matrixsize
%                 for MC = 1:MC_values_1
%                     StrandedAssets(:,i) = (StrandedAssets(:,i) + PowerSectorStrandedAssets(:,MC_values_1(MC),MC_values_2(MC),MC_values_3(MC)))/2;%takes the mean of a monte carlo
%                 end
%             end
% 
%             [CarbonTax,WholeSale] = meshgrid(sensitivity_range_CT,sensitivity_range_WS);
%             vals = squeeze(nanmean(nanmean(PowerSectorStrandedAssets,3),2))/1e12;%converts to trillions of dollars
%             contourrange = 0:.1:nanmax(vals(:));
% 
%             figure()
%             [WS,CT] = contourf(WholeSale,CarbonTax,vals,contourrange);
%             text_handle = clabel(WS,CT); 
%             xlabel('Wholesale Price');
%             ylabel('Carbon Tax');
%             colormap(flip(brewermap([],'Spectral')));
% 
%             ax = gca;
%             exportgraphics(ax,['../Plots/oil_sensitivity_plot.eps'],'ContentType','vector');
% 
% % %             [CarbonTax,WholeSale] = meshgrid(sensitivity_range_CT,sensitivity_range_WS,FuelCosts);
% % %             vals = squeeze(nanmean(PowerSectorStrandedAssets,3))/1e12;%converts to trillions of dollars
% % % 
% % %             figure()
% % %             [WS,CT,FC] = contour3(WholeSale,CarbonTax,vals);
% % %             text_handle = clabel(WS,CT,FC); 
% % %             xlabel('Wholesale Price');
% % %             ylabel('Carbon Tax');
% %             zlabel('Fuel Costs')
% % 
% % 
% % 
% %             [x,y,z,v] = PowerSectorStrandedAssets;
% %             levellist = linspace(-10,2,7);
% %             for i = 1:length(levellist)
% %                 level = levellist(i);
% %                 p = patch(isosurface(x,y,z,v,vals));
% %                 p.FaceVertexCData = level;
% %                 p.FaceColor = 'flat';
% %                 p.EdgeColor = 'none';
% %                 p.FaceAlpha = 0.3;
% %             end
% %             view(3)

%             for generator = 1:length(Plants)%%
%                 for sensitivity_WS = 1:length(sensitivity_range_WS) 
%                     PowerPlantProfits(generator,1) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*sensitivity_range_WS(sensitivity_WS))...%gains
%                     -(Plants(generator,1).*Plants(generator,3).*AnnualHours.*((FuelCosts(1,1))./Plants(generator,7)))...%costs
%                     - Plants(generator,8)*Plants(generator,1) - Plants(generator,6)*Plants(generator,1).*DiscountRate;
%                 end
%             end
%            
% 
%             PowerPlantProfits(PowerPlantProfits<0)  = 0;
% 
% 
%             WholeSaleCosts = zeros(length(WholeSaleCostofElectricity(:,1)),length(sensitivity_range_WS));
%             CarbonTaxCosts = zeros(length(CarbonTax19(1,7)),length(sensitivity_range_CT));
% 
%             for generator = 1:length(Plants)%%add in carbon tax portion
%                 for sensitivity_CT = 1:length(sensitivity_range_CT)
%                     for sensitivity_WS = 1:length(sensitivity_range_WS)
%                         PowerPlantProfits_CarbonTax(generator,sensitivity_CT,sensitivity_WS) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*(sensitivity_range_WS(sensitivity_WS)))...%gains
%                         -(Plants(generator,1).*Plants(generator,3).*AnnualHours.*((FuelCosts(1,1))./Plants(generator,7))+Plants(generator,4)*(sensitivity_range_CT(sensitivity_CT))) ...%costs  
%                         - Plants(generator,8)*Plants(generator,1) - Plants(generator,6)*Plants(generator,1).*DiscountRate;
%                         
%                         WholeSaleCosts(generator,sensitivity_WS) = sensitivity_range_WS(sensitivity_WS);
%                         CarbonTaxCosts(1,sensitivity_CT) = sensitivity_range_CT(sensitivity_CT);
% 
%                     end
%                 end
%             end
% 
%             PowerPlantProfits_CarbonTax(PowerPlantProfits_CarbonTax<0) = 0;
%                                   
% 
%             StrandedAssetValue = zeros(size(PowerPlantProfits_CarbonTax));
%             for generator = 1:length(Plants)
%                 StrandedAssetValue(generator,:,:) = (PowerPlantProfits(generator,1)-PowerPlantProfits_CarbonTax(generator,:,:))./(1 + DiscountRate).^1;
%             end 
%             
%             Average_StrandedAssetValue = squeeze(nansum(StrandedAssetValue,1));
%             WholeSaleCosts = nanmean(WholeSaleCosts,1);
% 
%             [CarbonTax,WholeSale] = meshgrid(CarbonTaxCosts,WholeSaleCosts);
%             vals = Average_StrandedAssetValue/1e12;%converts to trillions of dollars
% 
%             figure()
%             [WS,CT] = contourf(WholeSale,CarbonTax,vals);
%             text_handle = clabel(WS,CT); 
%             xlabel('Wholesale Price');
%             ylabel('Carbon Tax');
% 
%             figure()
%             [CT,WS] = contourf(CarbonTax,WholeSale,vals);
%             text_handle = clabel(CT,WS); 
%             xlabel('Carbon Tax');
%             ylabel('Wholesale Price');



            %example code from section 3, delete after section 11 is
            %completed


%             for generator = 1:length(Plants)%%add in carbon tax portion
%             PowerPlantProfits(generator,1) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,1))...%gains
%             -(Plants(generator,1).*Plants(generator,3).*AnnualHours.*((FuelCosts(1,1))./Plants(generator,7)))...%costs
%             - Plants(generator,8)*Plants(generator,1) - Plants(generator,6)*Plants(generator,1).*DiscountRate;
% 
%             OM_annual_increase(generator) = PowerPlantProfits(generator,1)./(DecommissionYear(generator,1) - current_year);
%             end






%             for generator = 1:length(Plants)%%add in carbon tax portion
%                 for sensitivity_CT = 1:length(sensitivity_range_CT)
%                     for sensitivity_WS = 1:length(sensitivity_range_WS)
%                             PowerPlantProfits_CarbonTax(generator,yr,1) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,1))...%gains
%                             -(Plants(generator,1).*Plants(generator,3).*AnnualHours.*((FuelCosts(1,1))./Plants(generator,7))+Plants(generator,4)*CarbonTax19(1,7)) ...%costs  
%                             - Plants(generator,8)*Plants(generator,1)-OM_annual_increase(generator) - Plants(generator,6)*Plants(generator,1).*DiscountRate;
%                     end
%                 end
%             end
% 
% 
%             for generator = 1:length(Plants)%%add in carbon tax portion
%                 for sensitivity_CT = 1:length(sensitivity_range_CT)
%                     for sensitivity_WS = 1:length(sensitivity_range_WS)
%                         PowerPlantProfits_CarbonTax(generator,sensitivity_CT,sensitivity_WS) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*(sensitivity_range_WS(sensitivity_WS)))...%gains
%                         -(Plants(generator,1).*Plants(generator,3).*AnnualHours.*((FuelCosts(1,1))./Plants(generator,7))+Plants(generator,4)*(sensitivity_range_CT(sensitivity_CT))) ...%costs  
%                         - Plants(generator,8)*Plants(generator,1) - Plants(generator,6)*Plants(generator,1).*DiscountRate;
%                         
%                         WholeSaleCosts(generator,sensitivity_WS) = sensitivity_range_WS(sensitivity_WS);
%                         CarbonTaxCosts(1,sensitivity_CT) = sensitivity_range_CT(sensitivity_CT);
% 
%                     end
%                 end
%             end





%         for generator = 1:length(Plants)
%             for yr = 2:mean_Life
%                 PowerPlantProfits(generator,yr) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,1))...%gains
%             -(Plants(generator,1).*Plants(generator,3).*AnnualHours.*((FuelCosts(1,1))./Plants(generator,7)))...%costs
%             - Plants(generator,8)*Plants(generator,1)-OM_annual_increase(generator)*yr - Plants(generator,6)*Plants(generator,1).*DiscountRate;
%             end
%         end
% 
% 
%         PowerPlantProfits(PowerPlantProfits<0)  = 0;
% 
%         PresentAssetValue = zeros(size(PowerPlantProfits));
%         for generator = 1:length(Plants)
%             for yr = 1:mean_Life
%                PresentAssetValue(generator,yr) =  (PresentAssetValue(generator,yr)./(1 + DiscountRate).^yr);%.*CapacityWeighted(generator);
%             end
%         end 
% 
% 
%         for generator = 1:length(Plants)%%add in carbon tax portion
%             for yr = 1:mean_Life
%                 for tax = 1:length(CarbonPrice)
%                     PowerPlantProfits_CarbonTax(generator,yr,tax) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,yr))...%gains
%                     -(Plants(generator,1).*Plants(generator,3).*AnnualHours.*((FuelCosts(1,yr))./Plants(generator,7))+Plants(generator,4)*CarbonPrice(tax)*((CarbonTaxYear(yr)-current_year)/(2100-current_year)).^2) ...%costs  
%                     - Plants(generator,8)*Plants(generator,1)-OM_annual_increase(generator)*yr - Plants(generator,6)*Plants(generator,1).*DiscountRate;
%                 end
%             end
%         end

            
        end
    end
        

elseif section == 12
    % EmissionsPerStrandedAssets = ((CommittedEmissions)./(StrandedAssetsbyCompany*1e9)); %converts stranded assets back to $ instead of billions of dollar

    load('../Data/Results/EmissionsPerStrandedAssets_coal.mat')
    Emissions_coal = EmissionsbyCompany;
    StrandedAssets_mean = StrandedAssetsbyCompany*1e9;
    EmissionsPerStrandedAssets_coal = ((CommittedEmissions)./(StrandedAssets_mean))*1000;

    load('../Data/Results/EmissionsPerStrandedAssets_coal_max.mat')
    StrandedAssets_max = StrandedAssetsbyCompany*1e9;
    EmissionsPerStrandedAssets_min = ((CommittedEmissions)./(StrandedAssets_max))*1000; %larger denominator results in smaller number 

    load('../Data/Results/EmissionsPerStrandedAssets_coal_min.mat')
    StrandedAssets_min = StrandedAssetsbyCompany*1e9;
    EmissionsPerStrandedAssets_max = ((CommittedEmissions)./(StrandedAssets_min))*1000; %smaller denominator results in larger number 

    error_bars = [EmissionsPerStrandedAssets_coal - EmissionsPerStrandedAssets_min, EmissionsPerStrandedAssets_max - EmissionsPerStrandedAssets_coal];
    
    figure;
    errorbar(CommittedEmissions, EmissionsPerStrandedAssets_coal, error_bars(:,1), error_bars(:,2), 'o', 'Color', [0 0 0]); % Black color for error bars
    hold on;
    scatter(CommittedEmissions, EmissionsPerStrandedAssets_coal, 75, Company_RGB_colors, 'filled');
    xlabel('Committed Emissions (CO2)');
    ylabel('Committed Emissions per ($)');
    ylim([0 20])
    ax = gca;
    exportgraphics(ax,'../Plots/scatter emissions per stranded assets coal.eps','ContentType','vector');
    % [EmissionsPerStrandedAssets_coal_min, indx]= rmoutliers(EmissionsPerStrandedAssets_coal_min);
    % EmissionsPerStrandedAssets_coal_max = rmoutliers(EmissionsPerStrandedAssets_coal_max); 
    % EmissionsbyCompany_coal = rmoutliers(EmissionsbyCompany_coal);
    % Company_RGB_colors(indx, :) = [];

    % EmissionsPerStrandedAssets_coal_average = (EmissionsPerStrandedAssets_coal_min+EmissionsPerStrandedAssets_coal_max)/2;
    % 
    % ds_matrix = [EmissionsPerStrandedAssets_coal_min, EmissionsPerStrandedAssets_coal_max];
    % err = abs(EmissionsPerStrandedAssets_coal_max - EmissionsPerStrandedAssets_coal_min);
    % 
    % ypos=abs(EmissionsPerStrandedAssets_coal_average-EmissionsPerStrandedAssets_coal_max);              % for errorbar +ive
    % yneg=abs(EmissionsPerStrandedAssets_coal_average-EmissionsPerStrandedAssets_coal_min);             % for errorbar -ive
    % 
    % figure;
    % scatter(EmissionsbyCompany_coal, EmissionsPerStrandedAssets_coal_average, 75, Company_RGB_colors, 'filled', 'MarkerFaceAlpha', 0.5);
    % hold on;
    % for i = 1:length(EmissionsbyCompany_coal)
    %     line([EmissionsbyCompany_coal(i), EmissionsbyCompany_coal(i)], [EmissionsPerStrandedAssets_coal_min(i), EmissionsPerStrandedAssets_coal_max(i)], 'Color', 'k', 'LineStyle', '--');
    % end
    % % ylim([0,20])
    % set(gca,'xscale','log')
    % % xlim([12,17])
    % hold off;
    % ax = gca;
    % exportgraphics(ax,'../Plots/scatter emissions per stranded assets coal.eps','ContentType','vector');


    % 
    % 
    % load('../Data/Results/EmissionsPerStrandedAssets_oil.mat')
    % EmissionsbyCompany_oil = EmissionsbyCompany;
    % 
    % load('../Data/Results/EmissionsPerStrandedAssets_max_oil.mat')
    % EmissionsPerStrandedAssets_oil_min = EmissionsPerStrandedAssets; %min and max saved backwards
    % 
    % load('../Data/Results/EmissionsPerStrandedAssets_min_oil.mat')
    % EmissionsPerStrandedAssets_oil_max = EmissionsPerStrandedAssets;
    % 
    % EmissionsPerStrandedAssets_oil_average = (EmissionsPerStrandedAssets_oil_min+EmissionsPerStrandedAssets_oil_max)/2;
    % 
    % figure;
    % scatter(EmissionsbyCompany_oil, EmissionsPerStrandedAssets_oil_average, 75, Company_RGB_colors, 'filled', 'MarkerFaceAlpha', 0.5);
    % hold on;
    % for i = 1:length(EmissionsbyCompany_oil)
    %     line([EmissionsbyCompany_oil(i), EmissionsbyCompany_oil(i)], [EmissionsPerStrandedAssets_oil_min(i), EmissionsPerStrandedAssets_oil_max(i)], 'Color', 'k', 'LineStyle', '--');
    % end
    % ylim([0,110])
    % set(gca,'xscale','log')
    % hold off;
    % ax = gca;
    % exportgraphics(ax,'../Plots/scatter emissions per stranded assets oil.eps','ContentType','vector');
    % 



    % load('../Data/Results/EmissionsPerStrandedAssets_gas.mat')
    % EmissionsbyCompany_gas = EmissionsbyCompany*1000;

    % load('../Data/Results/EmissionsPerStrandedAssets_gas_max.mat')
    % EmissionsPerStrandedAssets_gas_max= EmissionsPerStrandedAssets*1000; %min and max saved backwards
    % 
    % load('../Data/Results/EmissionsPerStrandedAssets_gas_min.mat')
    % EmissionsPerStrandedAssets_gas_min = EmissionsPerStrandedAssets*1000;
    % 
    % EmissionsPerStrandedAssets_gas_average = (EmissionsPerStrandedAssets_gas_min+EmissionsPerStrandedAssets_gas_max)/2;
    % 
    % figure;
    % scatter(EmissionsbyCompany_gas, EmissionsPerStrandedAssets_gas_average, 75, Company_RGB_colors, 'filled', 'MarkerFaceAlpha', 0.5);
    % hold on;
    % for i = 1:length(EmissionsbyCompany_gas)
    %     line([EmissionsbyCompany_gas(i), EmissionsbyCompany_gas(i)], [EmissionsPerStrandedAssets_gas_min(i), EmissionsPerStrandedAssets_gas_max(i)], 'Color', 'k', 'LineStyle', '--');
    % end
    % ylim([0,20])
    % set(gca,'xscale','log')
    % hold off;
    % ax = gca;
    % exportgraphics(ax,'../Plots/scatter emissions per stranded assets gas.eps','ContentType','vector');

    load('../Data/Results/EmissionsPerStrandedAssets_gas.mat')
    Emissions_gas = EmissionsbyCompany;
    StrandedAssets_mean = StrandedAssetsbyCompany*1e9;
    EmissionsPerStrandedAssets_gas = ((CommittedEmissions)./(StrandedAssets_mean))*1000;

    load('../Data/Results/EmissionsPerStrandedAssets_gas_max.mat')
    StrandedAssets_max = StrandedAssetsbyCompany*1e9;
    EmissionsPerStrandedAssets_min = ((CommittedEmissions)./(StrandedAssets_max))*1000; %larger denominator results in smaller number 

    load('../Data/Results/EmissionsPerStrandedAssets_gas_min.mat')
    StrandedAssets_min = StrandedAssetsbyCompany*1e9;
    EmissionsPerStrandedAssets_max = ((CommittedEmissions)./(StrandedAssets_min))*1000; %smaller denominator results in larger number 

    error_bars = [EmissionsPerStrandedAssets_gas - EmissionsPerStrandedAssets_min, EmissionsPerStrandedAssets_max - EmissionsPerStrandedAssets_gas];
    
    figure;
    errorbar(CommittedEmissions, EmissionsPerStrandedAssets_gas, error_bars(:,1), error_bars(:,2), 'o', 'Color', [0 0 0]); % Black color for error bars
    hold on;
    scatter(CommittedEmissions, EmissionsPerStrandedAssets_gas, 75, Company_RGB_colors, 'filled');
    xlabel('Committed Emissions (CO2)');
    ylabel('Committed Emissions per ($)');
    ylim([0 20])
    ax = gca;
    exportgraphics(ax,'../Plots/scatter emissions per stranded assets gas.eps','ContentType','vector');

elseif section == 13 %reduces capacity factor as prices increase 

    for gentype = FUEL
        load(['../Data/Results/' PowerPlantFuel{gentype} '_Plants']);
        load(['../Data/Results/' PowerPlantFuel{gentype} '_Plants_strings']);
        load(['../Data/Results/' PowerPlantFuel{gentype} 'CostbyCountry'])
        load(['../Data/WholeSaleCostofElectricity' PowerPlantFuel{gentype} '']);
        CarbonTax19 = xlsread('../Data/CarbonTax1_9.xlsx','standard');
        CarbonTax26 = xlsread('../Data/CarbonTax2_6.xlsx','standard');
        load(['../Data/Results/' PowerPlantFuel{gentype} 'Colors'])
        if gentype == 1
            colorschemecategoryFuel = colorschemecategoryCoal;
        else
            colorschemecategoryFuel = colorschemecategoryGas;
        end
        Plants(isnan(Plants)) = 0;
        
        clear PowerPlantProfits
        % Plants(isnan(Plants)) = 0;

        PowerPlantRevenue = zeros(length(Plants),1);

        for generator = 1:length(Plants)
            PowerPlantRevenue(generator,1) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,1)*RetailtoWholesaleConversionFactor);
        end
        
        FuelCosts = F_Costs;

        if gentype == 1
            LifeLeft = mean_Life_coal - Plants(:,2);
            mean_Life = mean_Life_coal;
        elseif gentype == 2
            LifeLeft = mean_Life_gas - Plants(:,2);
            mean_Life = mean_Life_gas;
        end

        if saveyear == 1
            for generator = 1:length(Plants)
                if isnan(Planned_decommission(generator))
                    if LifeLeft(generator,1) <=0 
                        yearsleft = randi(5);
                        DecommissionYear(generator,1) = current_year + yearsleft;
                        LifeLeft(generator,1) = yearsleft;
                    elseif LifeLeft(generator,1) > 0
                        DecommissionYear(generator,1) = current_year + LifeLeft(generator,1);
                        LifeLeft(generator,1) = LifeLeft(generator,1);
                    end
                elseif ~isnan(Planned_decommission(generator))
                       LifeLeft(generator,1) = Planned_decommission(generator) - current_year;

                    if LifeLeft(generator,1) <=0 
                        yearsleft = randi(5);
                        DecommissionYear(generator,1) = current_year + yearsleft;
                        LifeLeft(generator,1) = yearsleft;

                    elseif LifeLeft(generator,1) > 0
                        DecommissionYear(generator,1) = current_year + LifeLeft(generator,1);
                        LifeLeft(generator,1) = LifeLeft(generator,1);
                    end
                end
            end
            DecommissionYear(28522:28525) = 0; % not iterating through the final power plants due to nans, these are decomissioned anyways
            save(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''],'DecommissionYear','LifeLeft');
        elseif saveyear ~=1
            load(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''])
        end

        max_Life = nanmax(LifeLeft);

        LifeLeft(isnan(LifeLeft))=0;
        % for generator = 1:length(Plants)%%Nameplate * CF * annual hours 
        %     PowerPlantProfits(generator,1) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,1))...%gains
        %     -(Plants(generator,1).*Plants(generator,3).*AnnualHours.*((FuelCosts(1,1))./Plants(generator,7)))...%costs
        %     - Plants(generator,8)*Plants(generator,1) - Plants(generator,6)*Plants(generator,1).*DiscountRate;
        % 
        %     OM_annual_increase(generator) = PowerPlantProfits(generator,1)./(DecommissionYear(generator,1) - current_year);
        % end

        % for generator = 1:length(Plants)
        %     for yr = 2:40
        %      PowerPlantProfits(generator,yr) = (Plants(generator,1).*Plants(generator,3).*AnnualHours.*WholeSaleCostofElectricity(generator,1))...%gains
        %     -(Plants(generator,1).*Plants(generator,3).*AnnualHours.*((FuelCosts(1,1))./Plants(generator,7)))...%costs
        %     - Plants(generator,8)*Plants(generator,1)-OM_annual_increase(generator)*yr - Plants(generator,6)*Plants(generator,1).*DiscountRate;
        % 
        % 
        %     PowerPlant_StringInformation(generator,1) = Plants_string(generator,1);%corporate owner of the plant
        %     PowerPlant_StringInformation(generator,2) = Plants_string(generator,2);%national location of the plant
        %     PowerPlant_StringInformation(generator,3) = Plants_string(generator,3);%Operating status
        %     end
        % end
        if gentype == 1 
            % for generator = 1:length(Plants)
            %     OM_costs(generator) = Fixed_OM_coal*Plants(generator,1) + (Variable_OM_coal - PowerPlantRevenue(generator,1))*Plants(generator,1).*Plants(generator,3).*AnnualHours;
            % end
            % 
            % for generator = 1:length(Plants)
            %     Cost_of_Fuel(generator) = Fuel_costs_coal*((Plants(generator,1).*Plants(generator,3).*AnnualHours)/eta_coal);
            % 
            % end
            % 
            % for generator = 1:length(Plants)
            %     LCOE(generator) = (alpha_coal*Investment_costs_coal+OM_costs(generator)+Cost_of_Fuel(generator))/(Plants(generator,1).*Plants(generator,3).*AnnualHours);
            % end
            % 
            % LCOE(LCOE == Inf)=nan;


            for generator = 1:length(Plants)
                OM_costs(generator) = Fixed_OM_coal*Plants(generator,1) + Variable_OM_coal*Plants(generator,1).*Plants(generator,3).*AnnualHours;
            end

            for generator = 1:length(Plants)
                Cost_of_Fuel(generator) = Fuel_costs_coal*((Plants(generator,1).*Plants(generator,3).*AnnualHours)/eta_coal);
            end
    
            for generator = 1:length(Plants)
                Costs(generator) = (alpha_coal*Investment_costs_coal+OM_costs(generator)+Cost_of_Fuel(generator));
            end

            Costs = Costs';
            Costs(PowerPlantRevenue==0)=0;

            Costs(Costs == Inf)=nan;
            Costs(Costs == 0)=nan;

        
            for generator = 1:length(Plants)
                PowerPlantProfits(generator,1:LifeLeft(generator,1)) = PowerPlantRevenue(generator) - Costs(generator);
            
                PowerPlant_StringInformation(generator,1) = Plants_string(generator,1);%corporate owner of the plant
                PowerPlant_StringInformation(generator,2) = Plants_string(generator,2);%national location of the plant
                PowerPlant_StringInformation(generator,3) = Plants_string(generator,3);%Operating status
            end

            PowerPlantProfits_CarbonTax = zeros(length(PowerPlantProfits),max_Life,4);
            Stranded_Assets_based_on_added_costs = zeros(size(PowerPlantProfits_CarbonTax));
            for generator = 1:length(Plants)%%add in carbon tax portion
                for tax = 1:4%1 - global carbon tax 1.9, 2 - region specific 1.9, 3 - global carbon tax 2.6, 4 - region specific 2.6
                    for yr = 1:max_Life
                        if tax == 1
                            Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax19(yr+4,7)*(Plants(generator,1).*(Plants(generator,3)-yr).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                        elseif tax == 2
                            Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax19(yr+4,Plants(generator,12)+1)*(Plants(generator,1).*(Plants(generator,3)-yr).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                        elseif tax == 3
                            Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax26(yr+4,7)*(Plants(generator,1).*(Plants(generator,3)-yr).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                        elseif tax == 4
                            Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax26(yr+4,Plants(generator,12)+1)*(Plants(generator,1).*(Plants(generator,3)-yr).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                        end
                    end
                end
            end

            for i = 1:length(Plants)
                for j = 1:max_Life
                    if PowerPlantProfits(i,j) == 0 %ensures power plant profits set to zero if power plant is decommisioned based on operational life
                        Stranded_Assets_based_on_added_costs(i,j,:) = 0;
                    end
                end
            end

        elseif gentype ==2 

            for generator = 1:length(Plants)
                OM_costs(generator) = Fixed_OM_gas*Plants(generator,1) + Variable_OM_gas*Plants(generator,1).*Plants(generator,3).*AnnualHours;
            end

            for generator = 1:length(Plants)
                Cost_of_Fuel(generator) = Fuel_costs_gas*((Plants(generator,1).*Plants(generator,3).*AnnualHours)/eta_gas);
            end
    
            for generator = 1:length(Plants)
                Costs(generator) = (alpha_gas*Investment_costs_gas+OM_costs(generator)+Cost_of_Fuel(generator));
            end

            Costs = Costs';
            Costs(PowerPlantRevenue==0)=0;

            Costs(Costs == Inf)=nan;
            Costs(Costs == 0)=nan;

        
            for generator = 1:length(Plants)
                PowerPlantProfits(generator,1:LifeLeft(generator,1)) = PowerPlantRevenue(generator) - Costs(generator);
            
                PowerPlant_StringInformation(generator,1) = Plants_string(generator,1);%corporate owner of the plant
                PowerPlant_StringInformation(generator,2) = Plants_string(generator,2);%national location of the plant
                PowerPlant_StringInformation(generator,3) = Plants_string(generator,3);%Operating status
            end

            PowerPlantProfits_CarbonTax = zeros(length(PowerPlantProfits),max_Life,4);
            Stranded_Assets_based_on_added_costs = zeros(size(PowerPlantProfits_CarbonTax));
            for generator = 1:length(Plants)%%add in carbon tax portion
                for tax = 1:4%1 - global carbon tax 1.9, 2 - region specific 1.9, 3 - global carbon tax 2.6, 4 - region specific 2.6
                    for yr = 1:max_Life
                        if tax == 1
                            Stranded_Assets_based_on_added_costs(generator,yr,tax) =CarbonTax19(yr+4,7)*Plants(generator,1).*(Plants(generator,3)-yr).*AnnualHours.*(Emission_factor(generator))*(Plants(generator,5)/100) ; % equation based on https://www.gem.wiki/Estimating_carbon_dioxide_emissions_from_gas_plants
                        elseif tax == 2
                            Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax19(yr+4,Plants(generator,12)+1)*Plants(generator,1).*(Plants(generator,3)-yr).*AnnualHours.*(Emission_factor(generator)) *(Plants(generator,5)/100);
                        elseif tax == 3
                            Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax26(yr+4,7)*Plants(generator,1).*(Plants(generator,3)-yr).*AnnualHours.*(Emission_factor(generator)) *(Plants(generator,5)/100); 
                        elseif tax == 4
                            Stranded_Assets_based_on_added_costs(generator,yr,tax) = CarbonTax26(yr+4,Plants(generator,12)+1)*Plants(generator,1).*(Plants(generator,3)-yr).*AnnualHours.*(Emission_factor(generator)) *(Plants(generator,5)/100); 
                        end
                    end
                end
            end

            for i = 1:length(Plants)
                for j = 1:max_Life
                    if PowerPlantProfits(i,j) == 0 %ensures power plant profits set to zero if power plant is decommisioned based on operational life
                        PowerPlantProfits_CarbonTax(i,j,:) = 0;
                        Stranded_Assets_based_on_added_costs(i,j,:) = 0;
                    end
                end
            end


        end
        PowerPlantProfits_CarbonTax(isnan(PowerPlantProfits_CarbonTax)) = 0;
        PowerPlantProfits(isnan(PowerPlantProfits))=0;

    
        % PowerPlantProfits(PowerPlantProfits<0)  = 0; %prevents profits from being negative, instead power plants are shut down at this time


        %calculates the proportion of power plant assets by company based
        %on the percent ownership of that company
        for generators = 1:length(Plants)
            PowerPlantProfits(generator,:) = PowerPlantProfits(generator,:) * (Plants(generator,5)/100);
        end


        Present_Value_Stranded_Assets_based_on_added_costs = zeros(size(PowerPlantProfits_CarbonTax));
        for generator = 1:length(Plants)
            for yr = 1:max_Life
                PresentAssetValue(generator,yr) = PowerPlantProfits(generator,yr)./(1 + DiscountRate).^yr;
            end
        end 
        
        % PowerPlantProfits_CarbonTax(PowerPlantProfits_CarbonTax<0) = 0;

             
        for generator = 1:length(Plants)
            for yr = 1:max_Life
                for i = 1:4
                    PresentAssetValue_Carbontax(generator,yr,i) = PowerPlantProfits_CarbonTax(generator,yr,i)./((1 + DiscountRate).^yr);
                    Present_Value_Stranded_Assets_based_on_added_costs(generator,yr,i) = Stranded_Assets_based_on_added_costs(generator,yr,i)./((1 + DiscountRate).^yr);
                end
            end
        end         

                    
        StrandedAssetValue = zeros(size(PowerPlantProfits_CarbonTax));
        % for generator = 1:length(Plants) % We only care about the difference of these two values. Stranded assets would be equal to the additional unrecoverable costs added to the power infrastrucutre regardless of profits
        %     for yr = 1:max_Life
        %         for i = 1:4
        %             if PowerPlantProfits(generator,yr) > 0 && PowerPlantProfits_CarbonTax(generator,yr,i) >= 0
        %                 StrandedAssetValue(generator,yr,i) = (PowerPlantProfits(generator,yr)-PowerPlantProfits_CarbonTax(generator,yr,i))./(1 + DiscountRate).^yr;
        %             elseif PowerPlantProfits(generator,yr) > 0 && PowerPlantProfits_CarbonTax(generator,yr,i) <= 0
        %                 StrandedAssetValue(generator,yr,i) = (PowerPlantProfits(generator,yr)-PowerPlantProfits_CarbonTax(generator,yr,i))./(1 + DiscountRate).^yr;
        %             elseif PowerPlantProfits(generator,yr) <= 0 && PowerPlantProfits_CarbonTax(generator,yr,i) < 0
        %                 StrandedAssetValue(generator,yr,i) = (abs(PowerPlantProfits_CarbonTax(generator,yr,i))-abs(PowerPlantProfits(generator,yr)))./(1 + DiscountRate).^yr;
        %             end
        %         end
        %     end
        % end 

         for generator = 1:length(Plants) % We only care about the difference of these two values. Stranded assets would be equal to the additional unrecoverable costs added to the power infrastrucutre regardless of profits
            for yr = 1:max_Life
                for i = 1:4
                    StrandedAssetValue(generator,yr,i) = abs(((PowerPlantProfits(generator,yr))-(PowerPlantProfits_CarbonTax(generator,yr,i))))./((1 + DiscountRate).^yr);
                end
            end
        end 
        
        % AnnualStrandedAssets = StrandedAssetValue;
        % StrandedAssetValue = squeeze(nansum(StrandedAssetValue,2));
        AnnualStrandedAssets = Present_Value_Stranded_Assets_based_on_added_costs;
        StrandedAssetValue = squeeze(nansum(Present_Value_Stranded_Assets_based_on_added_costs,2));
        
        
        CorporateOwners = unique(PowerPlant_StringInformation(:,1));
        CountryLocations = unique(PowerPlant_StringInformation(:,2));
        PowerPlantFinances_byCompany = zeros(length(CorporateOwners),max_Life,5);
        RevenuebyCompany = zeros(length(CorporateOwners),1);
        colorschemecategory = nan(length(CorporateOwners),length(colorschemecategoryFuel));
        StrandedAssetValuebyCompany = zeros(length(CorporateOwners),4);
        PresentAssetValuebyCompany = zeros(length(CorporateOwners),1);
        PowerPlantStrandedAssets_byCompany = zeros(length(CorporateOwners),max_Life,4);
        
        for generator = 1:length(PowerPlant_StringInformation)
            for Company = 1:length(CorporateOwners)
                if strcmpi(PowerPlant_StringInformation{generator,1},CorporateOwners{Company,1})
                    for yr = 1:max_Life
                        PowerPlantFinances_byCompany(Company,yr,1) = PowerPlantFinances_byCompany(Company,yr,1) + PowerPlantProfits(generator,yr);
                        PowerPlantFinances_byCompany(Company,yr,2) = PowerPlantFinances_byCompany(Company,yr,2) + PowerPlantProfits_CarbonTax(generator,yr);
                        PowerPlantFinances_byCompany(Company,yr,3) = PowerPlantFinances_byCompany(Company,yr,3) + PresentAssetValue(generator,yr);
                        PowerPlantFinances_byCompany(Company,yr,4) = PowerPlantFinances_byCompany(Company,yr,4) + PresentAssetValue_Carbontax(generator,yr);
                        
                        PowerPlantStrandedAssets_byCompany(Company,yr,:) = PowerPlantStrandedAssets_byCompany(Company,yr,:) + AnnualStrandedAssets(generator,yr,:);
                    end
                    PresentAssetValuebyCompany(Company,:) = PresentAssetValuebyCompany(Company,:) + nansum(PresentAssetValue(generator,:),2);
                    PowerPlantString_ByCompany(Company,:) = PowerPlant_StringInformation(generator,1);
                    RevenuebyCompany(Company,1) = RevenuebyCompany(Company,1) + PowerPlantRevenue(generator);
                    StrandedAssetValuebyCompany(Company,:) = StrandedAssetValuebyCompany(Company,:) + StrandedAssetValue(generator,:);
                    PowerPlantFinances_byCompany(Company,1,5) = PowerPlantFinances_byCompany(Company,1,5) + StrandedAssetValue(generator,2);
                    colorschemecategory(Company,generator) = colorschemecategoryFuel(generator);
                end
            end
        end
        
       TotalPowerPlantCapacitybyCompany = zeros(length(CorporateOwners),1);
       PowerPlantLife_byCompany = zeros(length(CorporateOwners),max_Life);
       
       Capacity = Plants(:,1);
        
        for generator = 1:length(Plants)
            for yr = 1:max_Life 
                PlantAge(generator,yr) =  Plants(generator,2)+yr;
            end
        end
        
        PlantAge(isnan(PlantAge)) = 0;
        
        for Company = 1:length(CorporateOwners)
            for generator = 1:length(PowerPlant_StringInformation)
                if strcmpi(PowerPlant_StringInformation{generator,1},CorporateOwners{Company,1})
                    TotalPowerPlantCapacitybyCompany(Company,1) = TotalPowerPlantCapacitybyCompany(Company,1) + Capacity(generator,1)* (Plants(generator,5)/100);
                end
            end
        end
        
        for Company = 1:length(CorporateOwners)
            for generator = 1:length(PowerPlant_StringInformation)
                if strcmpi(PowerPlant_StringInformation{generator,1},CorporateOwners{Company,1})
                    PowerPlantLife_byCompany(Company,:) = PowerPlantLife_byCompany(Company,:) + PlantAge(generator,:).*(Capacity(generator,1)./TotalPowerPlantCapacitybyCompany(Company))*(Plants(generator,5)/100);%plant age weighted by capacity and percent ownership
                end
            end
        end
        
        PowerPlantLife_byCompany = round(PowerPlantLife_byCompany);
        PowerPlantFinances_byCountry = zeros(length(CountryLocations),max_Life,5);
        RevenuebyCountry = zeros(length(CountryLocations),1);
        PowerPlantStrandedAssets_byCountry = zeros(length(CountryLocations),max_Life,4);
        
        for generator = 1:length(PowerPlant_StringInformation)
            for country = 1:length(CountryLocations)
                if strcmpi(PowerPlant_StringInformation{generator,2},CountryLocations{country,1})
                    for yr = 1:max_Life
                        PowerPlantFinances_byCountry(country,yr,1) = PowerPlantFinances_byCountry(country,yr,1) + PowerPlantProfits(generator,yr);
                        PowerPlantFinances_byCountry(country,yr,2) = PowerPlantFinances_byCountry(country,yr,2) + PowerPlantProfits_CarbonTax(generator,yr);
                        PowerPlantFinances_byCountry(country,yr,3) = PowerPlantFinances_byCountry(country,yr,3) + PresentAssetValue(generator,yr);
                        PowerPlantFinances_byCountry(country,yr,4) = PowerPlantFinances_byCountry(country,yr,4) + PresentAssetValue_Carbontax(generator,yr);
                        
                        PowerPlantString_ByCountry(country,:) = PowerPlant_StringInformation(generator,2);
                        PowerPlantStrandedAssets_byCountry(country,yr,:) = PowerPlantStrandedAssets_byCountry(country,yr,:)+AnnualStrandedAssets(generator,yr,:);
                    end
                    RevenuebyCountry(country,1) = RevenuebyCountry(country,1) + PowerPlantRevenue(generator);
                    PowerPlantFinances_byCountry(country,1,5) = PowerPlantFinances_byCountry(country,1,5) + StrandedAssetValue(generator,2);
                end
            end
        end
        
        colorschemecategory  = mode(colorschemecategory,2);
        colorschemecategory(colorschemecategory == 0) = 8;
        save(['../Data/Results/colorschemecategory' PowerPlantFuel{gentype} '2'],'colorschemecategory');

        if saveresults == 1
            save(['../Data/Results/PowerPlantFinances_byCompany_' PowerPlantFuel{gentype} '_capacity_factor_reduction'],'Present_Value_Stranded_Assets_based_on_added_costs');
        end
    end

elseif section == 14
    for gentype = FUEL
    
    load(['../Data/Results/PowerPlantFinances_byCompany_' PowerPlantFuel{gentype} '_capacity_factor_reduction'])
    Reduced_capacity = Present_Value_Stranded_Assets_based_on_added_costs;
    load(['../Data/Results/PowerPlantFinances_byCompany_' PowerPlantFuel{gentype} ''])

    Stranded_Asset_difference = Present_Value_Stranded_Assets_based_on_added_costs-Reduced_capacity;
   
    
    end

elseif section == 15

    regions = { 'USA', 'Europe','China', 'India'};
    colors = {[0 0 1], [1 1 0], [1 0 0], [1 0.5 0]};

    figure()
    for i = 1:length(regions)
        Country = xlsread('../Data/capacity_age_by_country.xlsx',regions{i});
        Country(Country == 0) = 1;
        Country(Country == 2024) = 1;
        scatter(Country(:,2),Country(:,1), [], colors{i}, 'filled');
        hold on
    end
    ax = gca;
    exportgraphics(ax,'../Plots/scatter capacity and lifetime coal.eps','ContentType','vector');
    

    hold off
    figure()
    for i = 1:length(regions)
        Country = xlsread('../Data/capacity_age_by_country_gas.xlsx',regions{i});
        Country(Country <= 0) = 1;
        Country(Country == 2024) = 1;

        scatter(Country(:,2),Country(:,1), [], colors{i}, 'filled');
        hold on
    end
    ax = gca;
    exportgraphics(ax,'../Plots/scatter capacity and lifetime gas.eps','ContentType','vector');
    
end%section

end
