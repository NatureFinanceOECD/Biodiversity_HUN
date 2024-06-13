* Version: 1.1
* Runs on: Stata/MP 18.0

* Exiobase cleaning - Sector level
	* Created: 21/11/2023
	* Last modified: 29/05/2024
	
* Summary: This do-file cleans Exiobase data for the year 2022 at the sector level, calculates indirect (and total) impact and dependency scores, and merges them in with the MNB data.

********************************************************************************
* PART 0: TABLE OF CONTENTS
********************************************************************************

*	1) SETUP

*	2) LEONTIEF

*	3) GHOSH

*	4) INDIRECT MATERIALITY CALCULATION

*	5) EXIOBASE TO NACE CONVERSION

********************************************************************************
* PART 1: SETUP
********************************************************************************

/*
	if c(username) == "gulersoy_g" {
		global path = "G:\Biodiversity\data_analysis"
		global rawdata = "$path\0_rawdata"
		global code = "$path\1_code"
		global processed = "$path\3_processeddata"
		global output = "$path\4_output"
	}
*/

clear
cd "$path"
set type double

********************************************************************************
* PART 2: LEONTIEF
********************************************************************************		
{
	
* Merge	the Z matrix with the X column.
	use "$processed\Exiobase\Z_2022", clear
	gen n = _n
	merge 1:1 v1 using "$processed\Exiobase\X_2022", nogen
	sort n
	drop n
	
* Generate sector numbers at the row level
	order sector, a(v2)
	drop v2
	gen n_sector = real(substr(v1,4,.))
	order n_sector
	
* Collapse
	collapse (sum) ??_* indout, by(n_sector sector)
	
* Rowsum
	forvalues ind = 1/163 {
		egen s_`ind' = rowtotal(??_`ind')
		drop ??_`ind'
	}
	
* Save permanently
	save "$processed\Exiobase\Z_2022_sector", replace

* Construct Z input matrix
	mkmat s_1 - s_163, mat(Z)
	local msize = _N
	
* Construct X column vector
	mkmat indout, mat(colX)
	
* Construct diagonal X matrix
	mat diagX = diag(colX)
	
* Invert diagonal X matrix
	mat diagXinv = invsym(diagX)

* Construct the A matrix
	mat A = Z*diagXinv
	local msize = _N
	
* We want to create a Leontief quantity model. If we wanted to create a Leontief price-push model we would invert the matrix A here so that now each row of A corresponds to a country-industry's purchase share from every other country industry.
	 *mat A = A'
	
* Construct the I-A matrix
	mat IminA = I(`msize')-A
	
* Invert I-A matrix to get Leontief inverse
	mat L = inv(IminA)		
	keep n_sector sector
	svmat L
	
* Recast industry variable
	gen strlen = strlen(sector)
	sum strlen, det
	local newl = r(max)
	recast str`newl' sector
	drop strlen
	
* Save
	save "$processed\Exiobase\L_2022_sector", replace
}

********************************************************************************
* PART 3: GHOSH
********************************************************************************
{
	
* Get the sector-level Z matrix prepared above	
	use "$processed\Exiobase\Z_2022_sector", clear

* Construct Z input matrix
	mkmat s_1 - s_163, mat(Z)
	local msize = _N
	
* Construct X column vector
	mkmat indout, mat(colX)
	
* Construct diagonal X matrix
	mat diagX = diag(colX)
	
* Invert diagonal X matrix
	mat diagXinv = invsym(diagX)

* Construct B matrix
	mat B = diagXinv*Z

* Construct I-B matrix
	mat IminB = I(`msize')-B
	
* Invert I-B matrix to get the Ghosh inverse	
	mat G = inv(IminB)
	keep n_sector sector
	svmat G
	
* Recast industry variable
	gen strlen = strlen(sector)
	sum strlen, det
	local newl = r(max)
	recast str`newl' sector
	drop strlen
	
* Save
	save "$processed\Exiobase\G_2022_sector", replace
}

********************************************************************************
* PART 4: INDIRECT MATERIALITY CALCULATION
********************************************************************************
{
	
* 4.1) Indirect impacts using Leontief

	use "$processed\Exiobase\L_2022_sector", clear

	* Calculate input shares
		local counter = 1
		foreach var of varlist L1 - L163 {
			replace `var' = `var' - 1 in `counter'
			local counter = `counter' + 1
			egen temp = sum(`var')
			replace `var' = `var' / temp
			drop temp
		}
		
	* Prepare for merge	
		rename sector exio_ind
		gen strlen = strlen(exio_ind)
		sum strlen, det
		local newl = r(max)
		recast str`newl' exio_ind
		drop strlen
		tempfile L_sector_shares
		save `L_sector_shares', replace
		
		
	* Loop over different types of materiality ratings
		foreach materiality_type in impacts dependencies impacts_high dependencies_high {
			use `L_sector_shares', clear
			merge m:1 exio_ind using "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_`materiality_type'.dta", nogen
			
		* Set prefix
			if "`materiality_type'" == "impacts" | "`materiality_type'" == "impacts_high" {
				local prefix = "i"
			}
			if "`materiality_type'" == "dependencies" | "`materiality_type'" == "dependencies_high" {
				local prefix = "d"
			}
			
		* Multiply materiality by shares and reshape
			local counter = 1
			foreach var of varlist `prefix'_* {
				preserve
				foreach ind of varlist L* {
					replace `ind' = `ind' * `var'
				}
				local varlab : variable label `var'
				collapse (sum) L*
				gen n = 1
				reshape long L, i(n) j(ind)
				rename L `var'_i
				label var `var'_i "`varlab'"
				tempfile `prefix'_`counter'
				save ``prefix'_`counter'', replace
				restore
				local counter = `counter' + 1
			}
			local counter = `counter' - 1
		
		* Merge all materiality ratings together
			use ``prefix'_1', clear
			forvalues datafile = 2/`counter'{
				merge 1:1 ind using ``prefix'_`datafile'', nogen
			}
			
			drop n
			rename ind number
			tempfile `materiality_type'_i
			save ``materiality_type'_i', replace
			use "$processed\Exiobase\L_2022_sector", clear
			keep n_sector sector
			rename (n_sector sector) (number exio_ind)
			merge 1:1 number using ``materiality_type'_i', nogen
			save "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_`materiality_type'_indirect.dta", replace
			
		* Calculate total impacts and dependencies
			use "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_`materiality_type'.dta", clear
			rename `prefix'_* a_*
			merge 1:1 exio_ind using "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_`materiality_type'_indirect.dta", nogen
			rename `prefix'_* b_*
			foreach var of varlist a_* {
						local othervar = "b_"+substr("`var'",3,.)
						*replace `var' = (`var' + `othervar')/2
						replace `var' = ((`var'/10) + (1-(`var'/10))*(`othervar'/10))*10
			}
			drop b_*
			rename a_* `prefix'_*_t
			sort number
			save "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_`materiality_type'_total.dta", replace
			}
			
	* Merge the direct, indirect, and total materiality ratings separately for standard and cautious ratings.
	
		* Standard
		use "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_impacts.dta", clear
		rename i_* i_*_d
		merge 1:1 number exio_ind using "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_impacts_indirect.dta", nogen keep(master match)
		merge 1:1 number exio_ind using "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_impacts_total.dta", nogen keep(master match)
		merge 1:1 number exio_ind using "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_dependencies.dta", nogen keep(master match)
		rename d_* d_*_d
		merge 1:1 number exio_ind using "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_dependencies_indirect.dta", nogen keep(master match)
		merge 1:1 number exio_ind using "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_dependencies_total.dta", nogen keep(master match)
		compress
		save "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_standard_materialities.dta", replace
		
		* Cautious
		use "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_impacts_high.dta", clear
		rename i_* i_*_d
		merge 1:1 number exio_ind using "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_impacts_high_indirect.dta", nogen keep(master match)
		merge 1:1 number exio_ind using "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_impacts_high_total.dta", nogen keep(master match)
		merge 1:1 number exio_ind using "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_dependencies_high.dta", nogen keep(master match)
		rename d_* d_*_d
		merge 1:1 number exio_ind using "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_dependencies_high_indirect.dta", nogen keep(master match)
		merge 1:1 number exio_ind using "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_dependencies_high_total.dta", nogen keep(master match)
		compress
		save "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_cautious_materialities.dta", replace
		
		* Potentially add "erase" chunk here deleting the intermediary files.
		
}
	
********************************************************************************
* PART 5: EXIOBASE TO NACE CONVERSION
********************************************************************************	
{

* 5.1) Convert indirect impacts and dependencies to Nace
		use "$processed\Exiobase\exiobase_nace_corrtable.dta", clear
		reshape long exio_, i(nace4) j(exio)
		drop if exio_ == ""
		drop exio
		rename exio_ exio_ind
		tempfile nace_exio
		save `nace_exio', replace
		
	* Calculate indirect impacts/dependencies for Nace codes
		foreach rating_type in "standard" "cautious" {
		preserve
		merge m:1 exio_ind using "$processed/Exiobase/exiobase_impacts_dependencies\exiobase_`rating_type'_materialities.dta", nogen keep(master match) keepusing(*_i)
		drop exio_ind
		collapse (mean) i_* d_*, by(nace4)
		tempfile nace_indirect
		save `nace_indirect', replace
		
	* Merge indirect ratings to the direct ratings
		if "`rating_type'" == "standard" {
			use "$processed/ENCORE/nace_impacts", clear
		}
		if "`rating_type'" == "cautious" {
			use "$processed/ENCORE/nace_impacts_high", clear
		}
		rename i_* i_*_d
		merge 1:1 nace4 using `nace_indirect', nogen keep(master match) keepusing(i_*)
		if "`rating_type'" == "standard" {
			merge 1:1 nace4 using "$processed/ENCORE/nace_dependencies", nogen
		}
		if "`rating_type'" == "cautious" {
			merge 1:1 nace4 using "$processed/ENCORE/nace_dependencies_high", nogen
		}
		rename d_* d_*_d
		merge 1:1 nace4 using `nace_indirect', nogen keep(master match) keepusing(d_*)
		
	* Calculate the total impacts dependencies by Nace
		foreach var of varlist i_*_d {
			local varlab : variable label `var'
			local othervar = substr("`var'", 1, length("`var'") - 2)+"_i"
			local othervarlab = "`varlab'" + " - Indirect"
			label var `othervar' "`othervarlab'"
			local newvar = substr("`var'", 1, length("`var'") - 2)+"_t"
			gen `newvar' = ((`var'/10) + (1-(`var'/10))*(`othervar'/10))*10
			local newvarlab = "`varlab'" + " - Total"
			label var `newvar' "`newvarlab'"
			local varlab = "`varlab'" + " - Direct"
			label var `var' "`varlab'"
		}
		order i_dist_t - i_biological_t, a(i_biological_i)
		foreach var of varlist d_*_d {
			local varlab : variable label `var'
			local othervar = substr("`var'", 1, length("`var'") - 2)+"_i"
			local othervarlab = "`varlab'" + " - Indirect"
			label var `othervar' "`othervarlab'"
			local newvar = substr("`var'", 1, length("`var'") - 2)+"_t"
			gen `newvar' = ((`var'/10) + (1-(`var'/10))*(`othervar'/10))*10
			local newvarlab = "`varlab'" + " - Total"
			label var `newvar' "`newvarlab'"
			local varlab = "`varlab'" + " - Direct"
			label var `var' "`varlab'"
		}
		
	* Save 
		save "$processed/Exiobase/exiobase_impacts_dependencies\nace_`rating_type'_materialities.dta", replace
		*export excel "$output/exiobase_impacts_dependencies/nace_impacts_dependencies", sheet(dependencies_t, replace) firstrow(varl) nolab
		restore
		}

* 5.2) Merge in the MNB data at the Nace4 level to the materiality ratings.

	foreach rating_type in "standard" "cautious" {
		
	* Get the MNB portfolio shares
		use "$processed/MNB\instruments_firms.dta", clear
		egen sum = sum(k_usd)
		gen k_usd_sh = k_usd / sum
		drop sum
		label var k_usd "Outstanding capital balance"
		label var k_usd_sh "Portfolio share"
		keep nace4 k_usd k_usd_sh EUR
		gen count = 1
		collapse (sum) count k_usd k_usd_sh (mean) EUR, by(nace4)

		merge 1:1 nace4 using "$processed/Exiobase/exiobase_impacts_dependencies\nace_`rating_type'_materialities.dta", nogen
	
	* Order variables
		order nace1 nace1_d nace4 nace4_d
		
	* Replace the missing values by 0 for the industries that don't exist in the MNB data.
		foreach var of varlist count k_usd k_usd_sh {
			replace `var' = 0 if `var' == .
		}
		sum EUR
		replace EUR = r(mean) if EUR == .

	* Compress
		compress
		
	* Save
		save "$processed/MNB/nace_`rating_type'_materialities_with_mnb", replace
		
	}
}	




