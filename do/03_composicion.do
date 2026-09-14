*==============================================================
* 03. COMPOSICION Y CONCENTRACION
* Salida: resultados/03_composicion.xlsx
*==============================================================
clear all

run "$cod/_rutinas.do"   // clear all borra los programas; hay que recargarlos
local xls "$out/03_composicion.xlsx"
cap erase "`xls'"

*--------------------------------------------------------------
* A. Composicion sectorial, exportaciones a Panama y al mundo
*--------------------------------------------------------------
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Exportaciones" & tipo=="fob"
collapse (sum) valor, by(partner petro sector anio)
replace valor = valor/1e6
bysort partner petro anio: egen double _t = total(valor)
gen double share = 100*valor/_t
drop _t
reshape wide valor share, i(partner petro sector) j(anio)
sort partner petro sector
export excel using "`xls'", sheet("A_sector_export") sheetreplace firstrow(variables)

*--------------------------------------------------------------
* B. Composicion sectorial de las importaciones desde Panama,
*    en los dos universos
*--------------------------------------------------------------
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Importaciones" & tipo=="fob" & partner=="PAN"
collapse (sum) valor, by(registro petro sector anio)
replace valor = valor/1e6
bysort registro petro anio: egen double _t = total(valor)
gen double share = 100*valor/_t
drop _t
reshape wide valor share, i(registro petro sector) j(anio)
sort registro petro sector
export excel using "`xls'", sheet("B_sector_import") sheetreplace firstrow(variables)

*--------------------------------------------------------------
* C. Rankings de subpartidas
*--------------------------------------------------------------
* C1. Exportaciones no petroleras a Panama
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Exportaciones" & tipo=="fob" & partner=="PAN" & petro=="No Petrolero"
collapse (sum) valor (firstnm) descripcion sector, by(hs6 anio)
replace valor = valor/1e6
reshape wide valor, i(hs6 descripcion sector) j(anio)
gsort -valor$T1
export excel using "`xls'", sheet("C1_rank_export") sheetreplace firstrow(variables)
list hs6 descripcion valor$T0 valor$T1 in 1/20, noobs

* C2. Importaciones no petroleras, cada universo
foreach u in origen procedencia {
    use "$aux/db_ecu_clean.dta", clear
    keep if flujo=="Importaciones" & tipo=="fob" & partner=="PAN" & petro=="No Petrolero"
    keep if registro=="`u'"
    collapse (sum) valor (firstnm) descripcion sector, by(hs6 anio)
    replace valor = valor/1e6
    reshape wide valor, i(hs6 descripcion sector) j(anio)
    gsort -valor$T1
    export excel using "`xls'", sheet("C2_rank_`u'") sheetreplace firstrow(variables)
}

*--------------------------------------------------------------
* D. Concentracion: HHI (0 a 10.000) y CR5, por universo
*--------------------------------------------------------------
use "$aux/db_ecu_clean.dta", clear
keep if tipo=="fob" & petro=="No Petrolero"
gen str24 universo = ""
replace universo = "X a Panama"        if flujo=="Exportaciones" & partner=="PAN"
replace universo = "X al mundo"        if flujo=="Exportaciones" & partner=="WLD"
replace universo = "M origen PAN"      if flujo=="Importaciones" & partner=="PAN" & registro=="origen"
replace universo = "M procedencia PAN" if flujo=="Importaciones" & partner=="PAN" & registro=="procedencia"
drop if universo==""
tempfile base
save `base'
tempfile rconc
r_conc, in(`base') group(universo anio) out(`rconc')
use `rconc', clear
sort universo anio
export excel using "`xls'", sheet("D_concentracion") sheetreplace firstrow(variables)
list, noobs sepby(universo)

*--------------------------------------------------------------
* E. Similitud de canastas (Finger-Kreinin)
*--------------------------------------------------------------
* E1. Exportaciones: canasta a Panama frente a canasta al mundo
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Exportaciones" & tipo=="fob" & petro=="No Petrolero"
collapse (sum) valor, by(anio partner hs6)
tempfile f1
save `f1'
tempfile s1
r_simil, in(`f1') cvar(partner) a(PAN) b(WLD) by(anio) out(`s1')
use `s1', clear
gen str48 comparacion = "Export a PAN vs export al mundo (no petrolero)"
tempfile e1
save `e1'

* E2. Importaciones: canasta de origen frente a canasta de procedencia
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Importaciones" & tipo=="fob" & partner=="PAN" & petro=="No Petrolero"
collapse (sum) valor, by(anio registro hs6)
tempfile f2
save `f2'
tempfile s2
r_simil, in(`f2') cvar(registro) a(origen) b(procedencia) by(anio) out(`s2')
use `s2', clear
gen str48 comparacion = "Origen PAN vs procedencia PAN"
append using `e1'
order comparacion anio n_hs6 fk
sort comparacion anio
export excel using "`xls'", sheet("E_similitud") sheetreplace firstrow(variables)
list, noobs sepby(comparacion)

di as result "== 03_composicion.xlsx generado =="
clear all
