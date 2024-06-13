* Version: 1.1
* Runs on: Stata/MP 18.0

* Figaro cleaning
	* Created: 20/02/2024
	* Last modified: 29/05/2024
	
* Summary: This do-file cleans the Figaro data and outputs the Nace 1 level IO matrix, as well as the associated SEAs.

********************************************************************************
* PART 0: TABLE OF CONTENTS
********************************************************************************

*	1) SETUP

*	2) IO TABLE

*	3) SEAs

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
* PART 2: IO TABLE
********************************************************************************
{
	
* 2.1) Z matrix

	import delimited using "$rawdata\FIGARO\matrix_eu-ic-io_ind-by-ind_23ed_2021.csv", clear
	
	* Replace the "rest of the world" stuff with "RW".
		rename figw1_* fo_*
		replace rowlabels = "FO_" + substr(rowlabels,7,.) if substr(rowlabels,1,6) == "FIGW1_"
		
	* Extract the total output column
		preserve
		keep in 1/2944
		egen x = rowtotal(ar_a01 - za_p5m)
		keep rowlabel x
		save "$processed/FIGARO/X_2021", replace
		gen country = substr(rowlabels,1,2)
		gen nace1 = upper(substr(rowlabels,4,1))
		order country nace1
		collapse (sum) x, by(country nace1)
		save "$processed/FIGARO/X_2021_nace1", replace
		restore

	* Keep the Z matrix
		keep in 1/2944
		drop ar_p3_s13 - za_p5m
		save "$processed/FIGARO/Z_2021", replace

	* Construct the Nace 1 level Z matrix
		gen country = substr(rowlabels,1,2)
		gen nace1 = upper(substr(rowlabels,4,1))
		order country nace1
		collapse (sum) ar_a01 - za_u, by(country nace1)
		
	* Transpose the Z matrix
		preserve
		keep country nace1
		gen n = _n
		tempfile mat_format
		save `mat_format'
		restore
		drop country nace1
		xpose, clear varn
		order _varname
		gen country = upper(substr(_varn,1,2))
		gen nace1 = upper(substr(_varn,4,1))
		order country nace1
		drop _varname
		
	* Collapse by Nace1
		collapse (sum) v1 - v966, by(country nace1)
		
	* Transpose back
		xpose, clear varn
		drop if _n < 3
		gen n = _n
		merge 1:1 n using `mat_format', nogen
		drop n
		order country nace1
		
	* Rename the variables
		local num_obs = _N
		forvalues i = 1/`num_obs' {
			local newname = country[`i']+"_"+nace1[`i']
			di "`newname'"
			rename v`i' `newname'
		}
		drop _varname

	* Save
		save "$processed/FIGARO/Z_2021_nace1", replace
		
* 2.2) Leontief Nace1
		use "$processed\FIGARO\Z_2021_nace1", clear
		merge 1:1 country nace1 using "$processed\FIGARO\X_2021_nace1"
		
	* Construct Z input matrix
		mkmat AR_A - ZA_U, mat(Z)
		local msize = _N
		
	* Construct X column vector
		mkmat x, mat(colX)
		
	* Construct diagonal X matrix
		mat diagX = diag(colX)
		
	* Invert diagonal X matrix
		mat diagXinv = invsym(diagX)

	* Construct the A matrix
		mat A = Z*diagXinv
		local msize = _N
		
	* Construct the I-A matrix
		mat IminA = I(`msize')-A
		
	* Invert I-A matrix to get Leontief inverse
		mat L = inv(IminA)		
		keep country nace1
		svmat L
		
	* Rename variables
		local num_obs = _N
		forvalues i = 1/`num_obs' {
			local newname = country[`i']+"_"+nace1[`i']
			di "`newname'"
			rename L`i' `newname'
		}
		
	* Save the Leontief
		save "$processed/FIGARO/L_2021_nace1", replace
	
* 2.3) Ghosh Nace1
		use "$processed\FIGARO\Z_2021_nace1", clear
		merge 1:1 country nace1 using "$processed\FIGARO\X_2021_nace1"

	* Construct Z input matrix
		mkmat AR_A - ZA_U, mat(Z)
		local msize = _N
		
	* Construct X column vector
		mkmat x, mat(colX)
		
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
		keep country nace1
		svmat G
		
	* Rename variables
		local num_obs = _N
		forvalues i = 1/`num_obs' {
			local newname = country[`i']+"_"+nace1[`i']
			di "`newname'"
			rename G`i' `newname'
		}	

	* Save the Ghosh
		save "$processed/FIGARO/G_2021_nace1", replace
}
		
********************************************************************************
* PART 3: SEAs
********************************************************************************
{

* Figaro
import delimited using "$rawdata\FIGARO\matrix_eu-ic-io_ind-by-ind_23ed_2021.csv", clear
tempfile raw_figaro
save `raw_figaro', replace

* Keep Hungary
keep if substr(rowlabels,1,2) == "HU"

* Sum the output variables
egen fd = rowtotal(*_p3_s13 *_p3_s14 *_p3_s15 *_p51g *_p5m)
drop *_p3_s13 *_p3_s14 *_p3_s15 *_p51g *_p5m
egen io = rowtotal(ar_a01 - za_u)
drop ar_a01 - za_u
gen to = io + fd
order rowlabels io fd to

* Collapse to get total output
gen nace1 = ""
replace nace1 = upper(substr(rowlabels,4,1))
collapse (sum) io fd to, by(nace1)
tempfile ind_stats
save `ind_stats', replace

* Get the accounting variables
use `raw_figaro', clear
keep rowlabels hu_*
keep if _n > 2944

* Keep profit and wage bill
*keep if rowlabels == "W2_D1" | rowlabels == "W2_B2A3G"

* Collapse at the 21 Nace 1 level
xpose, clear varname
drop in 1
rename _varname nace1
replace nace1 = upper(substr(nace1,4,1))
collapse (sum) v1 - v6, by(nace1)
rename (v1 v2 v3 v4 v5 v6) (surplus wage taxes othertax nonres abroad)
tempfile stats
save `stats', replace

* Merge in with the full table
use `ind_stats', clear
merge 1:1 nace1 using `stats', nogen
save `ind_stats', replace

* Merge in the loan amount
use "$processed\MNB\instruments_firms.dta", clear
merge m:1 nace4 using "$processed/ENCORE/nace_impacts.dta", keep(master match) nogen keepusing(nace1 nace1_d nace4_d)

* Keep loan amount, convert to eur, and collapse at the Nace 1 level
gen k_eur = k_usd * EUR
collapse (sum) k_eur, by(nace1 nace1_d)
replace k_eur = k_eur / 1000000
merge 1:1 nace1 using `ind_stats', nogen
save `ind_stats', replace

* Include the variable on domestic input ratio
use `raw_figaro', clear
keep rowlabels hu_*
drop if _n > 2944
drop hu_p3_s13 hu_p3_s14 hu_p3_s15 hu_p51g hu_p5m
gen HU = substr(rowlabels,1,2) == "HU"
collapse (sum) hu_a01 - hu_u, by(HU)
xpose, clear varname
rename (v1 v2) (ii_f ii_d)
drop in 1
gen nace1 = upper(substr(_varname,4,1))
collapse (sum) ii_f ii_d, by(nace1)
tempfile dom_inp_rat
save `dom_inp_rat', replace
use `ind_stats', clear
merge 1:1 nace1 using `dom_inp_rat', nogen

* Label and export
replace nace1_d = proper(nace1_d)
label var ii_f "Foreign inputs"
label var ii_d "Domestic inputs"
gen dom_inp_rat = ii_d / (ii_f + ii_d)
label var dom_inp_rat "Domestic input ratio"

label var io "Intermediate outputs"
label var fd "Final demand"
label var to "Gross output"
gen int_con_rat = io / (io+fd)
label var int_con_rat "Intermediate consumption ratio" 

label var wage "Compensation of employees"
label var surplus "Gross operating surplus" 
label var k_eur "Portfolio amount"

label var taxes "Taxes less subsidies on products"
label var othertax "Other net taxes on production"
label var nonres "Purchases of non-residents in the domestic territory"
label var abroad "Direct purchase abroad by residents"
order nace1 nace1_d ii_f ii_d dom_inp_rat io fd to int_con_rat wage surplus k_eur
save "$processed\FIGARO\summary_statistics", replace
}


		