* Version: 1.1
* Runs on: Stata/MP 18.0

* Economic Risk Assessment
	* Created: 15/05/2023
	* Last modified: 29/05/2024
	
* Summary: This do-file generates the outputs to be included in the "Economic Risk Assessment" section of the paper.

********************************************************************************
* PART 0: TABLE OF CONTENTS
********************************************************************************

*	1) SETUP

*	2) SHOCK CALIBRATION

*	3) DOMESTIC SCENARIO CALCULATION

*	4) EXPOSURE ANALYSIS

*	5) FOREIGN TRANSITION RISK

*	6) EXIOBASE TO NACE CONVERSION

********************************************************************************
* PART 1: SETUP
********************************************************************************

/*
if c(username) == "gulersoy_g" {
	global path = "V:\BIODIVERSITY_HUN\sources"
	global rawdata = "V:\BIODIVERSITY_HUN\sources\0_rawdata"
	global processed = "V:\BIODIVERSITY_HUN\results\3_processeddata"
	global output = "V:\BIODIVERSITY_HUN\results\4_output"
}
*/

clear
cd "$path"
set type double

********************************************************************************
* PART 2: SHOCK CALIBRATION
********************************************************************************

* 2.1) Import the "impacts" data of Exiobase

	import delimited using "$rawdata\Exiobase\IOT_2022_ixi\impacts\F.txt", clear
	
	* Keep water consumption variables
		keep if substr(v1,1,17) == "Water Consumption" | _n < 4
	
	* Keep Hungarian sectors and destring the values
		foreach var of varlist v2 - v7988 {
			if `var'[1]!="HU" {
				drop `var' 
			}
		}
		keep if _n > 3
		rename v1 w
		destring v*, replace
	
	* Rename variables to correspond with the industry numbers
		local name = 1
		foreach var of varlist v2121 - v2283 {
			rename `var' v`name'
			local name = `name' + 1
		}
		
	* Drop total blue water consumption and generate total water consumption
		drop if w == "Water Consumption Blue - Total"
		drop w
		xpose, clear
		egen total_water = rowtotal(*)
		gen n = _n
		tempfile water
		save `water', replace
		
	* Get the output amount	
		use "$processed\Exiobase\X_2022.dta", clear
		keep if substr(v1,1,2) == "HU"
		rename sector exio_ind
		recast str200 exio_ind
		replace n = _n
		rename v1 ind
		merge 1:1 n using `water', force
		rename v? w?
		rename ind v1
	
	* Merge in the -water- materiality ratings
		rename n number
		merge 1:1 number using "$processed/Exiobase/exiobase_impacts_dependencies/exiobase_dependencies", keepusing(d_climate d_groundwater d_surfacewater d_waterflow) nogen
	
	* Generate variables of interest
	
		* Water consumption as share of output
			gen w_o = total_water / indout
	
		* Generate -weighted- average water materiality
			gen wat_mat = ((d_climate)+(d_waterflow)+(d_groundwater*2)+(d_surfacewater*2))/6
			gen vh_mat = wat_mat > 8
			gen h_mat = wat_mat > 6 & wat_mat <= 8
	
	* Generate the various shock vectors
	
		* Shock 1) All industries together. Share of output. Excluding N-fertilizer. 1-60 range. Extra shock to H and VH = (50% - 100%) for 1 month.
			preserve
			gen s_shock_1 = .
			replace w_o = . if v1 == "HU_61"
			sum w_o
			* Initial shock
			replace s_shock_1 = (w_o-r(min))/(r(max)-r(min)) * (60-1) + 1
			replace s_shock_1 = 0 if total_water == 0 | s_shock_1 == .
			* "Shutdown point" shock
			replace s_shock_1 = s_shock_1 + ((1/12)*0.5)*100 if h_mat == 1
			replace s_shock_1 = s_shock_1 + ((1/12)*1)*100 if vh_mat == 1
			keep n v1 s_shock_1
			label var s_shock_1 "All industries together. Share of output. Excluding N-fertilizer. 1-60 range. Extra shock to H and VH = (50% - 100%) for 1 month."
			tempfile shock_1
			save `shock_1', replace
			restore
	
		* Shock 2) All industries together. Share of output. Excluding N-fertilizer. 1-60 range. Extra shock to H and VH = (50% - 100%) for 2 months.
			preserve
			gen s_shock_2 = .
			replace w_o = . if v1 == "HU_61"
			sum w_o
			* Initial shock
			replace s_shock_2 = (w_o-r(min))/(r(max)-r(min)) * (60-1) + 1
			replace s_shock_2 = 0 if total_water == 0 | s_shock_2 == .
			* "Shutdown point" shock
			replace s_shock_2 = s_shock_2 + ((2/12)*0.5)*100 if h_mat == 1
			replace s_shock_2 = s_shock_2 + ((2/12)*1)*100 if vh_mat == 1
			keep n v1 s_shock_2
			label var s_shock_2 "All industries together. Share of output. Excluding N-fertilizer. 1-60 range. Extra shock to H and VH = (50% - 100%) for 2 months."
			tempfile shock_2
			save `shock_2', replace
			restore
			
		* Shock 3) All industries together. Share of output. Excluding N-fertilizer. 1-60 range. Extra shock to H and VH = (50% - 100%) for 4 months.
			preserve
			gen s_shock_3 = .
			replace w_o = . if v1 == "HU_61"
			sum w_o
			* Initial shock
			replace s_shock_3 = (w_o-r(min))/(r(max)-r(min)) * (60-1) + 1
			replace s_shock_3 = 0 if total_water == 0 | s_shock_3 == .
			* "Shutdown point" shock
			replace s_shock_3 = s_shock_3 + ((4/12)*0.5)*100 if h_mat == 1
			replace s_shock_3 = s_shock_3 + ((4/12)*1)*100 if vh_mat == 1
			keep n v1 s_shock_3
			label var s_shock_3 "All industries together. Share of output. Excluding N-fertilizer. 1-60 range. Extra shock to H and VH = (50% - 100%) for 4 months."
			tempfile shock_3
			save `shock_3', replace
			restore	
		
		* Merge
			merge 1:1 n v1 using `shock_1', nogen
			merge 1:1 n v1 using `shock_2', nogen
			merge 1:1 n v1 using `shock_3', nogen

		* Export
			save "$output\Economic_risk_assessment\drought_shock_vector", replace
			export excel using "$output\Economic_risk_assessment\drought_shock_vector", firstrow(variab) replace
			
********************************************************************************
* PART 3: DOMESTIC SCENARIO CALCULATION
********************************************************************************

* 3.1) Import the Leontief
		use "$processed\Exiobase\L_2022.dta", clear
		* Generate sorting number
		gen sortn = _n
	
	* Merge in the shock vector
		merge 1:1 v1 using "$output\Economic_risk_assessment\drought_shock_vector", keepusing(indout s_shock_1 s_shock_2 s_shock_3) nogen
		foreach var of varlist s_shock_1 s_shock_2 s_shock_3 {
			replace `var' = `var' * indout / 100
			replace `var' = 0 if `var' == .
		}
		sort sortn
		
	* Define Loecd and LIoecd matrices.
		mkmat AT_1 - WM_163, matrix(Loecd)
		mat LIoecd = Loecd - I(_N)
		
* 3.2) Backwards impacts (Upstream)
		* For each scenario: Calculate total and upstream output reduction: Matrix multiplication of the Leontief inverse with the shock vector.
		foreach level in 1 2 3 {
			mkmat s_shock_`level', matrix(s_`level')
			mat dom_tot_`level' = Loecd*s_`level' /* DROP THESE */
			mat dom_ind_`level' = LIoecd*s_`level'
		}
		keep sortn v1 v2 s_shock_1 s_shock_2 s_shock_3
		order sortn v1 v2 s_shock_1 s_shock_2 s_shock_3
		foreach newmat in dom_tot_1 dom_ind_1 dom_tot_2 dom_ind_2 dom_tot_3 dom_ind_3 {
			svmat `newmat'
		}
		rename (dom_tot_11 dom_ind_11 dom_tot_21 dom_ind_21 dom_tot_31 dom_ind_31) (dom_tot_1 dom_ind_1 dom_tot_2 dom_ind_2 dom_tot_3 dom_ind_3)
		order v1 v2 s_shock_1 dom_ind_1 dom_tot_1 s_shock_2 dom_ind_2 dom_tot_2 s_shock_3 dom_ind_3 dom_tot_3
		* Save as tempfile
		tempfile dom_scen
		save `dom_scen', replace
		
* 3.3) Import the Ghosh	and merge in the VA
		use "$processed\Exiobase\F_2022", clear
		keep if v1 == "Value Added"
		drop v1
		xpose, clear
		gen sortn = _n
		rename v1 va
		tempfile va
		save `va', replace
		use "$processed\Exiobase\G_2022.dta", clear
		gen sortn = _n
		merge 1:1 sortn using `va', nogen
		merge 1:1 v1 using "$output\Economic_risk_assessment\drought_shock_vector", keepusing(indout s_shock_1 s_shock_2 s_shock_3) nogen
		sort sortn
	
	* Define Goecd and GIoecd matrices.
		mkmat AT_1 - WM_163, matrix(Goecd)
		mat GIoecd = Goecd - I(_N)	

* 3.4) Forward impacts (Downstream)
	foreach level in 1 2 3 {
		gen f_shock_`level' = (s_shock_`level'*va/100)
		replace f_shock_`level' = 0 if f_shock_`level' == .
		mkmat f_shock_`level', matrix(f_`level')
		mat for_ind_`level' = GIoecd'*f_`level'
	}
	keep v1 v2
	foreach newmat in for_ind_1 for_ind_2 for_ind_3 {
		svmat `newmat'
	}
	rename (for_ind_11 for_ind_21 for_ind_31) (for_ind_1 for_ind_2 for_ind_3)
	* Save as tempfile
	tempfile for_scen
	save `for_scen', replace
	* Merge with the upstream file
	use `dom_scen', clear
	merge 1:1 v1 using `for_scen', nogen
	order v1 v2 s_shock_1 dom_ind_1 for_ind_1 dom_tot_1 s_shock_2 dom_ind_2 for_ind_2 dom_tot_2 s_shock_3 dom_ind_3 for_ind_3 dom_tot_3
	
* 3.5) Recalculate the total impacts and merge in total output
	foreach level in 1 2 3 {
		replace dom_tot_`level' = s_shock_`level' + dom_ind_`level' + for_ind_`level'
	}
	preserve
	use "$processed\Exiobase\X_2022.dta", clear
	rename n sortn
	tempfile output
	save `output', replace
	restore
	merge 1:1 sortn using `output', keepusing(indout) nogen
	save `dom_scen', replace
	
* 3.6) Estimating impacts in GDP values
	use "$processed\Exiobase\F_2022", clear
	keep if v1 == "Value Added"
	drop v1
	xpose, clear
	gen sortn = _n
	rename v1 va
	tempfile va
	save `va', replace
	use `dom_scen', clear
	merge 1:1 sortn using `va', keepusing(va) nogen
	sort sortn
	
	* Discover the ratio of VA per unit of output
	gen va_x = va / indout
	foreach level in 1 2 3 {
		gen gdp_red_`level' = dom_tot_`level' * va_x
	}
	drop va_x
	* Order
	order v1 v2 s_shock_1 dom_ind_1 for_ind_1 dom_tot_1 gdp_red_1 s_shock_2 dom_ind_2 for_ind_2 dom_tot_2 gdp_red_2 s_shock_3 dom_ind_3 for_ind_3 dom_tot_3 gdp_red_3
	save `dom_scen', replace

* 3.7) Changes to trade and foreign exchange generation

	* Calculate the value of exports per unit of output
		use "$processed\Exiobase\Z_2022", clear
		gen sortn = _n
		merge 1:1 v1 using "$processed\Exiobase\Y_2022", nogen
		merge 1:1 v1 using "$processed\Exiobase\X_2022.dta", keepusing(indout) nogen
		sort sortn
		egen exports = rowtotal(AT_1-HR_163 IE_1-WM_163 AT_fcebh-HR_exp IE_fcebh-WM_exp) if substr(v1,1,2) == "HU"
		gen exp_indout = exports / indout
		
	* Calculate the value of imports per unit of output
		levelsof v1 if substr(v1,1,2) == "HU", local(levels)
		gen imports = .
		foreach ind in `levels' {
			sum `ind' if substr(v1,1,2) != "HU"
			replace imports = r(sum) if v1 == "`ind'"
		}
		gen imp_indout = imports / indout
		
	* Keep Hungary
		keep if substr(v1,1,2) == "HU"
		
	* Subtract import coef from export coef
		gen fx = exp_indout - imp_indout
		
	* Save as tempfile and merge
		keep v1 fx exports imports
		tempfile fx
		save `fx', replace
		
	* Foreach scenario
		use `dom_scen', clear
		merge 1:1 v1 using `fx', nogen
		sort sortn
		foreach level in 1 2 3 {
			gen fx_red_`level' = (dom_tot_`level' * fx)
		}
		drop fx
		
	* Save as tempfile and merge
		save `dom_scen', replace
			
* 3.8) Separating Hungarian trade with EU and ROTW.

	* 3.8.1) EU
		* Calculate the value of exports per unit of output
			use "$processed\Exiobase\Z_2022", clear
			gen sortn = _n
			merge 1:1 v1 using "$processed\Exiobase\Y_2022", nogen
			merge 1:1 v1 using "$processed\Exiobase\X_2022.dta", keepusing(indout) nogen
			sort sortn
			egen exports = rowtotal(AT_1-HR_163 IE_1-SK_163 AT_fcebh-HR_exp IE_fcebh-SK_exp) if substr(v1,1,2) == "HU"
			gen exp_indout = exports / indout
			
		* Calculate the value of imports per unit of output
			levelsof v1 if substr(v1,1,2) == "HU", local(levels)
			gen imports = .
			foreach ind in `levels' {
				sum `ind' if (substr(v1,1,2) != "HU") & (_n <= 4401 )
				replace imports = r(sum) if v1 == "`ind'"
			}
			gen imp_indout = imports / indout	

		* Keep Hungary
			keep if substr(v1,1,2) == "HU"
			
		* Subtract import coef from export coef
			gen fx = exp_indout - imp_indout
			
		* Save as tempfile and merge
			keep v1 fx
			tempfile fx
			save `fx', replace
			
		* Foreach scenario
			use `dom_scen', clear
			merge 1:1 v1 using `fx', nogen
			foreach level in 1 2 3 {
				gen fx_red_eu_`level' = dom_tot_`level' * fx
			}
			drop fx
			
		* Save as tempfile and merge
			save `dom_scen', replace
	
	* 3.8.2) ROTW
		* Calculate the value of exports per unit of output
			use "$processed\Exiobase\Z_2022", clear
			gen sortn = _n
			merge 1:1 v1 using "$processed\Exiobase\Y_2022", nogen
			merge 1:1 v1 using "$processed\Exiobase\X_2022.dta", keepusing(indout) nogen
			sort sortn
			egen exports = rowtotal(GB_1-WM_163 GB_fcebh-WM_exp) if substr(v1,1,2) == "HU"
			gen exp_indout = exports / indout
			
		* Calculate the value of imports per unit of output
			levelsof v1 if substr(v1,1,2) == "HU", local(levels)
			gen imports = .
			foreach ind in `levels' {
				sum `ind' if _n > 4401
				replace imports = r(sum) if v1 == "`ind'"
			}
			gen imp_indout = imports / indout	

		* Keep Hungary
			keep if substr(v1,1,2) == "HU"
			
		* Subtract import coef from export coef
			gen fx = exp_indout - imp_indout
			
		* Save as tempfile and merge
			keep v1 fx
			tempfile fx
			save `fx', replace
			
		* Foreach scenario
			use `dom_scen', clear
			merge 1:1 v1 using `fx', nogen
			foreach level in 1 2 3 {
				gen fx_red_noneu_`level' = dom_tot_`level' * fx
			}
			drop fx
			
		* Save as tempfile and merge
			save `dom_scen', replace		
	
* 3.9) Price model
		use "$processed\Exiobase\F_2022", clear
		keep if v1 == "Value Added"
		drop v1
		xpose, clear
		gen sortn = _n
		rename v1 va
		tempfile va
		save `va', replace
		use "$processed\Exiobase\G_2022.dta", clear
		gen sortn = _n
		merge 1:1 sortn using `va', nogen
		merge 1:1 v1 using "$output\Economic_risk_assessment\drought_shock_vector", keepusing(indout s_shock_1 s_shock_2 s_shock_3) nogen
		sort sortn
		foreach level in 1 2 3 {
			gen f_shock_`level' = (s_shock_`level'*va/100)
			replace f_shock_`level' = 0 if f_shock_`level' == .
		}
		tempfile price_model
		save `price_model', replace
		
	* Import and merge
		use "$processed\Exiobase\L_2022", clear
		gen sortn = _n
		merge 1:1 v1 using "$processed\Exiobase\diagXinv_2022", nogen
		merge 1:1 sortn using `price_model', keepusing(f_shock_1 f_shock_2 f_shock_3) nogen
		mkmat AT_1-WM_163, mat(L)
		mkmat diagXinv1-diagXinv7987, mat(diagXinv)
		
	* Loop
		foreach level in 1 2 3 {
			preserve
			mkmat f_shock_`level', mat(valow)
			mat valow = valow'*diagXinv
			mat pricelow = Loecd'*valow'
			keep v1 v2
			svmat pricelow
			rename pricelow p_shock_`level'
			tempfile p_shock_`level'
			save `p_shock_`level'', replace
			restore
		}
		
		* Foreach scenario
			use `dom_scen', clear
			foreach level in 1 2 3 {
				merge 1:1 v1 using `p_shock_`level'', nogen
			}
			sort sortn
			
		* Save as tempfile and merge
			save `dom_scen', replace
			
* 3.10) Cleaning, renaming, ordering, labeling
		keep if substr(v1,1,2) == "HU"
		order v1 v2 sortn indout va imports exports
		rename dom_ind_? up_ind_?
		rename for_ind_? down_ind_?
		rename dom_tot_? t_shock_?
		foreach level in 3 2 1 {
			order s_shock_`level' up_ind_`level' down_ind_`level' t_shock_`level' gdp_red_`level' fx_red_`level' fx_red_eu_`level' fx_red_noneu_`level' p_shock_`level', a(exports)
		}
		foreach var of varlist s_shock_? {
			label var `var' "Direct impacts (M.EUR)"
		}
		foreach var of varlist up_ind_? {
			label var `var' "Upstream indirect impacts (M.EUR)"
		}
		foreach var of varlist down_ind_? {
			label var `var' "Downstream indirect impacts (M.EUR)"
		}
		foreach var of varlist t_shock_? {
			label var `var' "Total impacts (M.EUR)"
		}
		foreach var of varlist gdp_red_? {
			label var `var' "GDP reduction (M.EUR)"
		}
		foreach var of varlist fx_red_? {
			label var `var' "Foreign exchange reduction (M.EUR)"
		}
		foreach var of varlist fx_red_eu_? {
			label var `var' "Foreign exchange reduction from EU trade (M.EUR)"
		}
		foreach var of varlist fx_red_noneu_? {
			label var `var' "Foreign exchange reduction from non-EU trade (M.EUR)"
		}
		foreach var of varlist p_shock_? {
			replace `var' = `var' * 100
			label var `var' "Price increase (%)"
		}
		foreach var of varlist *_1 {
			local lbl : variable label `var'
			local newlab = "`lbl'" + " - Low"
			label var `var' "`newlab'"
		}
		foreach var of varlist *_2 {
			local lbl : variable label `var'
			local newlab = "`lbl'" + " - Medium"
			label var `var' "`newlab'"
		}
		foreach var of varlist *_3 {
			local lbl : variable label `var'
			local newlab = "`lbl'" + " - High"
			label var `var' "`newlab'"
		}
		label var v1 "Sector code"
		label var v2 "Sector name"
		label var sortn "Sector number"
		label var indout "Total output"
		label var va "Value added"
		label var imports "Imports"
		label var exports "Exports"
		
		* Save and export
			save `dom_scen', replace
			save "$output\Economic_risk_assessment\Domestic_scenario_results_Exiobase", replace
			export excel "$output\Economic_risk_assessment\Domestic_scenario_results_Exiobase", firstrow(varl) replace
			
********************************************************************************
* PART 4: EXPOSURE ANALYSIS
********************************************************************************
			
* 4.1) Imports exposure to impacts & dependencies
		use "$processed\Exiobase\Z_2022", clear
		gen sortn = _n
		merge 1:1 v1 using "$processed\Exiobase\Y_2022", nogen
		sort sortn
		keep v1 v2 HU_*
		drop if substr(v1,1,2) == "HU"
		egen imports = rowtotal(HU_*)
		egen imports_ii = rowtotal(HU_1-HU_163)
		egen imports_fd = rowtotal(HU_fcebh-HU_exp)
		collapse (sum) imports imports_ii imports_fd, by(v2)
		* Merge in the materiality ratings
		rename v2 exio_ind
		gen strlen = strlen(exio_ind)
		sum strlen
		local newlen = r(max)
		recast str`newlen' exio_ind
		drop strlen
		merge 1:1 exio_ind using "$processed\Exiobase\exiobase_impacts_dependencies\exiobase_impacts.dta", nogen
		merge 1:1 exio_ind using "$processed\Exiobase\exiobase_impacts_dependencies\exiobase_dependencies.dta", nogen
		* Replace the materiality ratings with the dummies
		foreach var of varlist i_* d_* {
				replace `var' = `var' > 6
		}
		* Replace the materiality dummies with the import amounts
		foreach var of varlist i_* d_* {
				replace `var' = `var' * imports_ii
		}
		* Collapse sum at the country level
		collapse (sum) imports - d_waterquality
		* Calculate the percentages
		foreach var of varlist i_* d_* {
				replace `var' = `var' / imports
		}
		tempfile imports
		save `imports', replace		
		
* 4.2) Exports exposure to impacts & dependencies
		use "$processed\Exiobase\Z_2022", clear
		drop HU_*
		keep if substr(v1,1,2) == "HU"
		collapse (sum) AT_1 - WM_163
		xpose, clear varn
		gen number = substr(_varname,4,.)
		drop _varname
		collapse (sum) v1, by(number)
		destring number, replace
		sort number
		rename v1 exports
		merge 1:1 number using "$processed\Exiobase\exiobase_impacts_dependencies\exiobase_impacts.dta", nogen
		merge 1:1 number using "$processed\Exiobase\exiobase_impacts_dependencies\exiobase_dependencies.dta", nogen
		* Replace the materiality ratings with the dummies
		foreach var of varlist i_* d_* {
				replace `var' = `var' > 6
		}
		* Replace the materiality dummies with the import amounts
		foreach var of varlist i_* d_* {
				replace `var' = `var' * exports
		}
		* Collapse sum at the country level
		order number exio_ind
		collapse (sum) exports - d_waterquality
		* Merge in total exports (as in merge in exports to FD as well)
		gen i = 1
		drop exports
		preserve
		use "$processed\Exiobase\Z_2022", clear
		gen sortn = _n
		merge 1:1 v1 using "$processed\Exiobase\Y_2022", nogen
		sort sortn
		keep if substr(v1,1,2) == "HU"
		egen exports = rowtotal(AT_1-HR_163 IE_1-WM_163 AT_fcebh-HR_exp IE_fcebh-WM_exp)
		egen exports_ii = rowtotal(AT_1-HR_163 IE_1-WM_163)
		egen exports_fd = rowtotal(AT_fcebh-HR_exp IE_fcebh-WM_exp)
		collapse (sum) exports exports_ii exports_fd
		order exports exports_ii exports_fd
		gen i = 1
		tempfile exp_sum_stat
		save `exp_sum_stat', replace
		restore
		merge 1:1 i using `exp_sum_stat', nogen
		drop i
		* Calculate the percentages
		foreach var of varlist i_* d_* {
				replace `var' = `var' / exports
		}
		tempfile exports
		save `exports', replace
		
		* Append
		append using `imports'
	
		* Save and export
		save `for_exp', replace
		save "$output\Economic_risk_assessment\Foreign_exposure_results_Exiobase", replace
		export excel "$output\Economic_risk_assessment\Foreign_exposure_results_Exiobase", firstrow(vari) replace
			
* 4.3) Main trading partners
	* Imports
		use "$processed\Exiobase\Z_2022", clear
		gen sortn = _n
		merge 1:1 v1 using "$processed\Exiobase\Y_2022", nogen
		sort sortn
		keep v1 v2 HU_*
		drop if substr(v1,1,2) == "HU"
		egen imports = rowtotal(HU_*)
		egen imports_ii = rowtotal(HU_1-HU_163)
		egen imports_fd = rowtotal(HU_fcebh-HU_exp)
		* Generate country variable
		gen country = substr(v1,1,2)
		collapse (sum) imports imports_ii imports_fd, by(country)
		* Generate total imports
		foreach var of varlist imports imports_ii imports_fd {
			egen `var'_tot = sum(`var')
		}
		gsort - imports
		tempfile import_partners
		save `import_partners', replace
	* Exports
		use "$processed\Exiobase\Z_2022", clear
		gen sortn = _n
		merge 1:1 v1 using "$processed\Exiobase\Y_2022", nogen
		sort sortn
		drop sortn
		keep if substr(v1,1,2) == "HU"
		drop HU_*
		collapse (sum) AT_1 - WM_exp
		xpose, clear varn
		gen country = substr(_varname,1,2)
		rename v1 exports
		gen exports_ii = real(substr(_varname,4,.))!=.
		gen exports_fd = real(substr(_varname,4,.))==.
		foreach var of varlist exports_ii exports_fd {
			replace `var' = `var' * exports
		}
		drop _varname
		order country
		collapse (sum) exports exports_ii exports_fd, by(country)
		gsort - exports
		tempfile export_partners
		save `export_partners', replace
		merge 1:1 country using `import_partners', nogen
	* Save and export
		save "$output\Economic_risk_assessment\Trade_partners_Exiobase", replace
		export excel "$output\Economic_risk_assessment\Trade_partners_Exiobase", firstrow(vari) replace

********************************************************************************
* PART 5: FOREIGN TRANSITION RISK
********************************************************************************
	
		* Import the Z matrix
		use "$processed\Exiobase\Z_2022", clear
		gen sortn = _n
		* Keep Hungary
		keep if substr(v1,1,2) == "HU"
		drop HU_*
		* Merge in the impact ratings
		rename v2 exio_ind
		gen strlen = strlen(exio_ind)
		sum strlen
		local newlen = r(max)
		recast str`newlen' exio_ind
		drop strlen
		merge m:1 exio_ind using "$processed\Exiobase\exiobase_impacts_dependencies\exiobase_impacts.dta", nogen
		sort sortn
		* Replace the materiality ratings with the dummies
		foreach var of varlist i_* {
				replace `var' = `var' > 6
		}
		* Replace the materiality dummies with the export amounts
		tostring number, replace
		order number
		foreach impact of varlist i_* {
			preserve
			levelsof number, local(levels)
			foreach ind in `levels' {
				sum `impact' if number == "`ind'"
				foreach var of varlist *_`ind' {
					replace `var' = `var' * r(mean)
				} 
			}
			* Generate shock vector
			egen `impact'_s = rowtotal(AT_1-WM_163)
			keep v1 `impact'_s
			tempfile `impact'_s_vector
			save ``impact'_s_vector', replace
			restore
		}
			* Merge in the shock vectors
			foreach var of varlist i*{
				merge 1:1 v1 using ``var'_s_vector', nogen
			}
			destring number, replace
			sort number
			keep v1 exio_ind i_*_s
			tempfile shocks
			save `shocks', replace

		* Import Leontief
		use "$processed\Exiobase\L_2022", clear
		* Matrix define
		mkmat AT_1 - WM_163, matrix(Loecd)
		mat LIoecd = Loecd - I(_N)
		
		gen sortn = _n
		merge 1:1 v1 using `shocks', nogen
		sort sortn
		foreach var of varlist i_*_s {
			replace `var' = 0 if `var' == .
		}

		* Generate the total and upstream shock for all sectors
		foreach var of varlist i_*_s {
			mkmat `var', mat(shock)
			mat `var'_tot = Loecd * shock
			svmat `var'_tot, name(`var'_tot)
			order `var'_tot, a(`var')
			mat `var'_ups = LIoecd * shock
			svmat `var'_ups, name(`var'_ups)
			order `var'_ups, a(`var'_tot)
		}
		
		* Keep the relevant vars
			keep v1 v2 i_*
			rename *1 *
			rename v v1
		
		* Save and export
			save "$output\Economic_risk_assessment\Foreign_transition_risk_Exiobase", replace
			export excel "$output\Economic_risk_assessment\Foreign_transition_risk_Exiobase", firstrow(vari) replace
		
********************************************************************************
* PART 6: EXIOBASE TO NACE CONVERSION
********************************************************************************
		
* 6.1) Domestic scenario results		
		
	* Get the exio to nace correspondance table
		use "$processed\Exiobase\exiobase_nace_corrtable.dta", clear
		reshape long exio_, i(nace4) j(exio)
		drop if exio_ == ""
		drop exio
		rename exio_ exio_ind
	
	* Merge in the Exiobase industry numbers
		merge m:1 exio_ind using "$processed\Exiobase\Exiobase_industry_list", nogen

	* Save as tempfile
		tempfile nace_exio
		save `nace_exio', replace
		
	* Import the Domestic scenario results		
		use "$output\Economic_risk_assessment\Domestic_scenario_results_Exiobase.dta", clear
		drop sortn
		gen exio_number = _n
		order exio_number
		tempfile shock
		save `shock', replace
		
	* Merge in with the correspondance table
		use `nace_exio', clear
		merge m:1 exio_number using `shock', nogen

	* Split the shock values equally between all the Nace codes that matched to the Exiobase industry
		bys exio_ind exio_number: gen exio_count = _N
		foreach var of varlist indout va imports exports s_shock_? up_ind_? down_ind_? t_shock_? gdp_red_? fx_red_? fx_red_eu_? fx_red_noneu_? {
			replace `var' = `var' / exio_count
		}

	* Collapse sum across Nace codes
		* Retain the original value labels
		foreach v of var * {
			local l`v' : variable label `v'
			if `"`l`v''"' == "" {
				local l`v' "`v'"
			}
		}
		collapse (sum) indout va imports exports s_shock_? up_ind_? down_ind_? t_shock_? gdp_red_? fx_red_? fx_red_eu_? fx_red_noneu_? (mean) p_shock_?, by(nace4)
		* Reapply the value labels
		foreach v of var * {
			label var `v' `"`l`v''"'
		}
		
	* Merge in the Nace 1 and Nace 2 codes.
		rename nace4 nace4_code
		merge 1:1 nace4_code using "$rawdata\Auxiliary\nace_rev2.dta", nogen
		order nace4_description nace3_code nace3_description nace2_code nace2_description nace1_code nace1_description, a(nace4_code)
		
	* Label variables
		label var nace4_code "NACE Level 4 Code"
		label var nace4_description "NACE Level 4 Description"
		label var nace3_code "NACE Level 3 Code"
		label var nace3_description "NACE Level 3 Description"
		label var nace2_code "NACE Level 2 Code"
		label var nace2_description "NACE Level 2 Description"
		label var nace1_code "NACE Level 1 Code"
		label var nace1_description "NACE Level 1 Description"
		compress

	* Calculate % drop in output
		foreach intensity in 1 2 3 {
			gen output_reduction_`intensity' = t_shock_`intensity' / indout
			label var output_reduction_`intensity' "Output reduction - `intensity'"
		}
		
	* Save
		save "$output\Economic_risk_assessment\domestic_scenario_analysis_nace", replace
		export excel using "$output\Economic_risk_assessment\domestic_scenario_analysis_nace", firstrow(varlabels) replace
		export excel using "$output\Economic_risk_assessment\domestic_scenario_analysis_nace_varn", firstrow(variables) replace
		
		
* 6.2) Foreign transition risk conversion

	* Get the exio to nace correspondance table
		use "$processed\Exiobase\exiobase_nace_corrtable.dta", clear
		reshape long exio_, i(nace4) j(exio)
		drop if exio_ == ""
		drop exio
		rename exio_ exio_ind
		
	* Merge in the Exiobase industry numbers
		merge m:1 exio_ind using "$processed\Exiobase\Exiobase_industry_list", nogen

	* Save as tempfile
		tempfile nace_exio
		save `nace_exio', replace
		
	* Merge
		use "$output\Economic_risk_assessment\Foreign_transition_risk_Exiobase", clear
		keep if substr(v1,1,2) == "HU"
		gen exio_number = _n
		tempfile fortra
		save `fortra'
		use `nace_exio', clear
		merge m:1 exio_number using `fortra', nogen keep(master match)

	* Split the shock values equally between all the Nace codes that matched to the Exiobase industry
	bys exio_ind exio_number: gen exio_count = _N
	foreach var of varlist i_* {
		replace `var' = `var' / exio_count
	}

* Collapse sum across Nace codes
	* Retain the original value labels
	foreach v of var * {
		local l`v' : variable label `v'
		if `"`l`v''"' == "" {
			local l`v' "`v'"
		}
	}
	collapse (sum) i_*, by(nace4)
	* Reapply the value labels
	foreach v of var * {
		label var `v' `"`l`v''"'
	}
	
	* Merge in the 4-digit Nace level output amount
	rename nace4 nace4_code
	merge 1:1 nace4 using "$output\Economic_risk_assessment\domestic_scenario_analysis_nace", keepusing(indout) nogen	
	
* Merge in the Nace 1 and Nace 2 codes.
	*rename nace4 nace4_code
	merge 1:1 nace4_code using "$rawdata\Auxiliary\nace_rev2.dta", nogen
	order nace4_description nace3_code nace3_description nace2_code nace2_description nace1_code nace1_description, a(nace4_code)
	
* Format
	format %10.0g i_*
	export excel using "$output\Economic_risk_assessment\Foreign_transition_risk_nace", firstrow(varlab) replace	
	
* Export the table
	* Collapse at Nace1
		collapse (sum) i_* indout, by(nace1_c nace1_d)
		foreach var of varlist i_*_s {
			gen `var'_sh = `var'_tot / indout
			order `var'_sh, a(`var'_tot)
		}
	
* Rename Nace inds
	* Normalize Nace1
		replace nace1_d = "Agriculture, Forestry And Fishing" if nace1_d == "AGRICULTURE, FORESTRY AND FISHING"
		replace nace1_d = "Mining And Quarrying" if nace1_d == "MINING AND QUARRYING"
		replace nace1_d = "Manufacturing" if nace1_d == "MANUFACTURING"
		replace nace1_d = "Electricity, Gas, Steam" if nace1_d == "ELECTRICITY, GAS, STEAM AND AIR CONDITIONING SUPPLY"
		replace nace1_d = "Water Supply" if nace1_d == "WATER SUPPLY; SEWERAGE, WASTE MANAGEMENT AND REMEDIATION ACTIVITIES"
		replace nace1_d = "Construction" if nace1_d == "CONSTRUCTION"
		replace nace1_d = "Wholesale And Retail Trade" if nace1_d == "WHOLESALE AND RETAIL TRADE; REPAIR OF MOTOR VEHICLES AND MOTORCYCLES"
		replace nace1_d = "Transportation And Storage" if nace1_d == "TRANSPORTATION AND STORAGE"
		replace nace1_d = "Accommodation And Food Service" if nace1_d == "ACCOMMODATION AND FOOD SERVICE ACTIVITIES"
		replace nace1_d = "Information And Communication" if nace1_d == "INFORMATION AND COMMUNICATION"
		replace nace1_d = "Financial And Insurance" if nace1_d == "FINANCIAL AND INSURANCE ACTIVITIES"
		replace nace1_d = "Real Estate" if nace1_d == "REAL ESTATE ACTIVITIES"
		replace nace1_d = "Professional, Scientific And Technical" if nace1_d == "PROFESSIONAL, SCIENTIFIC AND TECHNICAL ACTIVITIES"
		replace nace1_d = "Administrative And Support Service" if nace1_d == "ADMINISTRATIVE AND SUPPORT SERVICE ACTIVITIES"
		replace nace1_d = "Public Administration And Defence" if nace1_d == "PUBLIC ADMINISTRATION AND DEFENCE; COMPULSORY SOCIAL SECURITY"
		replace nace1_d = "Education" if nace1_d == "EDUCATION"
		replace nace1_d = "Human Health And Social Work" if nace1_d == "HUMAN HEALTH AND SOCIAL WORK ACTIVITIES"
		replace nace1_d = "Arts, Entertainment And Recreation" if nace1_d == "ARTS, ENTERTAINMENT AND RECREATION"
		replace nace1_d = "Other Service Activities" if nace1_d == "OTHER SERVICE ACTIVITIES"
		replace nace1_d = "Activities Of Households" if nace1_d == "ACTIVITIES OF HOUSEHOLDS AS EMPLOYERS; UNDIFFERENTIATED GOODS- AND SERVICES-PRODUCING ACTIVITIES OF HOUSEHOLDS FOR OWN USE"
		replace nace1_d = "Extraterritorial Organisations and Bodies" if nace1_d == "ACTIVITIES OF EXTRATERRITORIAL ORGANISATIONS AND BODIES"	
	
* Label vars
	foreach var of varlist i_*_s {
		label var `var' "First wave exposure (M. EUR)"
	}
	foreach var of varlist i_*_s_ups {
		label var `var' "Upstream exposure (M.EUR)"
	}
	foreach var of varlist i_*_s_tot {
		label var `var' "Total output exposure (M.EUR)"
	}
	foreach var of varlist i_*_s_sh {
		label var `var' "Share of sector's total output exposed"
	}
	label var nace1_d "Sector"
	drop indout
	label var nace1_c "Nace1 Code"
	
	* Compress
	compress

	* Export excel
	export excel using "$output\Economic_risk_assessment\foreign_exposure_analysis_nace_table.xlsx", firstrow(varlab) replace	


	
	
	