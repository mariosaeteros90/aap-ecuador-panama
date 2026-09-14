*==============================================================
* AAP ECUADOR - PANAMA
* Comercio bilateral no petrolero, 2021-2025
* Mario Saeteros Perez
* Programa maestro. Stata 19.
*==============================================================
clear all
set more off
set varabbrev off
version 19

*--------------------------------------------------------------
* UNICA LINEA QUE HAY QUE EDITAR
* Ruta de la carpeta del repositorio, la que contiene do/ y datos/.
* En Windows se puede escribir con / igual que en Mac y Linux.
*--------------------------------------------------------------
global path "C:/RUTA/DE/TU/CARPETA/aap-ecuador-panama"

cd "$path"

global cod  "$path/do"
global base "$path/datos/Base_Final.xlsx"
global inn  "$path/inn"
global aux  "$path/aux"
global out  "$path/resultados"

cap mkdir "$inn"
cap mkdir "$aux"
cap mkdir "$out"

* --- Parametros globales del analisis ---------------------------
global T0     = 2021          				  // anio base
global T1     = 2025          				  // anio final serie Ecuador
global T1PAN  = 2024          				  // ultimo anio con registro panameno
global TANCLA = 2024          				  // anio de anclaje para comparaciones bilaterales
global UMBRALES "0 1000 10000 50000 100000"   // sensibilidad margenes (USD)

* --- Ejecucion ---------------------------------------------------
* 00 reconstruye inn/ y aux/ desde el Excel. Los modulos 01 a 06
* leen de aux/ y se pueden correr sueltos una vez que 00 termino.
run "$cod/_rutinas.do"

do "$cod/00_prepara_bases.do"
do "$cod/01_conciliacion.do"
do "$cod/02_canales.do"
do "$cod/03_composicion.do"
do "$cod/04_indicadores.do"
do "$cod/05_dinamica.do"
do "$cod/06_graficos.do"
