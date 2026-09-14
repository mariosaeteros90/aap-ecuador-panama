*==============================================================
* 00. PREPARACION DE BASES Y VALIDACION
*==============================================================
clear all

*--------------------------------------------------------------
* Auxiliar: normaliza el codigo arancelario a string de longitud fija
* Sin esta validacion, un cambio de formato en el Excel convierte el
* arancel en numerico, se pierde el cero inicial y todos los capitulos
* 01 a 09 se reclasifican en silencio.
*--------------------------------------------------------------
cap program drop _normaliza_arancel
program define _normaliza_arancel
    args ndig
    cap confirm string variable arancel
    if _rc  tostring arancel, replace format(%0`ndig'.0f) force
    replace arancel = trim(arancel)
    replace arancel = string(real(arancel), "%0`ndig'.0f") if strlen(arancel) < `ndig'
    qui count if strlen(arancel) != `ndig'
    if r(N) > 0 {
        di as error "ERROR: `r(N)' codigos con longitud distinta de `ndig'"
        exit 459
    }
    gen str2 hs2 = substr(arancel,1,2)
    gen str4 hs4 = substr(arancel,1,4)
    gen str6 hs6 = substr(arancel,1,6)
end

*==============================================================
* 1. ECUADOR
*==============================================================
import excel "$base", sheet("db_ecu") firstrow clear
compress
destring año, replace force
rename año anio
_normaliza_arancel 10

* "data" choca con comandos de Stata; se renombra a registro
cap confirm variable data
if !_rc  rename data registro
else     gen str12 registro = ""
replace registro = "" if flujo == "Exportaciones"
replace registro = trim(lower(registro))

gen byte c98 = (hs2=="98")
label var c98 "Capitulo 98: trafico postal, muestras y operaciones especiales"

*--------------------------------------------------------------
* CORRECCION DE ETIQUETA: el bloque PAN / procedencia llega con
* las series FOB y CIF ambas rotuladas "fob", de modo que cada
* subpartida aparece dos veces y la suma duplica el flujo. Se
* verifica que no exista ninguna fila cif+procedencia+PAN (ahi
* deberia estar la serie que falta) y se reasigna por valor: de
* cada par, el menor es FOB y el mayor es CIF.
*--------------------------------------------------------------
qui count if partner=="PAN" & registro=="procedencia" & tipo=="cif"
if r(N)==0 {
    bysort partner registro anio arancel (valor): gen byte _par = _n if ///
        partner=="PAN" & registro=="procedencia"
    bysort partner registro anio arancel: gen byte _npar = _N if ///
        partner=="PAN" & registro=="procedencia"
    qui count if _npar==2 & _par==2
    local nrep = r(N)
    replace tipo = "cif" if _npar==2 & _par==2
    drop _par _npar
    di as error "AVISO: `nrep' filas PAN/procedencia reetiquetadas de fob a cif."
    di as error "       Sin esta correccion las importaciones por procedencia se duplican."
}

* Filas legitimamente repetidas (mismo codigo, descripciones distintas):
* se suman. Cualquier otro duplicado sobrante detiene la ejecucion.
collapse (sum) valor (firstnm) reporter descripcion petro_nopetro, ///
    by(anio flujo tipo partner registro arancel hs2 hs4 hs6 c98)

* Validaciones
isid anio flujo tipo partner registro arancel, missok
qui count if missing(valor)
assert r(N)==0

* Control de escala: al nivel mundo el total por origen y por
* procedencia debe coincidir, porque los dos registros reparten
* las mismas transacciones. Una razon cercana a 1.000 delata una
* descarga en miles de dolares.
preserve
    keep if partner=="WLD" & flujo=="Importaciones" & tipo=="fob"
    collapse (sum) valor, by(registro anio)
    reshape wide valor, i(anio) j(registro) string
    gen double razon = valorprocedencia/valororigen
    qui summ razon
    if abs(r(mean)-1) > 0.01 {
        di as error "ERROR: origen y procedencia del mundo no coinciden."
        di as error "       razon media = " r(mean) ". Revisar unidades de la descarga."
        list, noobs
    }
    else di as result "OK: identidad origen = procedencia (mundo) verificada."
restore

* Control de escala 2: la razon cif/fob de cada bloque debe estar
* entre 1.02 y 1.12. Por debajo de 1 el bloque tiene filas duplicadas
* o series mezcladas; muy por encima, un problema de unidades.
preserve
    keep if flujo=="Importaciones"
    collapse (sum) valor, by(partner registro tipo anio)
    reshape wide valor, i(partner registro anio) j(tipo) string
    gen double razon = valorcif/valorfob
    qui count if !inrange(razon,1.02,1.12)
    if r(N) > 0 {
        di as error "ERROR: `r(N)' bloques con razon cif/fob fuera de rango."
        list if !inrange(razon,1.02,1.12), noobs
        exit 459
    }
    di as result "OK: razon cif/fob dentro de rango en todos los bloques."
restore

* Control de escala 3: para Panama, el flujo por procedencia tiene que
* superar al de origen. Si no, el bloque de procedencia esta en miles.
preserve
    keep if flujo=="Importaciones" & partner=="PAN" & tipo=="fob"
    collapse (sum) valor, by(registro anio)
    reshape wide valor, i(anio) j(registro) string
    qui count if valorprocedencia <= valororigen
    if r(N) > 0 {
        di as error "ERROR: procedencia menor que origen en `r(N)' anios."
        list, noobs
        exit 459
    }
    di as result "OK: procedencia > origen en Panama, escala coherente."
restore

tab partner flujo
tab registro tipo if flujo=="Importaciones"
save "$inn/db_ecu.dta", replace

*==============================================================
* 2. PANAMA
*==============================================================
import excel "$base", sheet("db_pan") firstrow clear
compress
destring año, replace force
rename año anio
_normaliza_arancel 12
gen byte c98 = (hs2=="98")
save "$inn/db_pan.dta", replace

*==============================================================
* 3. CLASIFICACION PETROLERA A HS6 (construida desde Ecuador)
*==============================================================
use "$inn/db_ecu.dta", clear
keep hs6 petro_nopetro
drop if missing(hs6) | missing(petro_nopetro)
duplicates drop
replace petro_nopetro = "Petrolero" if hs6=="271490"   // conflicto conocido
duplicates drop
bysort hs6: gen byte _n_clas = _N
qui count if _n_clas > 1
if r(N) > 0 {
    di as error "AVISO: `r(N)' hs6 con clasificacion petrolera ambigua"
    list hs6 petro_nopetro if _n_clas>1, sepby(hs6)
}
duplicates drop hs6, force
keep hs6 petro_nopetro
rename petro_nopetro petro
save "$inn/clasificacion_petroleo_hs6.dta", replace

*==============================================================
* 4. BASE ECUADOR DE TRABAJO
*==============================================================
use "$inn/db_ecu.dta", clear
merge m:1 hs6 using "$inn/clasificacion_petroleo_hs6.dta", keep(1 3) nogen
replace petro = petro_nopetro if missing(petro)

gen str60 sector = ""

replace sector = "Agricultura, ganadería, pesca y silvicultura" ///
    if inrange(real(hs2),1,14)

replace sector = "Alimentos, bebidas y tabaco" ///
    if inrange(real(hs2),15,24)

replace sector = "Minería" ///
    if inrange(real(hs2),25,26)

replace sector = "Energía y derivados del petroleo" ///
    if real(hs2)==27

replace sector = "Química y farmacia" ///
    if inrange(real(hs2),28,38)

replace sector = "Caucho y plástico" ///
    if inrange(real(hs2),39,40)

replace sector = "Cuero, textiles y calzado" ///
    if inrange(real(hs2),41,43) | ///
       inrange(real(hs2),50,65)

replace sector = "Madera, papel y celulosa" ///
    if inrange(real(hs2),44,49)

replace sector = "Minerales no metálicos" ///
    if inrange(real(hs2),68,70)

replace sector = "Metales y productos metálicos" ///
    if inrange(real(hs2),72,83)

replace sector = "Maquinaria y equipo eléctrico" ///
    if inrange(real(hs2),84,85)

replace sector = "Vehículos y equipo de transporte" ///
    if inrange(real(hs2),86,89)

replace sector = "Capitulo 98 (tráfico postal y especiales)" ///
    if hs2=="98"

replace sector = "Otras manufacturas" ///
    if sector == ""

order anio flujo tipo reporter partner registro hs2 hs4 hs6 arancel ///
      descripcion petro sector c98 valor
compress
save "$aux/db_ecu_clean.dta", replace

*==============================================================
* 5. BASE PANAMA DE TRABAJO
*==============================================================
use "$inn/db_pan.dta", clear
merge m:1 hs6 using "$inn/clasificacion_petroleo_hs6.dta", keep(1 3)
* Los hs6 sin correspondencia en el registro ecuatoriano quedan marcados,
* no se asumen no petroleros.
gen byte petro_imputado = (_merge==1)
replace petro = "No Petrolero (imputado)" if _merge==1
drop _merge

gen str60 sector = ""

replace sector = "Agricultura, ganadería, pesca y silvicultura" ///
    if inrange(real(hs2),1,14)

replace sector = "Alimentos, bebidas y tabaco" ///
    if inrange(real(hs2),15,24)

replace sector = "Minería" ///
    if inrange(real(hs2),25,26)

replace sector = "Energía y derivados del petroleo" ///
    if real(hs2)==27

replace sector = "Química y farmacia" ///
    if inrange(real(hs2),28,38)

replace sector = "Caucho y plástico" ///
    if inrange(real(hs2),39,40)

replace sector = "Cuero, textiles y calzado" ///
    if inrange(real(hs2),41,43) | ///
       inrange(real(hs2),50,65)

replace sector = "Madera, papel y celulosa" ///
    if inrange(real(hs2),44,49)

replace sector = "Minerales no metálicos" ///
    if inrange(real(hs2),68,70)

replace sector = "Metales y productos metálicos" ///
    if inrange(real(hs2),72,83)

replace sector = "Maquinaria y equipo eléctrico" ///
    if inrange(real(hs2),84,85)

replace sector = "Vehículos y equipo de transporte" ///
    if inrange(real(hs2),86,89)

replace sector = "Capitulo 98 (tráfico postal y especiales)" ///
    if hs2=="98"

replace sector = "Otras manufacturas" ///
    if sector == ""
	
order anio flujo tipo reporter partner hs2 hs4 hs6 arancel ///
      descripcion petro sector c98 valor
compress
save "$aux/db_pan_clean.dta", replace

* Cuanto valor depende del supuesto de imputacion
tab petro_imputado, summarize(valor)

clear all
