* Version: 1.1
* Runs on: Stata/MP 18.0

* Identification and Prioritization
	* Created: 23/11/2023
	* Last modified: 29/05/2024
	
* Summary: This do-file generates the outputs to be included in the "Identification and Prioritisation" section of the paper.

********************************************************************************
* PART 0: TABLE OF CONTENTS
********************************************************************************

*	1) SETUP

*	2) EXPOSURE TO PHYSICAL AND TRANSITION RISKS

*	3) IMPACT AND DEPENDENCY LINKS

*	4) PORTFOLIO SCORES

*	5) SECTORAL DISAGGREGATION

*	6) CLIMATE AND NATURE NEXUS

*	7) DIRECTNESS

*	8) UPSTREAMNESS & DOWNSTREAMNESS

*	9) SUMMARY STATISTICS

*	10) GEOGRAPHICAL SCOPE

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

* Install dependencies
foreach package in sankey geo2xy colorpalette {
	capture which `package'
	if _rc == 111 {
		ssc install `package'
	}
}

********************************************************************************
* PART 2: EXPOSURE TO PHYSICAL AND TRANSITION RISKS
********************************************************************************
{
use "$processed/MNB/nace_standard_materialities_with_mnb.dta", clear

	* Generate variables of number of ecosystem services Highly impacted / depended
		gen h_i = 0
			foreach var of varlist i_dist_d - i_biological_d {
			replace h_i = h_i + 1 if `var' > 6
		}
		gen vh_i = 0
		foreach var of varlist i_dist_d - i_biological_d {
			replace vh_i = vh_i + 1 if `var' > 8
		}
		gen h_d = 0
			foreach var of varlist d_animal_d - d_waterquality_d {
			replace h_d = h_d + 1 if `var' > 6
		}
		gen vh_d = 0
		foreach var of varlist d_animal_d - d_waterquality_d {
			replace vh_d = vh_d + 1 if `var' > 8
		}
		
	* Keep relevant vars
		keep k_usd_sh h_i vh_i h_d vh_d
		
	* Replace those more than 6 with 6, in order to later demonstrate as 5+. Collapse and structure for output.
		foreach var of varlist h_i vh_i h_d vh_d {
			preserve
			replace `var' = 6 if `var' > 6
			collapse (sum) k_usd_sh, by(`var')
			xpose, clear var
			foreach varn of varlist v* {
				local newname = "eco_" + string(`varn'[1])
				rename `varn' `newname'
			}
			*rename eco_6 eco_6plus
			drop in 1
			order _varname
			replace _varname = "`var'"
			tempfile `var'_table
			save ``var'_table', replace
			restore
		}
		
	* Append	
		use `h_i_table', clear
		foreach data in vh_i h_d vh_d {
			append using ``data'_table'
		}
		
	* Replace missing values
		foreach var of varlist eco_? {
			replace `var' = 0 if `var' == .
		}
	
	* Replace variable names
		gen type = "Impacts" if _varname == "h_i" | _varname == "vh_i"
		replace type = "Dependencies" if _varname == "h_d" | _varname == "vh_d"
		replace _varname = "High" if _varname == "h_i"
		replace _varname = "Very High" if _varname == "vh_i"
		replace _varname = "High" if _varname == "h_d"
		replace _varname = "Very High" if _varname == "vh_d"
		order type
		
	* Export excel
		export excel using "$output\Identification_and_prioritisation\portfolio_share_impacts_dependencies", firstrow(var) replace
}

********************************************************************************
* PART 3: IMPACT AND DEPENDENCY LINKS
********************************************************************************
{
foreach mode in d i {
	
	* Import data
		use "$processed\MNB\nace_standard_materialities_with_mnb.dta", clear
		gen k_eur = k_usd * EUR

	* Reshape long
		if "`mode'" == "d" {
			keep nace4 k_eur nace1_d d_*_d
			local prefix = "d_"
			reshape long d_, i(nace4) j(dependency) string			
		}
		if "`mode'" == "i" {
			keep nace4 k_eur nace1_d i_*_d
			local prefix = "i_"
			reshape long i_, i(nace4) j(impact) string	
		}
		
	* Standardize the materialities of different ecosystem services across an industry.
		bys nace4: egen `prefix'tot = sum(`prefix')
		replace `prefix' = `prefix' / `prefix'tot
	
	* Sum across Nace1
		replace k_eur = k_eur * `prefix'
		
	* Rename and label
		if "`mode'" == "d" {
			collapse (sum) k_eur, by(nace1_d dependency)
			replace dependency = "d_" + substr(dependency,1,strpos(dependency,"_")-1)	
			replace dependency = "Animal based energy" if dependency == "d_animal"
			replace dependency = "Bio-remediation" if dependency == "d_bio"
			replace dependency = "Buffering and attenuation of mass flows" if dependency == "d_buffering"
			replace dependency = "Climate regulation" if dependency == "d_climate"
			replace dependency = "Dilution by atmosphere and ecosystems" if dependency == "d_dilution"
			replace dependency = "Disease control" if dependency == "d_disease" 
			replace dependency = "Fibres and other materials" if dependency == "d_fibres" 
			replace dependency = "Filtration" if dependency == "d_filtration"
			replace dependency = "Flood and storm protection" if dependency == "d_flood"
			replace dependency = "Genetic materials" if dependency == "d_genetic"
			replace dependency = "Ground water" if dependency == "d_groundwater"
			replace dependency = "Maintain nursery habitats" if dependency == "d_nursery"
			replace dependency = "Mass stabilisation and erosion control" if dependency == "d_erosion"
			replace dependency = "Mediation of sensory impacts" if dependency == "d_mediation"
			replace dependency = "Pest control" if dependency == "d_pest"
			replace dependency = "Pollination" if dependency == "d_pollination"
			replace dependency = "Soil quality" if dependency == "d_soil"
			replace dependency = "Surface water" if dependency == "d_surfacewater"
			replace dependency = "Ventilation" if dependency == "d_ventilation"
			replace dependency = "Waterflow maintenance" if dependency == "d_waterflow"
			replace dependency = "Water quality" if dependency == "d_waterquality"
			order nace1_d dependency k_eur
		}
		
		if "`mode'" == "i" {
			collapse (sum) k_eur, by(nace1_d impact)
			replace impact = "Disturbances" if impact == "dist_d"
			replace impact = "Freshwater ecosystem use" if impact == "freshwater_d"
			replace impact = "GHG emissions" if impact == "ghg_d"
			replace impact = "Marine ecosystem use" if impact == "marine_d"
			replace impact = "Non-GHG air pollutants" if impact == "nonghg_d"
			replace impact = "Other resource use" if impact == "other_d"
			replace impact = "Soil pollutants" if impact == "soil_d"
			replace impact = "Solid waste" if impact == "solid_d"
			replace impact = "Terrestrial ecosystem use" if impact == "terrestrial_d"
			replace impact = "Water pollutants" if impact == "waterpol_d"
			replace impact = "Water use" if impact == "wateruse_d"
			replace impact = "Biological interferences/alterations" if impact == "biological_d"
			order nace1_d impact k_eur
		}
		
	* Generate first class
		gen class = "Loans and debt instruments"
		order class		

	* Reshape data for Sankey
		preserve
		keep class nace1_d k_eur
		rename (class nace1_d k_eur) (source destination value)
		gen layer = 0
		tempfile layer0
		save `layer0', replace
		restore
		preserve
		if "`mode'" == "d" {
			keep nace1_d dependency k_eur
			rename (nace1_d dependency k_eur) (source destination value)
		}
		if "`mode'" == "i" {
			keep nace1_d impact k_eur
			rename (nace1_d impact k_eur) (source destination value)
		}
		gen layer = 1
		tempfile layer1
		save `layer1', replace
		restore
		use `layer0', clear
		append using `layer1'
		
	* Generate Sankey
		graph drop _all
		if "`mode'" == "d" {
			sankey value, from(source) to(destination) by(layer) sort1(value) sort2(value) noval smooth(6) laba(0) labs(1.5) labpos(0) name(dependencies) /* ctitles("" "NACE Level 1" "Ecosystem services") */
			graph display dependencies, scale(1) margins(large)
			graph export "$output\Identification_and_prioritisation\Sankey_dependencies.emf", as(emf) name("dependencies") replace
			export excel "$output\Identification_and_prioritisation\sankey.xlsx", replace sheet(dependencies) firstrow(varia)
		}
		if "`mode'" == "i" {
			sankey value, from(source) to(destination) by(layer) sort1(value) sort2(value) noval smooth(6) laba(0) labs(1.5) labpos(0) name(impacts) /* ctitles("" "NACE Level 1" "Ecosystem services") */
			graph display impacts, scale(1) margins(large)
			graph export "$output\Identification_and_prioritisation\Sankey_impacts.emf", as(emf) name("impacts") replace		
			export excel "$output\Identification_and_prioritisation\sankey.xlsx", sheet(impacts, replace) firstrow(varia)
			}
		
}
}

********************************************************************************
* PART 4: PORTFOLIO SCORES
********************************************************************************
{
use "$processed/MNB/nace_cautious_materialities_with_mnb.dta", clear

	* Multiply and collapse
		foreach var of varlist i_dist_d - d_waterquality_t {
			replace `var' = `var' * k_usd_sh
		}
		collapse (sum) i_dist_d - d_waterquality_t
		
	* Reshape
		* Impacts
		preserve
		gen i = 1
		reshape long i_, i(i) j(impact) string
		keep i impact i_
		drop i
		rename i_ score
		* Generate directness indicator
		gen type = "Direct" if substr(impact, strlen(impact), 1) == "d"
		replace type = "Indirect" if substr(impact, strlen(impact), 1) == "i"
		replace type = "Combined" if substr(impact, strlen(impact), 1) == "t"		
		* Rename and label
		replace impact = "Disturbances" if substr(impact, 1, 4) == "dist"
		replace impact = "Freshwater ecosystem use" if substr(impact, 1, 10) == "freshwater"
		replace impact = "GHG emissions" if substr(impact, 1, 3) == "ghg"
		replace impact = "Marine ecosystem use" if substr(impact, 1, 6) == "marine"
		replace impact = "Non-GHG air pollutants" if substr(impact, 1, 6) == "nonghg"
		replace impact = "Other resource use" if substr(impact, 1, 5) == "other"
		replace impact = "Soil pollutants" if substr(impact, 1, 4) == "soil"
		replace impact = "Solid waste" if substr(impact, 1, 5) == "solid"
		replace impact = "Terrestrial ecosystem use" if substr(impact, 1, 11) == "terrestrial"
		replace impact = "Water pollutants" if substr(impact, 1, 8) == "waterpol"
		replace impact = "Water use" if substr(impact, 1, 8) == "wateruse"
		replace impact = "Biological interferences/alterations" if substr(impact, 1, 10) == "biological"
		* Reshape
		reshape wide score, i(impact) j(type) string
		rename score* *
		rename impact Impact
		*gsort - Combined
		*sort Direct
		sort Combined
		order Combined Indirect Direct, a(Impact)
		foreach var of varlist Combined Indirect Direct {
			replace `var' = `var' / 10
		}
		tempfile impact_chart
		save `impact_chart'
		export excel using "$output\Identification_and_prioritisation\ecosystem_barchart_high", firstrow(var) sheet(impacts) replace
		restore

		* Dependencies
		preserve
		gen i = 1
		reshape long d_, i(i) j(dependency) string
		keep i dependency d_
		drop i
		rename d_ score
		* Generate directness indicator
		gen type = "Direct" if substr(dependency, strlen(dependency), 1) == "d"
		replace type = "Indirect" if substr(dependency, strlen(dependency), 1) == "i"
		replace type = "Combined" if substr(dependency, strlen(dependency), 1) == "t"		
		* Rename and label
		replace dependency = "Animal based energy" if substr(dependency, 1, 6) == "animal"
		replace dependency = "Bio-remediation" if substr(dependency, 1, 3) == "bio"
		replace dependency = "Buffering and attenuation of mass flows" if substr(dependency, 1, 9) == "buffering"
		replace dependency = "Climate regulation" if substr(dependency, 1, 7) == "climate"
		replace dependency = "Dilution by atmosphere and ecosystems" if substr(dependency, 1, 8) == "dilution"
		replace dependency = "Disease control" if substr(dependency, 1, 7) == "disease"
		replace dependency = "Fibres and other materials" if substr(dependency, 1, 6) == "fibres"
		replace dependency = "Filtration" if substr(dependency, 1, 10) == "filtration"
		replace dependency = "Flood and storm protection" if substr(dependency, 1, 5) == "flood"
		replace dependency = "Genetic materials" if substr(dependency, 1, 7) == "genetic"
		replace dependency = "Ground water" if substr(dependency, 1, 11) == "groundwater"
		replace dependency = "Maintain nursery habitats" if substr(dependency, 1, 7) == "nursery"
		replace dependency = "Mass stabilisation and erosion control" if substr(dependency, 1, 7) == "erosion"
		replace dependency = "Mediation of sensory impacts" if substr(dependency, 1, 9) == "mediation"
		replace dependency = "Pest control" if substr(dependency, 1, 4) == "pest"
		replace dependency = "Pollination" if substr(dependency, 1, 11) == "pollination"
		replace dependency = "Soil quality" if substr(dependency, 1, 4) == "soil"
		replace dependency = "Surface water" if substr(dependency, 1, 12) == "surfacewater"
		replace dependency = "Ventilation" if substr(dependency, 1, 11) == "ventilation"
		replace dependency = "Waterflow maintenance" if substr(dependency, 1, 9) == "waterflow"
		replace dependency = "Water quality" if substr(dependency, 1, 12) == "waterquality"
		* Reshape
		reshape wide score, i(dependency) j(type) string
		rename score* *
		rename dependency Dependency
		*gsort - Combined
		*sort Direct
		sort Combined
		order Combined Indirect Direct, a(Dependency)
		foreach var of varlist Combined Indirect Direct {
			replace `var' = `var' / 10
		}
		tempfile dependency_chart
		save `dependency_chart'
		export excel using "$output\Identification_and_prioritisation\ecosystem_barchart_high", firstrow(var) sheet(dependencies,replace)
		restore
}

********************************************************************************
* PART 5: SECTORAL DISAGGREGATION
********************************************************************************
{
	use "$processed/MNB/nace_cautious_materialities_with_mnb", clear

* Multiply and collapse
		foreach var of varlist i_dist_d - d_waterquality_t {
			replace `var' = `var' * k_usd_sh
		}
		
* Collapse total impacts and dependencies by Nace1		
		collapse (sum) i_dist_d - d_waterquality_t, by(nace1 nace1_d)
		
* Generate total impact and total dependency weighted scores for each Nace 1 sector
		egen i_total = rowtotal(i_*_t)
		replace i_total = i_total / 10
		egen d_total = rowtotal(d_*_t)
		replace d_total = d_total / 10
	
* Labels
	label var d_animal_t "Animal based energy"
	label var d_bio_t "Bio-remediation"
	label var d_buffering_t "Buffering and attenuation of mass flows"
	label var d_climate_t "Climate regulation"
	label var d_dilution_t "Dilution by atmosphere and ecosystems"
	label var d_disease_t "Disease control"
	label var d_fibres_t "Fibres and other materials"
	label var d_filtration_t "Filtration"
	label var d_flood_t "Flood and storm protection"
	label var d_genetic_t "Genetic materials"
	label var d_groundwater_t "Ground water"
	label var d_nursery_t "Maintain nursery habitats"
	label var d_erosion_t "Mass stabilisation and erosion control"
	label var d_mediation_t "Mediation of sensory impacts"
	label var d_pest_t "Pest control"
	label var d_pollination_t "Pollination"
	label var d_soil_t "Soil quality"
	label var d_surfacewater_t "Surface water"
	label var d_ventilation_t "Ventilation"
	label var d_waterflow_t "Waterflow maintenance"
	label var d_waterquality_t "Water quality"
	
	label var i_dist_t "Disturbances"
	label var i_freshwater_t "Freshwater ecosystem use"
	label var i_ghg_t "GHG emissions"
	label var i_marine_t "Marine ecosystem use"
	label var i_nonghg_t "Non-GHG air pollutants"
	label var i_other_t "Other resource use"
	label var i_soil_t "Soil pollutants"
	label var i_solid_t "Solid waste"
	label var i_terrestrial_t "Terrestrial ecosystem use"
	label var i_waterpol_t "Water pollutants"
	label var i_wateruse_t "Water use"
	label var i_biological_t "Biological interferences/alterations"
	
	label var i_total "Total impact score"
	label var d_total "Total dependency score"
	
	replace nace1_d = proper(nace1_d)
	
* Impacts
	preserve
	keep nace1 nace1_d i_*_t i_total
	export excel using "$output\Identification_and_prioritisation/sectoral_breakdown_high_nace1", replace firstrow(varl) sheet(impacts)
	restore
	preserve
	keep nace1 nace1_d d_*_t d_total
	export excel using "$output\Identification_and_prioritisation/sectoral_breakdown_high_nace1", firstrow(varl) sheet(dependencies, replace)
	restore
}
	
********************************************************************************
* PART 6: CLIMATE AND NATURE NEXUS (CPRS)
********************************************************************************
{
* 6.1) Cleaning
	import excel using "$rawdata\Auxiliary\CPRS_20220909_NGFS", clear sheet(NACE_CPRS_IAM) firstrow
	rename *, lower
	keep if level == "4"
	keep nace description carbonleakage cprsmain cprs2 cprsgranular noteoncprs
	replace nace = substr(nace,3,2)+substr(nace,6,2)
	gen cprs_flag = noteoncprs != ""
	label var cprs_flag "Mapped with NACE 3 digits."
	
	* Clean the CPRS category variables
		
		* Drop CPRS granular
			drop cprsgranular
			duplicates drop
		
		* CPRS
			gen cprs = real(substr(cprsmain, 1, 1))
			gen cprs_lab = proper(substr(cprsmain,3,.))
			labmask cprs, values(cprs_lab)
			order cprs, a(cprsmain)
			drop cprsmain cprs_lab noteoncprs
			rename nace nace4
			duplicates drop
				
		* Labels
			label var carbonleakage "Letters in the EU Carbon Leakage classification (Battiston et al. 2017 Supp. In)"
			label var cprs "CPRS sectors at the first level of granularity."
			label var cprs2 "Second level. Distinguishes some high/low carbon activities."
			replace cprs2 = proper(substr(cprs2, 3,.))
			
		* Save as tempfile	
			tempfile cprs
			save `cprs', replace

* 6.2) Merge

	use "$processed/MNB/nace_standard_materialities_with_mnb", clear	
	merge m:1 nace4 using `cprs', keep(master match) nogen
	* There is 1 Nace-4 industry missing from CPRS => 4311
	
	* Decisions
	
	* Treat missing CPRS codes as "other"
		replace cprs = 9 if cprs == .
		replace cprs2 = "Other" if cprs2 == ""

	* Collapse
		gen k_eur = k_usd * EUR
		collapse (sum) k_eur k_usd_sh (mean) i_dist_d - d_waterquality_t , by(nace4 desc cprs cprs2 nace1 nace1_d)
		rename k_usd_sh k_sh

	* Analysis	
		gen cprs_v = cprs != 9
		tab cprs_v
		replace k_sh = 0 if k_sh == .
		gen h_vh = 0
		* Ignore the GHG impact variable
			drop i_ghg_d
		foreach var of varlist i_*_d {
			replace h_vh = 1 if `var' > 6
		}
		
	* Collapse	
		collapse (sum) k_sh, by(cprs_v h_vh nace1 nace1_d)

	* Generate a unique identifier for each combination of 'cprs_v' and 'h_vh'
		gen hvh_cprs = string(h_vh) + "_" + string(cprs_v)
		drop h_vh cprs

		* Reshape the data from long to wide, using the new combination identifier
		reshape wide k_sh, i(nace1 nace1_d) j(hvh_cprs) string

		* Replace missing values with 0
		foreach var of varlist k_sh* {
			replace `var' = 0 if missing(`var')
		}
		
	* Proper
		replace nace1_d = proper(nace1_d)
	
	* Label vars
		label var k_sh0_0 "Neither ENCORE nor CPRS"
		label var k_sh0_1 "Only CPRS"
		label var k_sh1_0 "Only ENCORE"
		label var k_sh1_1 "Both ENCORE and CPRS"
	
	* Export excel
		export excel "$output\Identification_and_prioritisation\hvh_cprs_link", firstrow(varl) replace
}
		
********************************************************************************
* PART 7: DIRECTNESS
********************************************************************************
{
use "$processed\Exiobase\exiobase_impacts_dependencies\nace_standard_materialities.dta", clear
	
* Directness vs indirectness
	egen i_d_t = rowtotal(i_*_d) /* Impact directness */
	egen i_i_t = rowtotal(i_*_i) /* Impact indirectness */
	egen d_d_t = rowtotal(d_*_d) /* Dependency directness */
	egen d_i_t = rowtotal(d_*_i) /* Dependency indirectness */
	gen d_t = i_d_t + d_d_t /* All-inclusive directness */
	gen i_t = i_i_t + d_i_t /* All-inclusive indirectness */
	
* Generate impact directness score, defined as total direct impacts minus total indirect impacts, divided by the number of impact drivers
	gen imp_dir = ((i_d_t - i_i_t)/10) / 12
	gen dep_dir = ((d_d_t - d_i_t)/10) / 21

* Export
	* Table 1
	preserve
	collapse (mean) imp_dir dep_dir, by(nace1 nace1_d)
	keep nace1 nace1_d imp_dir
	gsort - imp_dir
	gen impact_directness_order = _n
	export excel using "$output\Identification_and_prioritisation\directness", replace sheet(impacts_nace1) firstrow(variables)
	restore
	preserve
	collapse (mean) imp_dir dep_dir, by(nace1 nace1_d)
	keep nace1 nace1_d dep_dir
	gsort - dep_dir
	gen dependency_directness_order = _n
	export excel using "$output\Identification_and_prioritisation\directness", sheet(dependencies_nace1, replace) firstrow(variables)
	restore
	preserve
	keep nace4 nace4_d imp_dir
	gsort - imp_dir
	gen impact_directness_order = _n
	export excel using "$output\Identification_and_prioritisation\directness", sheet(impacts_nace4, replace) firstrow(variables)
	restore
	preserve
	keep nace4 nace4_d dep_dir
	gsort - dep_dir
	gen dependency_directness_order = _n
	export excel using "$output\Identification_and_prioritisation\directness", sheet(dependencies_nace4, replace) firstrow(variables)
	restore
	
	* Table 2 (Do a second table here considering all 33 ecosystem services together)
	preserve
	gen dir = ((d_t - i_t)/10) / 33
	collapse (mean) dir, by(nace1 nace1_d)
	gsort - dir
	export excel using "$output\Identification_and_prioritisation\directness_together", sheet(dependencies_nace4, replace) firstrow(variables)
	restore
}		

********************************************************************************
* PART 8: UPSTREAMNESS & DOWNSTREAMNESS (FIGARO)
********************************************************************************
{
 * Upstreamness corresponds to the row sum of Ghosh. (Large amount of total forward linkages.)
	use "$processed/FIGARO/G_2021_nace1", clear
	
	* Gen upstreamness
		egen upstream = rowtotal(HU_A - HU_U) if country == "HU"
		keep country nace1 upstream
		keep if country == "HU"
		
	* Get Nace1_d
		merge 1:m nace1 using "$processed/MNB/nace_standard_materialities_with_mnb.dta", nogen keepusing(nace1_d) keep(master match)
		duplicates drop
		
	* Save as tempfile
		tempfile upstreamness
		save `upstreamness', replace
		
* Downstreamness, by proxy, corresponds to the column sum of Leontief. (Large amount of total backwards linkages.) 
 	use "$processed/FIGARO/L_2021_nace1", clear
	
	* Gen downstreamness
		gen v1 = country+"_"+nace1
		mkmat AR_A - ZA_U, mat(L) rownames(v1)
		mat L = L'
		keep country nace1 v1
		svmat L, names(col)
		drop v1
		egen downstream = rowtotal(HU_A - HU_U) if country == "HU"
		keep country nace1 downstream
		keep if country == "HU"
		
	* Get Nace1_d
		merge 1:m nace1 using "$processed/MNB/nace_standard_materialities_with_mnb.dta", nogen keepusing(nace1_d)
		duplicates drop		
		
	* Save as tempfile
		tempfile downstreamness
		save `downstreamness', replace	

* Export
	use `upstreamness', clear
	merge 1:1 nace1 using `downstreamness', nogen
	sort nace1
	
	order country nace1 nace1_d
	drop country
	gen keyness = upstream * downstream
	gsort - keyness
	export excel "$output\Identification_and_prioritisation\upstreamness", firstrow(var) replace
}

********************************************************************************
* PART 9: SUMMARY STATISTICS (FIGARO)
********************************************************************************
{
use "$processed\FIGARO\summary_statistics", clear

keep nace1 nace1_d ii_f ii_d dom_inp_rat io fd to int_con_rat wage surplus k_eur
gen ii = ii_f + ii_d
order ii, a(ii_d)
drop ii_f ii_d
label var ii "Intermediate inputs"

drop io fd

* Nace1 labels
replace nace1_d = "Electricity, Gas, Steam" in 4
replace nace1_d = "Accommodation And Food Service" in 9
replace nace1_d = "Financial And Insurance" in 11
replace nace1_d = "Professional, Scientific And Technical" in 13
replace nace1_d = "Administrative And Support Service" in 14
replace nace1_d = "Human Health And Social Work" in 17
replace nace1_d = "Activities Of Households" in 20
compress

* Convert to EUR billions
	foreach var of varlist ii to wage surplus k_eur {
		replace `var' = `var' / 1000
	}
	
* Drop Households and Extraterritorials
	drop if nace1 == "T" | nace1 == "U"

export excel using "$output\Identification_and_prioritisation\industry_stats", firstrow(varlab) replace
}

********************************************************************************
* PART 10: GEOGRAPHICAL SCOPE
********************************************************************************
{
global county_map = "$rawdata\Auxiliary\Map_data\NUTS_RG_01M_2021_3035"
global district_map = "$rawdata\Auxiliary\Map_data\Hungary_shapefile\hun_admbnda_osm_20220720_shp"
	
* 10.1) County level

	* Get the shp data.
	use "$county_map\world.dta", clear

	* Generate matching ID
	gen _ID = _n

	* Keep Hungary NUTS 3
	keep if CNTR_CODE == "HU" & LEVL_CODE == 3

	*Save as tempfile
	tempfile location
	save `location', replace

	* Take the instruments data
	use "$processed\MNB\instruments_firms.dta", clear
	merge m:1 nace4 using "$processed\MNB\nace_standard_materialities_with_mnb.dta", nogen keepusing(nace1 nace1_d)

	* Concord the NUTS 3 names.
	decode county, gen(NUTS_NAME)
	replace NUTS_NAME = "Csongrád" if NUTS_NAME == "Csongrád-Csanád"
	replace NUTS_NAME = "Győr-Moson-Sopron" if NUTS_NAME == "Gyor-Moson-Sopron"

	* Get the variables of interest (total exposure, total agricultural exposure etc.)
	gen k_eur = k_usd * EUR
	gen k_eur_a = k_eur if nace1 == "A"
	gen k_eur_c = k_eur if nace1 == "C"
	gen k_eur_l = k_eur if nace1 == "L"
	collapse (sum) k_eur k_eur_a k_eur_c k_eur_l, by(NUTS_NAME)
	drop if NUTS_NAME == ""
	foreach var of varlist k_eur k_eur_a k_eur_c k_eur_l {
		replace `var' = `var' / 1000000
	}

	* Merge with the map data
	merge 1:1 NUTS_NAME using `location', nogen

	* Generate the total exposure map
	colorpalette sfso blue, n(20) nograph reverse
	local colors `r(p)'
	spmap k_eur using "$county_map/world_shp", id(_ID) fcolor("`colors'") /*title("Total exposure amount")*/ clnumber(20) legenda(off)
	graph export "$output\Identification_and_prioritisation\total_exposure.emf", as(emf) replace

	* Generate the agricultural exposure map
	colorpalette sfso green, n(20) nograph reverse
	local colors `r(p)'
	spmap k_eur_a using "$county_map/world_shp", id(_ID) fcolor("`colors'") /*title("Total agricultural exposure amount")*/ clnumber(20) legenda(off)
	graph export "$output\Identification_and_prioritisation\total_exposure_a.emf", as(emf) replace

	* Generate the manufacturing exposure map
	colorpalette sfso orange, n(20) nograph reverse
	local colors `r(p)'
	spmap k_eur_c using "$county_map/world_shp", id(_ID) fcolor("`colors'") /*title("Total manufacturing exposure amount")*/ clnumber(20) legenda(off)
	graph export "$output\Identification_and_prioritisation\total_exposure_c.emf", as(emf) replace

	* Generate the real estate exposure map
	colorpalette sfso brown, n(20) nograph reverse
	local colors `r(p)'
	spmap k_eur_l using "$county_map/world_shp", id(_ID) fcolor("`colors'") /*title("Total real estate exposure amount")*/ clnumber(20) legenda(off)
	graph export "$output\Identification_and_prioritisation\total_exposure_l.emf", as(emf) replace

* 10.2) District level

	use "$processed\MNB\instruments_firms.dta", clear
	decode district, gen(district2)
	order district2, a(district)
	drop district
	rename district2 district
	* Rename the districts in the MNB data to match the shp file.
	{
	replace district = "10th district" if district=="Budapest 10. Ker."
	replace district = "11th district" if district=="Budapest 11. Ker."
	replace district = "12th district" if district=="Budapest 12. Ker."
	replace district = "13th district" if district=="Budapest 13. Ker."
	replace district = "14th district" if district=="Budapest 14. Ker."
	replace district = "15th district" if district=="Budapest 15. Ker."
	replace district = "16th district" if district=="Budapest 16. Ker."
	replace district = "17th district" if district=="Budapest 17. Ker."
	replace district = "18th district" if district=="Budapest 18. Ker."
	replace district = "19th district" if district=="Budapest 19. Ker."
	replace district = "1st district" if district=="Budapest 01. Ker."
	replace district = "20th district" if district=="Budapest 20. Ker."
	replace district = "21st district" if district=="Budapest 21. Ker."
	replace district = "22nd district" if district=="Budapest 22. Ker."
	replace district = "23rd district" if district=="Budapest 23. Ker."
	replace district = "2nd district" if district=="Budapest 02. Ker."
	replace district = "3rd district" if district=="Budapest 03. Ker."
	replace district = "4th district" if district=="Budapest 04. Ker."
	replace district = "5th district" if district=="Budapest 05. Ker."
	replace district = "6th district" if district=="Budapest 06. Ker."
	replace district = "7th district" if district=="Budapest 07. Ker."
	replace district = "8th district" if district=="Budapest 08. Ker."
	replace district = "9th district" if district=="Budapest 09. Ker."
	replace district = "Ajkai jaras" if district=="Ajkai Járás"
	replace district = "Aszodi jaras" if district=="Aszódi Járás"
	replace district = "Bacsalmasi jaras" if district=="Bácsalmási Járás"
	replace district = "Bajai jaras" if district=="Bajai Járás"
	replace district = "Baktaloranthazai jaras" if district=="Baktalórántházai Járás"
	replace district = "Balassagyarmati jaras" if district=="Balassagyarmati Járás"
	replace district = "Balatonalmadi jaras" if district=="Balatonalmádi Járás"
	replace district = "Balatonfuredi jaras" if district=="Balatonfüredi Járás"
	replace district = "Balmazujvarosi jaras" if district=="Balmazújvárosi Járás"
	replace district = "Barcsi jaras" if district=="Barcsi Járás"
	replace district = "Batonyterenyei jaras" if district=="Bátonyterenyei Járás"
	replace district = "Bekescsabai jaras" if district=="Békéscsabai Járás"
	replace district = "Bekesi jaras" if district=="Békési Járás"
	replace district = "Belapatfalvai jaras" if district=="Bélapátfalvai Járás"
	replace district = "Berettyoujfalui jaras" if district=="Berettyóújfalui Járás"
	replace district = "Bicskei jaras" if district=="Bicskei Járás"
	replace district = "Bolyi jaras" if district=="Bólyi Járás"
	replace district = "Bonyhadi jaras" if district=="Bonyhádi Járás"
	replace district = "Budakeszi jaras" if district=="Budakeszi Járás"
	replace district = "Cegledi jaras" if district=="Ceglédi Járás"
	replace district = "Celldomolki jaras" if district=="Celldömölki Járás"
	replace district = "Cigandi jaras" if district=="Cigándi Járás"
	replace district = "Csengeri jaras" if district=="Csengeri Járás"
	replace district = "Csongradi jaras" if district=="Csongrádi Járás"
	replace district = "Csornai jaras" if district=="Csornai Járás"
	replace district = "Csurgoi jaras" if district=="Csurgói Járás"
	replace district = "Dabasi jaras" if district=="Dabasi Járás"
	replace district = "Debreceni jaras" if district=="Debreceni Járás"
	replace district = "Derecskei jaras" if district=="Derecskei Járás"
	replace district = "Devecseri jaras" if district=="Devecseri Járás"
	replace district = "Dombovari jaras" if district=="Dombóvári Járás"
	replace district = "Dunakeszi jaras" if district=="Dunakeszi Járás"
	replace district = "Dunaujvarosi jaras" if district=="Dunaújvárosi Járás"
	replace district = "Edelenyi jaras" if district=="Edelényi Járás"
	replace district = "Egri jaras" if district=="Egri Járás"
	replace district = "Encsi jaras" if district=="Encsi Járás"
	replace district = "Enyingi jaras" if district=="Enyingi Járás"
	replace district = "Erdi jaras" if district=="Érdi Járás"
	replace district = "Esztergomi jaras" if district=="Esztergomi Járás"
	replace district = "Fehergyarmati jaras" if district=="Fehérgyarmati Járás"
	replace district = "Fonyodi jaras" if district=="Fonyódi Járás"
	replace district = "Fuzesabonyi jaras" if district=="Füzesabonyi Járás"
	replace district = "Gardonyi jaras" if district=="Gárdonyi Járás"
	replace district = "Godollo Regional Unit" if district=="Gödölloi Járás"
	replace district = "Gonci jaras" if district=="Gönci Járás"
	replace district = "Gyali jaras" if district=="Gyáli Járás"
	replace district = "Gyomaendrodi jaras" if district=="Gyomaendrodi Járás"
	replace district = "Gyongyosi jaras" if district=="Gyöngyösi Járás"
	replace district = "Gyori jaras" if district=="Gyori Járás"
	replace district = "Gyulai jaras" if district=="Gyulai Járás"
	replace district = "Hajduboszormenyi jaras" if district=="Hajdúböszörményi Járás"
	replace district = "Hajduhadhazi jaras" if district=="Hajdúhadházi Járás"
	replace district = "Hajdunanasi jaras" if district=="Hajdúnánási Járás"
	replace district = "Hajduszoboszloi jaras" if district=="Hajdúszoboszlói Járás"
	replace district = "Hatvani jaras" if district=="Hatvani Járás"
	replace district = "Hegyhati jaras" if district=="Hegyháti Járás"
	replace district = "Hevesi jaras" if district=="Hevesi Járás"
	replace district = "Hodmezovasarhelyi jaras" if district=="Hódmezovásárhelyi Járás"
	replace district = "Ibranyi jaras" if district=="Ibrányi Járás"
	replace district = "Janoshalmai jaras" if district=="Jánoshalmai Járás"
	replace district = "Jaszapati jaras" if district=="Jászapáti Járás"
	replace district = "Jaszberenyi jaras" if district=="Jászberényi Járás"
	replace district = "Kalocsai jaras" if district=="Kalocsai Járás"
	replace district = "Kaposvari jaras" if district=="Kaposvári Járás"
	replace district = "Kapuvari jaras" if district=="Kapuvári Járás"
	replace district = "Karcagi jaras" if district=="Karcagi Járás"
	replace district = "Kazincbarcikai jaras" if district=="Kazincbarcikai Járás"
	replace district = "Kecskemeti jaras" if district=="Kecskeméti Járás"
	replace district = "Kemecsei jaras" if district == "Kemecsei Járás"
	replace district = "Keszthelyi jaras" if district == "Keszthelyi Járás"
	replace district = "Kisberi jaras" if district == "Kisbéri Járás"
	replace district = "Kiskorosi jaras" if district == "Kiskorösi Járás"
	replace district = "Kiskunfelegyhazi jaras" if district == "Kiskunfélegyházi Járás"
	replace district = "Kiskunhalasi jaras" if district == "Kiskunhalasi Járás"
	replace district = "Kiskunmajsai jaras" if district == "Kiskunmajsai Járás"
	replace district = "Kisteleki jaras" if district == "Kisteleki Járás"
	replace district = "Kisvardai jaras" if district == "Kisvárdai Járás"
	replace district = "Komaromi jaras" if district == "Komáromi Járás"
	replace district = "Komloi jaras" if district == "Komlói Járás"
	replace district = "Kormendi jaras" if district == "Körmendi Járás"
	replace district = "Koszegi jaras" if district == "Koszegi Járás"
	replace district = "Kunhegyesi jaras" if district == "Kunhegyesi Járás"
	replace district = "Kunszentmartoni jaras" if district == "Kunszentmártoni Járás"
	replace district = "Kunszentmiklosi jaras" if district == "Kunszentmiklósi Járás"
	replace district = "Lenti jaras" if district == "Lenti Járás"
	replace district = "Letenyei jaras" if district == "Letenyei Járás"
	replace district = "Makoi jaras" if district == "Makói Járás"
	replace district = "Marcali jaras" if district == "Marcali Járás"
	replace district = "Martonvasari jaras" if district == "Martonvásári Járás"
	replace district = "Mateszalkai jaras" if district == "Mátészalkai Járás"
	replace district = "Mezocsati jaras" if district == "Mezocsáti Járás"
	replace district = "Mezokovacshazai jaras" if district == "Mezokovácsházai Járás"
	replace district = "Mezokovesdi jaras" if district == "Mezokövesdi Járás"
	replace district = "Mezoturi jaras" if district == "Mezotúri Járás"
	replace district = "Miskolci jaras" if district == "Miskolci Járás"
	replace district = "Mohacsi jaras" if district == "Mohácsi Járás"
	replace district = "Monori jaras" if district == "Monori Járás"
	replace district = "Morahalmi jaras" if district == "Mórahalmi Járás"
	replace district = "Mori jaras" if district == "Móri Járás"
	replace district = "Mosonmagyarovari jaras" if district == "Mosonmagyaróvári Járás"
	replace district = "Nagyatadi jaras" if district == "Nagyatádi Járás"
	replace district = "Nagykalloi jaras" if district == "Nagykállói Járás"
	replace district = "Nagykanizsai jaras" if district == "Nagykanizsai Járás"
	replace district = "Nagykatai jaras" if district == "Nagykátai Járás"
	replace district = "Nagykorosi jaras" if district == "Nagykorösi Járás"
	replace district = "Nyiradonyi jaras" if district == "Nyíradonyi Járás"
	replace district = "Nyirbatori jaras" if district == "Nyírbátori Járás"
	replace district = "Nyiregyhazi jaras" if district == "Nyíregyházai Járás"
	replace district = "Oroshazi jaras" if district == "Orosházi Járás"
	replace district = "Oroszlanyi jaras" if district == "Oroszlányi Járás"
	replace district = "Ozdi jaras" if district == "Ózdi Járás"
	replace district = "Paksi jaras" if district == "Paksi Járás"
	replace district = "Pannonhalmi jaras" if district == "Pannonhalmi Járás"
	replace district = "Papai jaras" if district == "Pápai Járás"
	replace district = "Pasztoi jaras" if district == "Pásztói Járás"
	replace district = "Pecsi jaras" if district == "Pécsi Járás"
	replace district = "Pecsvaradi jaras" if district == "Pécsváradi Járás"
	replace district = "Petervasarai jaras" if district == "Pétervásárai Járás"
	replace district = "Pilisvorosvari jaras" if district == "Pilisvörösvári Járás"
	replace district = "Puspokladanyi jaras" if district == "Püspökladányi Járás"
	replace district = "Putnoki jaras" if district == "Putnoki Járás"
	replace district = "Rackevei jaras" if district == "Ráckevei Járás"
	replace district = "Retsagi jaras" if district == "Rétsági Járás"
	replace district = "Salgotarjani jaras" if district == "Salgótarjáni Járás"
	replace district = "Sarbogardi jaras" if district == "Sárbogárdi Járás"
	replace district = "Sarkadi jaras" if district == "Sarkadi Járás"
	replace district = "Sarospataki jaras" if district == "Sárospataki Járás"
	replace district = "Sarvari jaras" if district == "Sárvári Járás"
	replace district = "Satoraljaujhelyi jaras" if district == "Sátoraljaújhelyi Járás"
	replace district = "Sellyei jaras" if district == "Sellyei Járás"
	replace district = "Siklosi jaras" if district == "Siklósi Járás"
	replace district = "Siofoki jaras" if district == "Siófoki Járás"
	replace district = "Soproni jaras" if district == "Soproni Járás"
	replace district = "Sumegi jaras" if district == "Sümegi Járás"
	replace district = "Szarvasi jaras" if district == "Szarvasi Járás"
	replace district = "Szecsenyi jaras" if district == "Szécsényi Járás"
	replace district = "Szegedi jaras" if district == "Szegedi Járás"
	replace district = "Szeghalmi jaras" if district == "Szeghalmi Járás"
	replace district = "Szekesfehervari jaras" if district == "Székesfehérvári Járás"
	replace district = "Szekszardi jaras" if district == "Szekszárdi Járás"
	replace district = "Szentendrei jaras" if district == "Szentendrei Járás"
	replace district = "Szentesi jaras" if district == "Szentesi Járás"
	replace district = "Szentgotthardi jaras" if district == "Szentgotthárdi Járás"
	replace district = "Szentlorinci Jaras" if district == "Szentlorinci Járás"
	replace district = "Szerencsi jaras" if district == "Szerencsi Járás"
	replace district = "Szigetszentmiklosi jaras" if district == "Szigetszentmiklósi Járás"
	replace district = "Szigetvari jaras" if district == "Szigetvári Járás"
	replace district = "Szikszoi jaras" if district == "Szikszói Járás"
	replace district = "Szobi jaras" if district == "Szobi Járás"
	replace district = "Szolnoki jaras" if district == "Szolnoki Járás"
	replace district = "Szombathelyi jaras" if district == "Szombathelyi Járás"
	replace district = "Tabi jaras" if district == "Tabi Járás"
	replace district = "Tamasi jaras" if district == "Tamási Járás"
	replace district = "Tapolcai jaras" if district == "Tapolcai Járás"
	replace district = "Tatabanyai jaras" if district == "Tatabányai Járás"
	replace district = "Tatai jaras" if district == "Tatai Járás"
	replace district = "Teti jaras" if district == "Téti Járás"
	replace district = "Tiszafuredi jaras" if district == "Tiszafüredi Járás"
	replace district = "Tiszakecskei jaras" if district == "Tiszakécskei Járás"
	replace district = "Tiszaujvarosi jaras" if district == "Tiszaújvárosi Járás"
	replace district = "Tiszavasvari jaras" if district == "Tiszavasvári Járás"
	replace district = "Tokaji jaras" if district == "Tokaji Járás"
	replace district = "Tolnai jaras" if district == "Tolnai Járás"
	replace district = "Torokszentmiklosi jaras" if district == "Törökszentmiklósi Járás"
	replace district = "Vaci jaras" if district == "Váci Járás"
	replace district = "Varpalotai jaras" if district == "Várpalotai Járás"
	replace district = "Vasarosnamenyi jaras" if district == "Vásárosnaményi Járás"
	replace district = "Vasvari jaras" if district == "Vasvári Járás"
	replace district = "Vecsesi jaras" if district == "Vecsési Járás"
	replace district = "Veszpremi jaras" if district == "Veszprémi Járás"
	replace district = "Zahonyi jaras" if district == "Záhonyi Járás"
	replace district = "Zalaegerszegi jaras" if district == "Zalaegerszegi Járás"
	replace district = "Zalaszentgroti jaras" if district == "Zalaszentgróti Járás"
	replace district = "Zirci jaras" if district == "Zirci Járás"
	replace district = "" if district == "Fiktív, Területre Nem Bontott"
	}
	tempfile instrument_firms
	save `instrument_firms', replace

	* Get the shp data.
	use "$district_map\hungary2.dta", clear

	*Save as tempfile
	tempfile location
	save `location', replace

	* Take the instruments data
	use `instrument_firms', clear
	merge m:1 nace4 using "$processed/MNB/nace_standard_materialities_with_mnb.dta", nogen keepusing(nace1 nace1_d)

	* Concord the NUTS 3 names.
	rename district ADM2_HU

	* Get the variables of interest (total exposure, total agricultural exposure etc.)
	gen k_eur = k_usd * EUR
	gen k_eur_a = k_eur if nace1 == "A"
	gen k_eur_c = k_eur if nace1 == "C"
	gen k_eur_l = k_eur if nace1 == "L"

	* Distribute the missing Budapest values to the districts based on the existing ratios.
	collapse (sum) k_eur k_eur_a k_eur_c k_eur_l, by(ADM2_HU county)
	foreach var of varlist k_eur k_eur_a k_eur_c k_eur_l {
		sum `var' if county == 1 & ADM2_HU != ""
		gen rat_`var'=`var'/r(sum) if county == 1
		sum `var' if county == 1 & ADM2_HU == ""
		replace `var' = `var' + (r(mean)*rat_`var') if county == 1
		drop rat_`var'
	}
		drop if county == 1 & ADM2_HU == ""

	* Save the intermediate district data here
		save "$processed/MNB/instruments_firms_districts", replace

	collapse (sum) k_eur k_eur_a k_eur_c k_eur_l, by(ADM2_HU)
	drop if ADM2_HU == ""

	* Convert to millions of Euros
	foreach var of varlist k_eur k_eur_a k_eur_c k_eur_l {
		replace `var' = `var' / 1000000
	}

	* Merge with the map data
	merge 1:1 ADM2_HU using `location', nogen
	
	* Generate the total exposure map
	colorpalette sfso blue, n(198) nograph reverse
	local colors `r(p)'
	spmap k_eur using "$district_map/hungary3_shp", id(_ID) fcolor("`colors'") /*title("Total exposure amount")*/ clnumber(198) legenda(off)
	graph export "$output\Identification_and_prioritisation\total_exposure_district.emf", as(emf) replace

	* Generate the agricultural exposure map
	colorpalette sfso green, n(198) nograph reverse
	local colors `r(p)'
	spmap k_eur_a using "$district_map/hungary3_shp", id(_ID) fcolor("`colors'") /*title("Total agricultural exposure amount")*/ clnumber(198) legenda(off)
	graph export "$output\Identification_and_prioritisation\total_exposure_a_district.emf", as(emf) replace

	* Generate the manufacturing exposure map
	colorpalette sfso orange, n(198) nograph reverse
	local colors `r(p)'
	spmap k_eur_c using "$district_map/hungary3_shp", id(_ID) fcolor("`colors'") /*title("Total manufacturing exposure amount")*/ clnumber(198) legenda(off)
	graph export "$output\Identification_and_prioritisation\total_exposure_c_district.emf", as(emf) replace

	* Generate the real estate exposure map
	colorpalette sfso brown, n(198) nograph reverse
	local colors `r(p)'
	spmap k_eur_l using "$district_map/hungary3_shp", id(_ID) fcolor("`colors'") /*title("Total real estate exposure amount")*/ clnumber(198) legenda(off)
	graph export "$output\Identification_and_prioritisation\total_exposure_l_district.emf", as(emf) replace

* 10.3) Descriptives

	* 10.3.1) Where are the loans located?
		use "$processed\MNB\instruments_firms.dta", clear
		merge m:1 nace4 using "$processed/MNB/nace_standard_materialities_with_mnb.dta", nogen keepusing(nace1 nace1_d)

		* Future proofing - decode nationality
			decode nationality, generate(nationality_label)
			tab nationality_label
			
		* Foreign borrowers
			preserve
			gen k_eur = k_usd * EUR
			replace k_eur = k_eur / 1000000
			collapse (sum) k_eur, by(nationality_label)
			drop if nationality_label == "Hungary"
			drop if nationality_label == ""
			gsort - k_eur
			keep if _n < 11
			export excel using "$output/Identification_and_prioritisation/top_10_borrower_locations", replace sheet(foreign_countries)
			restore
			
		* Hungarian counties
			use "$processed/MNB/instruments_firms_districts", clear
			decode county, gen(county_label)
			preserve
			collapse (sum) k_eur, by(county_label)
			drop if county_label == ""
			gsort - k_eur
			replace k_eur = k_eur / 1000000
			keep if _n < 11
			export excel using "$output/Identification_and_prioritisation/top_10_borrower_locations", sheet(counties,replace)
			restore
		
		* Hungarian districts
			preserve
			collapse (sum) k_eur, by(ADM2_HU)
			drop if ADM2_HU == ""
			gsort - k_eur
			replace k_eur = k_eur / 1000000
			keep if _n < 11
			export excel using "$output/Identification_and_prioritisation/top_10_borrower_locations", sheet(districts,replace)
			restore

	* 10.3.2) Where are the agricultural loans located?

		use "$processed\MNB\instruments_firms.dta", clear
		merge m:1 nace4 using "$processed/MNB/nace_standard_materialities_with_mnb.dta", nogen keepusing(nace1 nace1_d)

		* Future proofing - decode nationality
			decode nationality, generate(nationality_label)
			tab nationality_label
			
		* Foreign borrowers
			preserve
			gen k_eur = k_usd * EUR
			replace k_eur = k_eur / 1000000
			keep if nace1 == "A"
			collapse (sum) k_eur, by(nationality_label)
			drop if nationality_label == "Hungary"
			drop if nationality_label == ""
			gsort - k_eur
			keep if _n < 11
			export excel using "$output/Identification_and_prioritisation/top_10_borrower_locations_agriculture", replace sheet(foreign_countries)
			restore
			
		* Hungarian counties
			use "$processed/MNB/instruments_firms_districts", clear
			decode county, gen(county_label)
			preserve
			collapse (sum) k_eur_a, by(county_label)
			drop if county_label == ""
			gsort - k_eur_a
			replace k_eur_a = k_eur_a / 1000000
			keep if _n < 11
			export excel using "$output/Identification_and_prioritisation/top_10_borrower_locations_agriculture", sheet(counties,replace)
			restore
		
		* Hungarian districts
			preserve
			collapse (sum) k_eur_a, by(ADM2_HU)
			drop if ADM2_HU == ""
			gsort - k_eur_a
			replace k_eur_a = k_eur_a / 1000000
			keep if _n < 11
			export excel using "$output/Identification_and_prioritisation/top_10_borrower_locations_agriculture", sheet(districts,replace)
			restore
}