* Version: 1.2
* Runs on: Stata/MP 18.0

* Exiobase cleaning
	* Created: 16/11/2023
	* Last modified: 12/06/2024
	
* Summary: This do file cleans the Exiobase files at the country-sector level.

********************************************************************************
* PART 0: TABLE OF CONTENTS
********************************************************************************

*	1) SETUP

*	2) LEONTIEF

*	3) GHOSH

*	4) CLEAN F AND Y MATRICES

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
set maxvar 120000, permanently

********************************************************************************
* PART 2: LEONTIEF
********************************************************************************
{
	
* Matrix A
	import delimited "$rawdata\Exiobase\IOT_2022_ixi\A.txt", clear rowrange(4)

* Concatenate country names and sector numbers 
	gen cycle_var = mod(_n - 1, 163) + 1
	order cycle
	replace region = region + "_" + string(cycle_var)
	drop cycle_var
	rename region v1
	
* Replace the column titles with country_ind
	local cycle_var = 1
	foreach var of varlist at - v7989 {
		local newn = v1[`cycle_var']
		rename `var' `newn'
		local cycle_var = `cycle_var' + 1
	}
	
* Save as tempfile
	tempfile matA
	save `matA', replace
	
* Save permanently as well
	save "$processed\Exiobase\A_2022", replace
	
* Construct the A matrix
	*use "$processed\Exiobase\A_2022", clear
	mkmat AT_1 - WM_163, mat(A)
	local msize = _N
	
* Construct the I-A matrix
	mat IminA = I(`msize')-A
	
* Invert I-A matrix to get Leontief inverse
	mat L = inv(IminA)		
	keep v1 v2
	svmat L
	
* Rename variables
	foreach var of varlist L* {
		local cnt = real(substr("`var'",2,.))
		local newn = v1 in `cnt'
		rename `var' `newn'
	}
	
* Recast industry variable
	gen strlen = strlen(v2)
	sum strlen, det
	local newl = r(max)
	recast str`newl' v2
	
* Save
	save "$processed\Exiobase\L_2022", replace
}

********************************************************************************
* PART 3: GHOSH
********************************************************************************
{
			
* 3.1) Matrix Z

	import delimited "$rawdata\Exiobase\IOT_2022_ixi\Z.txt", clear rowrange(4)
	
	* Concatenate country names and sector numbers 
		gen cycle_var = mod(_n - 1, 163) + 1
		order cycle
		replace region = region + "_" + string(cycle_var)
		drop cycle_var
		rename region v1
		
	* Replace the column titles with country_ind
		local cycle_var = 1
		foreach var of varlist at - v7989 {
			local newn = v1[`cycle_var']
			rename `var' `newn'
			local cycle_var = `cycle_var' + 1
		}
		
	* Generate Exiobase sector name and numbers columns
		preserve
		gen exio_number = substr(v1,4,.)
		order exio_n
		rename v2  exio_ind
		keep exio_n exio_i
		duplicates drop
		destring exio_n, replace
		gen strlen = strlen(exio_ind)
		sum strlen, det
		local newl = r(max)
		recast str`newl' exio_ind
		drop strlen	
		save "$processed\Exiobase\Exiobase_industry_list", replace
		restore
		
	* Save permanently 
		save "$processed\Exiobase\Z_2022", replace	
		
* 3.2) Column X
		
	import delimited "$rawdata\Exiobase\IOT_2022_ixi\X.txt", clear
	
	* Concatenate country names and sector numbers
		gen temp = _n
		gen cycle_var = mod(temp - 1, 163) + 1
		order cycle
		replace region = region + "_" + string(cycle_var)
		drop temp cycle_var
		rename region v1
		gen n = _n
		
	* Save as tempfile
		tempfile colX
		save `colX', replace
		
	* Save permanently
		save "$processed\Exiobase\X_2022.dta", replace

* 3.3) Merge
	
	use "$processed\Exiobase\Z_2022", clear
	gen n = _n
	merge 1:1 v1 using `colX', nogen
	sort n
	drop n
	
	* Construct Z input matrix
		mkmat AT_1 - WM_163, mat(Z)
		local msize = _N
		
	* Construct X column vector
		mkmat indout, mat(colX)
		
	* Construct diagonal X matrix
		mat diagX = diag(colX)
		
	* Invert diagonal X matrix
		mat diagXinv = invsym(diagX)
		
	* Save 
		preserve
		keep v1 sector
		svmat diagXinv
		save "$processed/Exiobase/diagXinv_2022", replace
		restore
			
	* Construct B matrix
		mat B = diagXinv*Z

	* Construct I-B matrix
		mat IminB = I(`msize')-B
		
	* Invert I-B matrix to get the Gosh inverse	
		mat G = inv(IminB)
		keep v1 v2
		svmat G
		
	* Rename variables
		foreach var of varlist G* {
			local cnt = real(substr("`var'",2,.))
			local newn = v1 in `cnt'
			rename `var' `newn'
		}
		
	* Recast industry variable
		gen strlen = strlen(v2)
		sum strlen, det
		local newl = r(max)
		recast str`newl' v2
		drop strlen
		
	* Save
		save "$processed\Exiobase\G_2022", replace
}

********************************************************************************
* PART 4: CLEAN F AND Y MATRICES
********************************************************************************
{
	
* 4.1) F Matrix
	import delimited using "$rawdata\Exiobase\IOT_2022_ixi\impacts\F.txt", clear

	* Concatenate country names and sector numbers
		gen temp = _n
		gen cycle_var = mod(temp - 4, 163) + 1
		order cycle
		replace v1 = v1 + "_" + string(cycle_var)
		drop temp cycle_var
		
	* Replace the column titles with country_ind
		foreach var of varlist v2 - v7988 {
			local num = real(substr("`var'",2,.))
			local num = mod(`num'-2,163) + 1
			replace `var' = `var' + "_" + "`num'" in 1
			local newn = `var' in 1
			rename `var' `newn'
		}
		
	* Clean and destring
		drop if _n < 4
		foreach var of varlist AT_1 - WM_163 {
			destring `var', replace
		}
		
	* Correct the variable names
		replace v1 = substr(v1,1,strlen(v1)-2) if _n < 10
		replace v1 = substr(v1,1,strlen(v1)-3) if _n >= 10

	* Save permanently as well - because destring takes too long	
		save "$processed\Exiobase\F_2022", replace	

* 4.2) Clean the Y Matrix
		import delimited using "$rawdata\Exiobase\IOT_2022_ixi\Y.txt", clear

	* Concatenate country names and sector numbers
		gen temp = _n
		gen cycle_var = mod(temp - 4, 163) + 1
		order cycle
		replace v1 = v1 + "_" + string(cycle_var)
		drop temp cycle_var
		
	* Replace the column titles with "country_ind"
		foreach var of varlist v3 - v345 {
			local num = real(substr("`var'",2,.))
			local num = mod(`num'-3,7) + 1
			replace `var' = `var' + "_" + "`num'" in 1
			local newn = `var' in 1
			rename `var' `newn'
		}

	* Clean and destring
		drop if _n < 4
		foreach var of varlist AT_1 - WM_7 {
			destring `var', replace
		}
		
	* Rename and label variables
		foreach var of varlist *_1 {
			label var `var' "Final consumption expenditure by households"
		}
		rename *_1 *_fcebh
		foreach var of varlist *_2 {
			label var `var' "Final consumption expenditure by non-profit organisations serving households (NPISH)"
		}
		rename *_2 *_fcebnpo
			foreach var of varlist *_3 {
			label var `var' "Final consumption expenditure by government"
		}
		rename *_3 *_fcebg
			foreach var of varlist *_4 {
			label var `var' "FGross fixed capital formation"
		}
		rename *_4 *_gfcf
			foreach var of varlist *_5 {
			label var `var' "Changes in inventories"
		}
		rename *_5 *_cii
			foreach var of varlist *_6 {
			label var `var' "Changes in valuables"
		}
		rename *_6 *_civ
			foreach var of varlist *_7 {
			label var `var' "Exports: Total (fob)"
		}
		rename *_7 *_exp						

	* Save permanently	
		save "$processed\Exiobase\Y_2022", replace	
}
	
	







