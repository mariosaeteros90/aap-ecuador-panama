*==============================================================
* 04. INDICADORES DE ESTRUCTURA DE LA RELACION BILATERAL
*     A. Comercio intraindustrial (Grubel-Lloyd, simple y Aquino)
*     B. Complementariedad (Michaely / TCI)
*     C. Similitud de canastas (Finger-Kreinin)
* Salida: resultados/04_indicadores.xlsx
*==============================================================
clear all

run "$cod/_rutinas.do"   // clear all borra los programas; hay que recargarlos
local xls "$out/04_indicadores.xlsx"
cap erase "`xls'"

*==============================================================
* A. GRUBEL-LLOYD
* Cuatro variantes: universo de importacion (origen o procedencia)
* por cobertura (con o sin petroleo). Tres niveles de agregacion,
* porque el indice sube mecanicamente con la agregacion y reportar
* uno solo permite elegir el resultado que conviene.
*==============================================================
tempfile glacum
local primero = 1

foreach u in origen procedencia {
  foreach cob in total nopetro {
    * Exportaciones ECU -> PAN
    use "$aux/db_ecu_clean.dta", clear
    keep if flujo=="Exportaciones" & tipo=="fob" & partner=="PAN"
    if "`cob'"=="nopetro" keep if petro=="No Petrolero"
    collapse (sum) x=valor, by(anio hs2 hs4 hs6)
    tempfile xx
    save `xx'

    * Importaciones PAN -> ECU en el universo correspondiente
    use "$aux/db_ecu_clean.dta", clear
    keep if flujo=="Importaciones" & tipo=="fob" & partner=="PAN" & registro=="`u'"
    if "`cob'"=="nopetro" keep if petro=="No Petrolero"
    collapse (sum) m=valor, by(anio hs2 hs4 hs6)
    merge 1:1 anio hs2 hs4 hs6 using `xx', nogen
    replace x = 0 if missing(x)
    replace m = 0 if missing(m)
    tempfile par
    save `par'

    foreach niv in hs2 hs4 hs6 {
        tempfile r
        r_gl, in(`par') nivel(`niv') out(`r') etiqueta("`u' / `cob'")
        use `r', clear
        if `primero' {
            save `glacum', replace
            local primero = 0
        }
        else {
            append using `glacum'
            save `glacum', replace
        }
    }
  }
}

use `glacum', clear
gsort variante nivel anio
export excel using "`xls'", sheet("A_grubel_lloyd") sheetreplace firstrow(variables)
list if nivel=="hs4", sepby(variante) noobs

*==============================================================
* B. COMPLEMENTARIEDAD
* Requiere la estructura importadora de Panama frente al mundo.
* No esta en la base bilateral: db_pan solo registra a Ecuador como
* contraparte. Mientras no exista la hoja db_pan_wld el bloque no
* corre.
*==============================================================
cap confirm file "$aux/db_pan_wld_clean.dta"
if _rc {
    di as txt "== B. Complementariedad omitida: falta db_pan_wld =="
}
else {
    * Estructura exportadora del Ecuador hacia el mundo
    use "$aux/db_ecu_clean.dta", clear
    keep if flujo=="Exportaciones" & tipo=="fob" & partner=="WLD"
    collapse (sum) valor, by(anio hs6)
    bysort anio: egen double _t = total(valor)
    gen double sx = valor/_t
    keep anio hs6 sx
    tempfile ecux
    save `ecux'

    * Estructura importadora de Panama desde el mundo
    use "$aux/db_pan_wld_clean.dta", clear
    keep if flujo=="Importaciones"
    collapse (sum) valor, by(anio hs6)
    bysort anio: egen double _t = total(valor)
    gen double sm = valor/_t
    keep anio hs6 sm
    merge 1:1 anio hs6 using `ecux', nogen
    tempfile pares
    save `pares'

    tempfile tci1
    r_tci, in(`pares') out(`tci1') etiqueta("Oferta ECU frente a demanda PAN")
    use `tci1', clear
    export excel using "`xls'", sheet("B_complementariedad") sheetreplace firstrow(variables)
    list, noobs

    * Aporte de cada seccion al indice: donde esta la complementariedad
    use `pares', clear
    gen str2 hs2 = substr(hs6,1,2)
    gen double coincidencia = min(sx, sm)
    collapse (sum) coincidencia sx sm, by(anio hs2)
    replace coincidencia = 100*coincidencia
    gsort anio -coincidencia
    export excel using "`xls'", sheet("B_compl_por_hs2") sheetreplace firstrow(variables)
}

*==============================================================
* C. SIMILITUD DE CANASTAS (Finger-Kreinin)
* C1. Lo que Ecuador manda a Panama frente a lo que manda al mundo.
*     Mide si Panama es un destino de nicho o una replica del mundo.
*==============================================================
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Exportaciones" & tipo=="fob"
collapse (sum) valor, by(anio partner hs6)
tempfile fk1
save `fk1'
tempfile r1
r_simil, in(`fk1') cvar(partner) a(PAN) b(WLD) by(anio) out(`r1')
use `r1', clear
gen str40 comparacion = "Export ECU a PAN vs ECU al mundo"
export excel using "`xls'", sheet("C1_simil_export") sheetreplace firstrow(variables)
list, noobs

* C2. Canasta de origen panameno frente a canasta de procedencia.
*     Mide que tanto se parecen las dos canastas.
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Importaciones" & tipo=="fob" & partner=="PAN"
collapse (sum) valor, by(anio registro hs6)
tempfile fk2
save `fk2'
tempfile r2
r_simil, in(`fk2') cvar(registro) a(origen) b(procedencia) by(anio) out(`r2')
use `r2', clear
gen str40 comparacion = "Origen PAN vs procedencia PAN"
export excel using "`xls'", sheet("C2_simil_import") sheetreplace firstrow(variables)
list, noobs

di as result "== 04_indicadores.xlsx generado =="
clear all
